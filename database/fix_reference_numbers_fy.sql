/* Purchase & Sales reference numbers — reset each financial year (Apr–Mar, India FY) */
USE PawanPutra;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaNow()
RETURNS DATETIME2
AS
BEGIN
    RETURN DATEADD(MINUTE, 330, SYSUTCDATETIME());
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaDate()
RETURNS DATE
AS
BEGIN
    RETURN CAST(DATEADD(MINUTE, 330, SYSUTCDATETIME()) AS DATE);
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetFinancialYearCode(@Date DATE)
RETURNS NVARCHAR(4)
AS
BEGIN
    IF @Date IS NULL SET @Date = dbo.fn_GetIndiaDate();

    DECLARE @Year INT = YEAR(@Date);
    DECLARE @StartYear INT = CASE WHEN MONTH(@Date) >= 4 THEN @Year ELSE @Year - 1 END;
    DECLARE @EndYear INT = @StartYear + 1;

    RETURN RIGHT(N'00' + CAST(@StartYear % 100 AS NVARCHAR(2)), 2)
         + RIGHT(N'00' + CAST(@EndYear % 100 AS NVARCHAR(2)), 2);
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePurchaseInward
    @CompanyId     INT,
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

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

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
        VALUES (@CompanyId, @PurchaseNo, @PurchaseDate, @LocationId, @SupplierName, @Remark);

        DECLARE @PurchaseId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, Quantity, Rate)
        SELECT @PurchaseId, COALESCE(MaterialId, MaterialId2), COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found. Check material and quantity.', 1;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d
        WHERE d.PurchaseId = @PurchaseId;

        IF @@ROWCOUNT = 0 THROW 50004, N'Stock ledger update failed for purchase inward.', 1;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
    @CompanyId         INT,
    @SalesDate         DATE,
    @CustomerName      NVARCHAR(150) = NULL,
    @Remark            NVARCHAR(500) = NULL,
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

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId', MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId') j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2) AND l.CompanyId = @CompanyId AND l.IsActive = 1
            LEFT JOIN dbo.MaterialMaster m
                ON m.MaterialId = COALESCE(j.MaterialId, j.MaterialId2) AND m.CompanyId = @CompanyId AND m.IsActive = 1
            WHERE l.LocationId IS NULL OR m.MaterialId IS NULL
        )
            THROW 50013, N'Invalid or inactive warehouse on one or more lines.', 1;

        DECLARE @StockError NVARCHAR(500);

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
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
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

        INSERT INTO dbo.SalesHeader (CompanyId, SalesNo, SalesDate, LocationId, CustomerName, Remark)
        VALUES (@CompanyId, @SalesNo, @SalesDate, @HeaderLocationId, @CustomerName, @Remark);

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

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0 THROW 50016, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Financial-year reference numbers applied (PIN-2526-0001 / SAL-2526-0001). Resets from 0001 each Apr–Mar FY.';
GO
