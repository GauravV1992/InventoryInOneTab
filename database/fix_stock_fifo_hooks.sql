/* ============================================================
   FIFO hooks — Opening / Purchase IN + Sales OUT (FIFO order)
   Run AFTER fix_stock_fifo.sql
   ============================================================ */
USE PawanPutra;
GO

/* ===================== OPENING STOCK ===================== */
CREATE OR ALTER PROCEDURE dbo.sp_SaveOpeningStock
    @CompanyId      INT,
    @OpeningStockId INT = NULL,
    @MaterialId     INT,
    @LocationId     INT,
    @Quantity       DECIMAL(18,3),
    @Rate           DECIMAL(18,2) = NULL,
    @StockDate      DATE = NULL,
    @Remark         NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @StockDate IS NULL SET @StockDate = dbo.fn_GetIndiaDate();

    IF NOT EXISTS (SELECT 1 FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN RAISERROR(N'Invalid material.', 16, 1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN RAISERROR(N'Invalid warehouse location.', 16, 1); RETURN; END

    IF @Rate IS NULL
        SELECT @Rate = Rate FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId;
    SET @Rate = ISNULL(@Rate, 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @OpeningStockId IS NULL OR @OpeningStockId = 0
            SELECT @OpeningStockId = OpeningStockId
            FROM dbo.OpeningStock
            WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId;

        IF @OpeningStockId IS NULL
        BEGIN
            INSERT INTO dbo.OpeningStock (CompanyId, MaterialId, LocationId, Quantity, Rate, StockDate, Remark)
            VALUES (@CompanyId, @MaterialId, @LocationId, @Quantity, @Rate, @StockDate, @Remark);
            SET @OpeningStockId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId)
            BEGIN RAISERROR(N'Opening stock record not found.', 16, 1); RETURN; END

            UPDATE dbo.OpeningStock
            SET MaterialId = @MaterialId, LocationId = @LocationId, Quantity = @Quantity,
                Rate = @Rate, StockDate = @StockDate, Remark = @Remark
            WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;

            DELETE FROM dbo.StockLedger
            WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;
        END

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        VALUES (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);

        EXEC dbo.sp_FifoAddOrReplaceBatch
            @CompanyId = @CompanyId,
            @MaterialId = @MaterialId,
            @LocationId = @LocationId,
            @SourceType = N'OPENING',
            @SourceId = @OpeningStockId,
            @TransactionDate = @StockDate,
            @QuantityIn = @Quantity,
            @Rate = @Rate;

        COMMIT TRANSACTION;
        SELECT @OpeningStockId AS OpeningStockId, @Rate AS Rate;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ===================== PURCHASE — line-level warehouse + FIFO ===================== */
/* Prefer running fix_purchase_line_location.sql for full Update/Delete procs.
   This block keeps FIFO hooks aligned if re-applied after that migration. */

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

/* ===================== SALES — FIFO consume after order ===================== */
CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
    @CompanyId         INT,
    @SalesDate         DATE,
    @CustomerName      NVARCHAR(150) = NULL,
    @Remark            NVARCHAR(500) = NULL,
    @TermsAndConditions NVARCHAR(MAX) = NULL,
    @DetailsJson       NVARCHAR(MAX),
    @GSTRate           DECIMAL(18,2) = 0,
    @DiscountType      NVARCHAR(10) = NULL,
    @DiscountPercent   DECIMAL(18,2) = 0,
    @DiscountAmount    DECIMAL(18,2) = 0,
    @RoundOff          DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

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
            THROW 50012, N'Each line must have material, warehouse location and quantity.', 1;

        DECLARE @StockError NVARCHAR(500);

        -- Validate against FIFO remaining (oldest batches)
        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT COALESCE(j.MaterialId, j.MaterialId2) AS MaterialId,
                   COALESCE(j.LocationId, j.LocationId2) AS LocationId,
                   SUM(COALESCE(j.Quantity, j.Quantity2)) AS TotalQty
            FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            GROUP BY COALESCE(j.MaterialId, j.MaterialId2), COALESCE(j.LocationId, j.LocationId2)
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(b.QuantityRemaining), 0) AS Avail
            FROM dbo.StockFifoBatch b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.CompanyId = @CompanyId AND b.MaterialId = d.MaterialId AND b.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL THROW 50014, @StockError, 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @FyCode NVARCHAR(4) = dbo.fn_GetFinancialYearCode(@SalesDate);
        DECLARE @PeriodPrefix NVARCHAR(20) = N'SAL-' + @FyCode + N'-';
        DECLARE @NextNo INT = ISNULL((
            SELECT MAX(TRY_CAST(RIGHT(h.SalesNo, 4) AS INT))
            FROM dbo.SalesHeader h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.CompanyId = @CompanyId
              AND h.SalesNo LIKE @PeriodPrefix + N'%'
        ), 0) + 1;
        SET @SalesNo = @PeriodPrefix + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson) WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        INSERT INTO dbo.SalesHeader (CompanyId, SalesNo, SalesDate, LocationId, CustomerName, Remark, TermsAndConditions)
        VALUES (@CompanyId, @SalesNo, @SalesDate, @HeaderLocationId, @CustomerName, @Remark, @TermsAndConditions);

        DECLARE @SalesId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId, COALESCE(MaterialId, MaterialId2), COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
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

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
            THROW 50015, N'No valid sales items found.', 1;

        DECLARE @SubTotal DECIMAL(18,2);
        DECLARE @DiscountValue DECIMAL(18,2);
        DECLARE @TaxableAmount DECIMAL(18,2);
        DECLARE @GSTAmount DECIMAL(18,2);
        DECLARE @GrandTotal DECIMAL(18,2);

        SELECT @SubTotal = ISNULL(SUM(Amount), 0) FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        IF UPPER(ISNULL(@DiscountType, N'')) = N'PERCENT'
            SET @DiscountValue = ROUND(@SubTotal * ISNULL(@DiscountPercent, 0) / 100.0, 2);
        ELSE IF UPPER(ISNULL(@DiscountType, N'')) = N'AMOUNT'
            SET @DiscountValue = ISNULL(@DiscountAmount, 0);
        ELSE SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET SubTotal = @SubTotal, DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0), DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue, GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount, RoundOff = ISNULL(@RoundOff, 0), GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        -- Stock ledger OUT
        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0 THROW 50016, N'Stock ledger update failed for sales.', 1;

        -- FIFO consume: oldest opening/purchase batches first
        EXEC dbo.sp_FifoConsumeForSales @CompanyId = @CompanyId, @SalesId = @SalesId;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSales
    @CompanyId INT,
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId)
            THROW 50030, N'Sales record not found.', 1;

        -- Restore FIFO batches before removing sale
        EXEC dbo.sp_FifoRestoreBySales @CompanyId = @CompanyId, @SalesId = @SalesId;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId AND CompanyId = @CompanyId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;
        DELETE FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId;
        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateSales
    @CompanyId INT,
    @SalesId INT,
    @SalesDate DATE,
    @CustomerName NVARCHAR(150) = NULL,
    @Remark NVARCHAR(500) = NULL,
    @TermsAndConditions NVARCHAR(MAX) = NULL,
    @DetailsJson NVARCHAR(MAX),
    @GSTRate DECIMAL(18,2) = 0,
    @DiscountType NVARCHAR(10) = NULL,
    @DiscountPercent DECIMAL(18,2) = 0,
    @DiscountAmount DECIMAL(18,2) = 0,
    @RoundOff DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId)
            THROW 50031, N'Sales record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        DECLARE @SalesNo NVARCHAR(30);
        SELECT @SalesNo = SalesNo FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        -- Put stock back (FIFO restore), then re-apply new lines
        EXEC dbo.sp_FifoRestoreBySales @CompanyId = @CompanyId, @SalesId = @SalesId;
        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId AND CompanyId = @CompanyId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        UPDATE dbo.SalesHeader
        SET SalesDate = @SalesDate, CustomerName = @CustomerName, Remark = @Remark,
            TermsAndConditions = @TermsAndConditions
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId, COALESCE(MaterialId, MaterialId2), COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
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

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
            THROW 50015, N'No valid sales items found.', 1;

        DECLARE @StockError NVARCHAR(500);
        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT MaterialId, LocationId, SUM(Quantity) AS TotalQty
            FROM dbo.SalesDetail WHERE SalesId = @SalesId
            GROUP BY MaterialId, LocationId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(b.QuantityRemaining), 0) AS Avail
            FROM dbo.StockFifoBatch b WITH (UPDLOCK, HOLDLOCK)
            WHERE b.CompanyId = @CompanyId AND b.MaterialId = d.MaterialId AND b.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL THROW 50014, @StockError, 1;

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = LocationId FROM dbo.SalesDetail WHERE SalesId = @SalesId ORDER BY SalesDetailId;

        DECLARE @SubTotal DECIMAL(18,2);
        DECLARE @DiscountValue DECIMAL(18,2);
        DECLARE @TaxableAmount DECIMAL(18,2);
        DECLARE @GSTAmount DECIMAL(18,2);
        DECLARE @GrandTotal DECIMAL(18,2);

        SELECT @SubTotal = ISNULL(SUM(Amount), 0) FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        IF UPPER(ISNULL(@DiscountType, N'')) = N'PERCENT'
            SET @DiscountValue = ROUND(@SubTotal * ISNULL(@DiscountPercent, 0) / 100.0, 2);
        ELSE IF UPPER(ISNULL(@DiscountType, N'')) = N'AMOUNT'
            SET @DiscountValue = ISNULL(@DiscountAmount, 0);
        ELSE SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET LocationId = @HeaderLocationId,
            SubTotal = @SubTotal, DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0), DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue, GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount, RoundOff = ISNULL(@RoundOff, 0), GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        EXEC dbo.sp_FifoConsumeForSales @CompanyId = @CompanyId, @SalesId = @SalesId;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* Fix RemoveBatch: allow replace when no allocations — SyncPurchase deletes then re-adds.
   When purchase has no prior batch, RemoveBatch is no-op. When allocated, throw.
   Sync calls RemoveBatch first — if old purchase was never FIFO-synced, OK.
   If partially sold, throw — correct. */

PRINT N'FIFO hooks applied: Opening IN, Purchase IN, Sales OUT (FIFO), Sales delete/update restore.';
GO
