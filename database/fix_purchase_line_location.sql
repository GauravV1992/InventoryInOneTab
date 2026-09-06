/* Purchase Inward — warehouse LocationId on each line item */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.PurchaseInwardDetail', 'LocationId') IS NULL
    ALTER TABLE dbo.PurchaseInwardDetail ADD LocationId INT NULL;
GO

/* Backfill from header */
UPDATE d
SET LocationId = h.LocationId
FROM dbo.PurchaseInwardDetail d
INNER JOIN dbo.PurchaseInwardHeader h ON h.PurchaseId = d.PurchaseId
WHERE d.LocationId IS NULL AND h.LocationId IS NOT NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE LocationId IS NULL)
    RAISERROR(N'Some purchase lines still missing LocationId. Fix data before continuing.', 16, 1);
GO

ALTER TABLE dbo.PurchaseInwardDetail ALTER COLUMN LocationId INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInwardDetail_Location')
    ALTER TABLE dbo.PurchaseInwardDetail
        ADD CONSTRAINT FK_PurchaseInwardDetail_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PurchaseInwardDetail_LocationId' AND object_id = OBJECT_ID('dbo.PurchaseInwardDetail'))
    CREATE NONCLUSTERED INDEX IX_PurchaseInwardDetail_LocationId ON dbo.PurchaseInwardDetail(LocationId);
GO

