/* Purchase & Sales edit/delete with stock validation */
USE PawanPutra;
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeletePurchaseInward
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId)
            THROW 50020, N'Purchase record not found.', 1;

        DECLARE @LocationId INT;
        DECLARE @StockError NVARCHAR(500);

        SELECT @LocationId = LocationId FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot delete — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail
            WHERE PurchaseId = @PurchaseId
            GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @LocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @LocationId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL
            THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger
        WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId;

        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdatePurchaseInward
    @PurchaseId    INT,
    @PurchaseDate  DATE,
    @LocationId    INT,
    @SupplierName  NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @DetailsJson   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId)
            THROW 50022, N'Purchase record not found.', 1;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @OldLocationId INT;
        DECLARE @StockError NVARCHAR(500);

        SELECT @PurchaseNo = PurchaseNo, @OldLocationId = LocationId
        FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot update — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail
            WHERE PurchaseId = @PurchaseId
            GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @OldLocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @OldLocationId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL
            THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger
        WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId;

        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;

        UPDATE dbo.PurchaseInwardHeader
        SET PurchaseDate = @PurchaseDate,
            LocationId = @LocationId,
            SupplierName = @SupplierName,
            Remark = @Remark
        WHERE PurchaseId = @PurchaseId;

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, Quantity, Rate)
        SELECT @PurchaseId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId  INT             '$.MaterialId',
            MaterialId2 INT             '$.materialId',
            Quantity    DECIMAL(18,3)   '$.Quantity',
            Quantity2   DECIMAL(18,3)   '$.quantity',
            Rate        DECIMAL(18,2)   '$.Rate',
            Rate2       DECIMAL(18,2)   '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found.', 1;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d
        WHERE d.PurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSales
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId)
            THROW 50030, N'Sales record not found.', 1;

        DELETE FROM dbo.StockLedger
        WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId;

        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;
        DELETE FROM dbo.SalesHeader WHERE SalesId = @SalesId;

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
    @SalesId          INT,
    @SalesDate        DATE,
    @CustomerName     NVARCHAR(150) = NULL,
    @Remark           NVARCHAR(500) = NULL,
    @DetailsJson      NVARCHAR(MAX),
    @GSTRate          DECIMAL(18,2) = 0,
    @DiscountType     NVARCHAR(10) = NULL,
    @DiscountPercent  DECIMAL(18,2) = 0,
    @DiscountAmount   DECIMAL(18,2) = 0,
    @RoundOff         DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId)
            THROW 50031, N'Sales record not found.', 1;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        DECLARE @SalesNo NVARCHAR(30);
        SELECT @SalesNo = SalesNo FROM dbo.SalesHeader WHERE SalesId = @SalesId;

        DELETE FROM dbo.StockLedger
        WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId;

        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;

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

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT
                COALESCE(j.MaterialId, j.MaterialId2) AS MaterialId,
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
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL
            THROW 50014, @StockError, 1;

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson)
        WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        UPDATE dbo.SalesHeader
        SET SalesDate = @SalesDate,
            LocationId = @HeaderLocationId,
            CustomerName = @CustomerName,
            Remark = @Remark
        WHERE SalesId = @SalesId;

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId  INT             '$.MaterialId',
            MaterialId2 INT             '$.materialId',
            LocationId  INT             '$.LocationId',
            LocationId2 INT             '$.locationId',
            Quantity    DECIMAL(18,3)   '$.Quantity',
            Quantity2   DECIMAL(18,3)   '$.quantity',
            Rate        DECIMAL(18,2)   '$.Rate',
            Rate2       DECIMAL(18,2)   '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(LocationId, LocationId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

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
        ELSE
            SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET SubTotal = @SubTotal,
            DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0),
            DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue,
            GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount,
            RoundOff = ISNULL(@RoundOff, 0),
            GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Purchase/Sales edit & delete procedures created.';
GO
