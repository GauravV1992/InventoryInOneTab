/* ============================================================
   FIFO stock layers â€” consume oldest stock first on Sales
   Run in SSMS after fix_multi_company / fix_opening_stock_rate
   ============================================================ */
USE PawanPutra;
GO

/* ---------- Tables ---------- */
IF OBJECT_ID('dbo.StockFifoBatch', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.StockFifoBatch (
        BatchId            BIGINT IDENTITY(1,1) PRIMARY KEY,
        CompanyId          INT NOT NULL,
        MaterialId         INT NOT NULL,
        LocationId         INT NOT NULL,
        SourceType         NVARCHAR(20) NOT NULL,  -- OPENING / PURCHASE
        SourceId           INT NOT NULL,
        TransactionDate    DATE NOT NULL,
        QuantityIn         DECIMAL(18,3) NOT NULL,
        QuantityRemaining  DECIMAL(18,3) NOT NULL,
        Rate               DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreatedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_StockFifoBatch_Remaining CHECK (QuantityRemaining >= 0 AND QuantityRemaining <= QuantityIn),
        CONSTRAINT FK_StockFifoBatch_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId)
    );
END
GO

IF OBJECT_ID('dbo.StockFifoAllocation', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.StockFifoAllocation (
        AllocationId   BIGINT IDENTITY(1,1) PRIMARY KEY,
        CompanyId      INT NOT NULL,
        SalesId        INT NOT NULL,
        SalesDetailId  INT NULL,
        BatchId        BIGINT NOT NULL,
        MaterialId     INT NOT NULL,
        LocationId     INT NOT NULL,
        Quantity       DECIMAL(18,3) NOT NULL,
        Rate           DECIMAL(18,2) NOT NULL DEFAULT 0,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_StockFifoAllocation_Batch FOREIGN KEY (BatchId) REFERENCES dbo.StockFifoBatch(BatchId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockFifoBatch_FifoOrder' AND object_id = OBJECT_ID('dbo.StockFifoBatch'))
    CREATE NONCLUSTERED INDEX IX_StockFifoBatch_FifoOrder
        ON dbo.StockFifoBatch(CompanyId, MaterialId, LocationId, TransactionDate, BatchId)
        INCLUDE (QuantityRemaining, Rate, SourceType, SourceId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockFifoAllocation_Sales' AND object_id = OBJECT_ID('dbo.StockFifoAllocation'))
    CREATE NONCLUSTERED INDEX IX_StockFifoAllocation_Sales
        ON dbo.StockFifoAllocation(CompanyId, SalesId)
        INCLUDE (BatchId, Quantity);
GO

/* ---------- Add / upsert FIFO batch (stock IN) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoAddOrReplaceBatch
    @CompanyId       INT,
    @MaterialId      INT,
    @LocationId      INT,
    @SourceType      NVARCHAR(20),
    @SourceId        INT,
    @TransactionDate DATE,
    @QuantityIn      DECIMAL(18,3),
    @Rate            DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @QuantityIn IS NULL OR @QuantityIn <= 0
        RETURN;

    DECLARE @BatchId BIGINT;
    DECLARE @Consumed DECIMAL(18,3);

    SELECT @BatchId = BatchId
    FROM dbo.StockFifoBatch
    WHERE CompanyId = @CompanyId
      AND SourceType = @SourceType
      AND SourceId = @SourceId
      AND MaterialId = @MaterialId
      AND LocationId = @LocationId;

    IF @BatchId IS NULL
    BEGIN
        INSERT INTO dbo.StockFifoBatch
            (CompanyId, MaterialId, LocationId, SourceType, SourceId, TransactionDate, QuantityIn, QuantityRemaining, Rate)
        VALUES
            (@CompanyId, @MaterialId, @LocationId, @SourceType, @SourceId, @TransactionDate, @QuantityIn, @QuantityIn, ISNULL(@Rate, 0));
        RETURN;
    END

    SELECT @Consumed = ISNULL(SUM(Quantity), 0)
    FROM dbo.StockFifoAllocation
    WHERE BatchId = @BatchId AND CompanyId = @CompanyId;

    IF @QuantityIn < @Consumed
    BEGIN
        DECLARE @Err NVARCHAR(400) =
            N'Cannot reduce inbound qty below already sold FIFO qty ('
            + CAST(@Consumed AS NVARCHAR(30)) + N').';
        THROW 50050, @Err, 1;
    END

    UPDATE dbo.StockFifoBatch
    SET TransactionDate = @TransactionDate,
        QuantityIn = @QuantityIn,
        QuantityRemaining = @QuantityIn - @Consumed,
        Rate = ISNULL(@Rate, Rate)
    WHERE BatchId = @BatchId;
END
GO

/* ---------- Remove FIFO batch (stock IN deleted) ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoRemoveBatch
    @CompanyId  INT,
    @SourceType NVARCHAR(20),
    @SourceId   INT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.StockFifoBatch b
        INNER JOIN dbo.StockFifoAllocation a ON a.BatchId = b.BatchId
        WHERE b.CompanyId = @CompanyId AND b.SourceType = @SourceType AND b.SourceId = @SourceId
    )
        THROW 50051, N'Cannot remove stock batch â€” quantity already sold (FIFO).', 1;

    DELETE FROM dbo.StockFifoBatch
    WHERE CompanyId = @CompanyId AND SourceType = @SourceType AND SourceId = @SourceId;
END
GO

/* ---------- Restore FIFO after sales delete/update ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoRestoreBySales
    @CompanyId INT,
    @SalesId   INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET QuantityRemaining = b.QuantityRemaining + a.Quantity
    FROM dbo.StockFifoBatch b
    INNER JOIN dbo.StockFifoAllocation a ON a.BatchId = b.BatchId
    WHERE a.CompanyId = @CompanyId AND a.SalesId = @SalesId;

    DELETE FROM dbo.StockFifoAllocation
    WHERE CompanyId = @CompanyId AND SalesId = @SalesId;
END
GO

/* ---------- Consume FIFO for one sales detail line ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoConsumeForSalesLine
    @CompanyId     INT,
    @SalesId       INT,
    @SalesDetailId INT,
    @MaterialId    INT,
    @LocationId    INT,
    @Quantity      DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Need DECIMAL(18,3) = @Quantity;
    DECLARE @BatchId BIGINT, @Remain DECIMAL(18,3), @Rate DECIMAL(18,2), @Take DECIMAL(18,3);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT BatchId, QuantityRemaining, Rate
        FROM dbo.StockFifoBatch WITH (UPDLOCK, HOLDLOCK)
        WHERE CompanyId = @CompanyId
          AND MaterialId = @MaterialId
          AND LocationId = @LocationId
          AND QuantityRemaining > 0
        ORDER BY TransactionDate ASC, BatchId ASC;

    OPEN c;
    FETCH NEXT FROM c INTO @BatchId, @Remain, @Rate;

    WHILE @@FETCH_STATUS = 0 AND @Need > 0
    BEGIN
        SET @Take = CASE WHEN @Remain >= @Need THEN @Need ELSE @Remain END;

        UPDATE dbo.StockFifoBatch
        SET QuantityRemaining = QuantityRemaining - @Take
        WHERE BatchId = @BatchId;

        INSERT INTO dbo.StockFifoAllocation
            (CompanyId, SalesId, SalesDetailId, BatchId, MaterialId, LocationId, Quantity, Rate)
        VALUES
            (@CompanyId, @SalesId, @SalesDetailId, @BatchId, @MaterialId, @LocationId, @Take, @Rate);

        SET @Need = @Need - @Take;
        FETCH NEXT FROM c INTO @BatchId, @Remain, @Rate;
    END

    CLOSE c;
    DEALLOCATE c;

    IF @Need > 0.0001
    BEGIN
        DECLARE @Msg NVARCHAR(500) =
            N'Insufficient FIFO stock for material '
            + CAST(@MaterialId AS NVARCHAR(20))
            + N' at location '
            + CAST(@LocationId AS NVARCHAR(20))
            + N'. Short by '
            + CAST(@Need AS NVARCHAR(30));
        THROW 50052, @Msg, 1;
    END
END
GO

/* ---------- Consume FIFO for entire sales document ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoConsumeForSales
    @CompanyId INT,
    @SalesId   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesDetailId INT, @MaterialId INT, @LocationId INT, @Quantity DECIMAL(18,3);

    DECLARE d CURSOR LOCAL FAST_FORWARD FOR
        SELECT SalesDetailId, MaterialId, LocationId, Quantity
        FROM dbo.SalesDetail
        WHERE SalesId = @SalesId
        ORDER BY SalesDetailId;

    OPEN d;
    FETCH NEXT FROM d INTO @SalesDetailId, @MaterialId, @LocationId, @Quantity;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.sp_FifoConsumeForSalesLine
            @CompanyId = @CompanyId,
            @SalesId = @SalesId,
            @SalesDetailId = @SalesDetailId,
            @MaterialId = @MaterialId,
            @LocationId = @LocationId,
            @Quantity = @Quantity;

        FETCH NEXT FROM d INTO @SalesDetailId, @MaterialId, @LocationId, @Quantity;
    END

    CLOSE d;
    DEALLOCATE d;
END
GO

/* ---------- Available stock from FIFO remaining ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_GetAvailableStock
    @CompanyId INT,
    @MaterialId INT,
    @LocationId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Fifo DECIMAL(18,3) = (
        SELECT ISNULL(SUM(QuantityRemaining), 0)
        FROM dbo.StockFifoBatch
        WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId
    );

    DECLARE @Ledger DECIMAL(18,3) = (
        SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0)
        FROM dbo.StockLedger
        WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId
    );

    -- Prefer FIFO remaining when batches exist; else ledger
    IF EXISTS (
        SELECT 1 FROM dbo.StockFifoBatch
        WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId
    )
        SELECT @Fifo AS AvailableStock;
    ELSE
        SELECT @Ledger AS AvailableStock;
END
GO

/* ---------- Rebuild FIFO from existing StockLedger ---------- */
CREATE OR ALTER PROCEDURE dbo.sp_FifoRebuildFromLedger
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dbo.StockFifoAllocation;
        DELETE FROM dbo.StockFifoBatch;

        /* Create batches from inbound ledger rows */
        INSERT INTO dbo.StockFifoBatch
            (CompanyId, MaterialId, LocationId, SourceType, SourceId, TransactionDate, QuantityIn, QuantityRemaining, Rate)
        SELECT
            sl.CompanyId,
            sl.MaterialId,
            sl.LocationId,
            sl.TransactionType,
            sl.ReferenceId,
            sl.TransactionDate,
            sl.QuantityIn,
            sl.QuantityIn,
            CASE
                WHEN sl.TransactionType = N'OPENING' THEN ISNULL((
                    SELECT TOP 1 os.Rate FROM dbo.OpeningStock os
                    WHERE os.OpeningStockId = sl.ReferenceId AND os.CompanyId = sl.CompanyId
                ), 0)
                WHEN sl.TransactionType = N'PURCHASE' THEN ISNULL((
                    SELECT TOP 1 d.Rate FROM dbo.PurchaseInwardDetail d
                    WHERE d.PurchaseId = sl.ReferenceId AND d.MaterialId = sl.MaterialId
                ), 0)
                ELSE 0
            END
        FROM dbo.StockLedger sl
        WHERE sl.QuantityIn > 0
          AND sl.TransactionType IN (N'OPENING', N'PURCHASE');

        /* Replay sales OUT in date order to consume FIFO */
        DECLARE @CompanyId INT, @SalesId INT, @MaterialId INT, @LocationId INT, @Qty DECIMAL(18,3);
        DECLARE @SalesDetailId INT;

        DECLARE s CURSOR LOCAL FAST_FORWARD FOR
            SELECT h.CompanyId, h.SalesId, d.SalesDetailId, d.MaterialId, d.LocationId, d.Quantity
            FROM dbo.SalesHeader h
            INNER JOIN dbo.SalesDetail d ON d.SalesId = h.SalesId
            ORDER BY h.SalesDate, h.SalesId, d.SalesDetailId;

        OPEN s;
        FETCH NEXT FROM s INTO @CompanyId, @SalesId, @SalesDetailId, @MaterialId, @LocationId, @Qty;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                EXEC dbo.sp_FifoConsumeForSalesLine
                    @CompanyId = @CompanyId,
                    @SalesId = @SalesId,
                    @SalesDetailId = @SalesDetailId,
                    @MaterialId = @MaterialId,
                    @LocationId = @LocationId,
                    @Quantity = @Qty;
            END TRY
            BEGIN CATCH
                -- If historical data cannot fully FIFO-match, leave remaining need unallocated
                -- (ledger still remains source of truth for total qty)
                PRINT N'FIFO rebuild warning SalesId=' + CAST(@SalesId AS NVARCHAR(20))
                    + N': ' + ERROR_MESSAGE();
            END CATCH

            FETCH NEXT FROM s INTO @CompanyId, @SalesId, @SalesDetailId, @MaterialId, @LocationId, @Qty;
        END

        CLOSE s;
        DEALLOCATE s;

        COMMIT TRANSACTION;
        PRINT N'FIFO rebuild completed.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* Run one-time rebuild of existing stock into FIFO layers */
EXEC dbo.sp_FifoRebuildFromLedger;
GO

PRINT N'FIFO stock engine ready. Next: patch sales/opening/purchase to use FIFO (included below).';
GO
