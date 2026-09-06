/* ============================================================
   Sales - GST, Discount, Round Off
   Run manually in SSMS on PawanPutra database
   ============================================================ */
USE PawanPutra;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'SubTotal')
    ALTER TABLE dbo.SalesHeader ADD SubTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_SubTotal DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'DiscountType')
    ALTER TABLE dbo.SalesHeader ADD DiscountType NVARCHAR(10) NULL;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'DiscountPercent')
    ALTER TABLE dbo.SalesHeader ADD DiscountPercent DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_DiscountPercent DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'DiscountAmount')
    ALTER TABLE dbo.SalesHeader ADD DiscountAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_DiscountAmount DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'DiscountValue')
    ALTER TABLE dbo.SalesHeader ADD DiscountValue DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_DiscountValue DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'GSTRate')
    ALTER TABLE dbo.SalesHeader ADD GSTRate DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_GSTRate DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'GSTAmount')
    ALTER TABLE dbo.SalesHeader ADD GSTAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_GSTAmount DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'RoundOff')
    ALTER TABLE dbo.SalesHeader ADD RoundOff DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_RoundOff DEFAULT 0;
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'GrandTotal')
    ALTER TABLE dbo.SalesHeader ADD GrandTotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_SalesHeader_GrandTotal DEFAULT 0;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetSales
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.SalesId, h.SalesNo, h.SalesDate, h.LocationId,
        hl.LocationName AS HeaderLocationName,
        h.CustomerName, h.Remark, h.CreatedAt,
        h.SubTotal, h.DiscountType, h.DiscountPercent, h.DiscountAmount, h.DiscountValue,
        h.GSTRate, h.GSTAmount, h.RoundOff, h.GrandTotal,
        d.SalesDetailId, d.MaterialId, m.MaterialName, m.Unit, m.HSNCode,
        d.LocationId AS DetailLocationId,
        dl.LocationName AS DetailLocationName,
        d.Quantity, d.Rate, d.Amount
    FROM dbo.SalesHeader h
    LEFT JOIN dbo.WarehouseLocation hl ON hl.LocationId = h.LocationId
    LEFT JOIN dbo.SalesDetail d ON d.SalesId = h.SalesId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
    LEFT JOIN dbo.WarehouseLocation dl ON dl.LocationId = d.LocationId
    ORDER BY h.SalesDate DESC, h.SalesId DESC, d.SalesDetailId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
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
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId') j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2) AND l.IsActive = 1
            WHERE l.LocationId IS NULL
        )
            THROW 50013, N'Invalid or inactive warehouse on one or more lines.', 1;

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
            WHERE sl.MaterialId = d.MaterialId
              AND sl.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL
            THROW 50014, @StockError, 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @NextNo INT = ISNULL((SELECT MAX(SalesId) FROM dbo.SalesHeader WITH (UPDLOCK, HOLDLOCK)), 0) + 1;
        SET @SalesNo = N'SAL-' + FORMAT(GETDATE(), 'yyyyMM') + N'-' + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson)
        WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        INSERT INTO dbo.SalesHeader (SalesNo, SalesDate, LocationId, CustomerName, Remark)
        VALUES (@SalesNo, @SalesDate, @HeaderLocationId, @CustomerName, @Remark);

        DECLARE @SalesId INT = SCOPE_IDENTITY();

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

        IF @@ROWCOUNT = 0
            THROW 50016, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;

        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Sales GST, Discount, RoundOff columns and procedures updated.';
GO