/* Allow header LocationId to be the first line warehouse (nullable for flexibility) */
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.PurchaseInwardHeader') AND name = N'LocationId' AND is_nullable = 0
)
    ALTER TABLE dbo.PurchaseInwardHeader ALTER COLUMN LocationId INT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetPurchaseInward
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.PurchaseId, h.PurchaseNo, h.PurchaseDate,
        h.LocationId AS HeaderLocationId,
        hl.LocationName AS HeaderLocationName,
        h.SupplierName, h.Remark, h.CreatedAt,
        d.PurchaseDetailId, d.MaterialId, m.MaterialName, m.Unit,
        d.LocationId, l.LocationName,
        d.Quantity, d.Rate, d.Amount
    FROM dbo.PurchaseInwardHeader h
    LEFT JOIN dbo.WarehouseLocation hl ON hl.LocationId = h.LocationId AND hl.CompanyId = @CompanyId
    LEFT JOIN dbo.PurchaseInwardDetail d ON d.PurchaseId = h.PurchaseId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
    LEFT JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
    WHERE h.CompanyId = @CompanyId
    ORDER BY h.PurchaseDate DESC, h.PurchaseId DESC, d.PurchaseDetailId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_FifoSyncPurchaseBatches
    @CompanyId    INT,
    @PurchaseId   INT,
    @PurchaseDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.sp_FifoRemoveBatch', 'P') IS NOT NULL
        EXEC dbo.sp_FifoRemoveBatch @CompanyId = @CompanyId, @SourceType = N'PURCHASE', @SourceId = @PurchaseId;

    IF OBJECT_ID('dbo.sp_FifoAddOrReplaceBatch', 'P') IS NULL
        RETURN;

    DECLARE @MaterialId INT, @LocationId INT, @Qty DECIMAL(18,3), @Rate DECIMAL(18,2);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT MaterialId, LocationId, SUM(Quantity) AS Quantity, MAX(Rate) AS Rate
        FROM dbo.PurchaseInwardDetail
        WHERE PurchaseId = @PurchaseId
        GROUP BY MaterialId, LocationId;

    OPEN c;
    FETCH NEXT FROM c INTO @MaterialId, @LocationId, @Qty, @Rate;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.sp_FifoAddOrReplaceBatch
            @CompanyId = @CompanyId,
            @MaterialId = @MaterialId,
            @LocationId = @LocationId,
            @SourceType = N'PURCHASE',
            @SourceId = @PurchaseId,
            @TransactionDate = @PurchaseDate,
            @QuantityIn = @Qty,
            @Rate = @Rate;
        FETCH NEXT FROM c INTO @MaterialId, @LocationId, @Qty, @Rate;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePurchaseInward
    @CompanyId     INT,
    @PurchaseDate  DATE,
    @LocationId    INT = NULL,
    @SupplierName  NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @DetailsJson   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            WHERE COALESCE(j.MaterialId, j.MaterialId2) IS NULL
               OR COALESCE(j.LocationId, j.LocationId2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) <= 0
        )
            THROW 50012, N'Each line must have material, warehouse and quantity.', 1;

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId') j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2) AND l.CompanyId = @CompanyId AND l.IsActive = 1
            WHERE l.LocationId IS NULL
        )
            THROW 50002, N'Invalid or inactive warehouse on one or more lines.', 1;

        DECLARE @HeaderLocationId INT = @LocationId;
        IF @HeaderLocationId IS NULL
            SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
            FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @FyCode NVARCHAR(4) = dbo.fn_GetFinancialYearCode(@PurchaseDate);
        DECLARE @PeriodPrefix NVARCHAR(20) = N'PIN-' + @FyCode + N'-';
        DECLARE @NextNo INT = ISNULL((
            SELECT MAX(TRY_CAST(RIGHT(h.PurchaseNo, 4) AS INT))
            FROM dbo.PurchaseInwardHeader h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.CompanyId = @CompanyId
              AND h.PurchaseNo LIKE @PeriodPrefix + N'%'
        ), 0) + 1;
        SET @PurchaseNo = @PeriodPrefix + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        INSERT INTO dbo.PurchaseInwardHeader (CompanyId, PurchaseNo, PurchaseDate, LocationId, SupplierName, Remark)
        VALUES (@CompanyId, @PurchaseNo, @PurchaseDate, @HeaderLocationId, @SupplierName, @Remark);

        DECLARE @PurchaseId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, LocationId, Quantity, Rate)
        SELECT @PurchaseId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(LocationId, LocationId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found. Check material, warehouse and quantity.', 1;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d
        WHERE d.PurchaseId = @PurchaseId;

        IF @@ROWCOUNT = 0 THROW 50004, N'Stock ledger update failed for purchase inward.', 1;

        IF OBJECT_ID('dbo.sp_FifoSyncPurchaseBatches', 'P') IS NOT NULL
            EXEC dbo.sp_FifoSyncPurchaseBatches
                @CompanyId = @CompanyId,
                @PurchaseId = @PurchaseId,
                @PurchaseDate = @PurchaseDate;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdatePurchaseInward
    @CompanyId     INT,
    @PurchaseId    INT,
    @PurchaseDate  DATE,
    @LocationId    INT = NULL,
    @SupplierName  NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @DetailsJson   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId)
            THROW 50022, N'Purchase record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            WHERE COALESCE(j.MaterialId, j.MaterialId2) IS NULL
               OR COALESCE(j.LocationId, j.LocationId2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) <= 0
        )
            THROW 50012, N'Each line must have material, warehouse and quantity.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @StockError NVARCHAR(500);

        SELECT @PurchaseNo = PurchaseNo
        FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        -- Cannot remove stock already sold (per old line locations)
        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot update — quantity already used in sales)'
        FROM (
            SELECT MaterialId, LocationId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId
            GROUP BY MaterialId, LocationId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        IF OBJECT_ID('dbo.sp_FifoRemoveBatch', 'P') IS NOT NULL
            EXEC dbo.sp_FifoRemoveBatch @CompanyId = @CompanyId, @SourceType = N'PURCHASE', @SourceId = @PurchaseId;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId AND CompanyId = @CompanyId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;

        DECLARE @HeaderLocationId INT = @LocationId;
        IF @HeaderLocationId IS NULL
            SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
            FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        UPDATE dbo.PurchaseInwardHeader
        SET PurchaseDate = @PurchaseDate, LocationId = @HeaderLocationId,
            SupplierName = @SupplierName, Remark = @Remark
        WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, LocationId, Quantity, Rate)
        SELECT @PurchaseId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(LocationId, LocationId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found.', 1;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d WHERE d.PurchaseId = @PurchaseId;

        IF OBJECT_ID('dbo.sp_FifoSyncPurchaseBatches', 'P') IS NOT NULL
            EXEC dbo.sp_FifoSyncPurchaseBatches
                @CompanyId = @CompanyId,
                @PurchaseId = @PurchaseId,
                @PurchaseDate = @PurchaseDate;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeletePurchaseInward
    @CompanyId INT,
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId)
            THROW 50020, N'Purchase record not found.', 1;

        DECLARE @StockError NVARCHAR(500);

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot delete — quantity already used in sales)'
        FROM (
            SELECT MaterialId, LocationId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId
            GROUP BY MaterialId, LocationId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        IF OBJECT_ID('dbo.sp_FifoRemoveBatch', 'P') IS NOT NULL
            EXEC dbo.sp_FifoRemoveBatch @CompanyId = @CompanyId, @SourceType = N'PURCHASE', @SourceId = @PurchaseId;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId AND CompanyId = @CompanyId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT N'Purchase line-level warehouse LocationId applied.';
GO
