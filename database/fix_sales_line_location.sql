/* ============================================================
   Sales - Warehouse location per line item
   Run manually in SSMS on PawanPutra database
   ============================================================ */
USE PawanPutra;
GO

/* Add LocationId to SalesDetail */
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.SalesDetail') AND name = N'LocationId'
)
BEGIN
    ALTER TABLE dbo.SalesDetail ADD LocationId INT NULL;

    UPDATE d
    SET d.LocationId = h.LocationId
    FROM dbo.SalesDetail d
    INNER JOIN dbo.SalesHeader h ON h.SalesId = d.SalesId;

    ALTER TABLE dbo.SalesDetail ALTER COLUMN LocationId INT NOT NULL;

    ALTER TABLE dbo.SalesDetail
    ADD CONSTRAINT FK_SalesDetail_Location
    FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
END
GO

/* Header location optional (line items carry warehouse) */
IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.SalesHeader') AND name = N'LocationId'
)
BEGIN
    ALTER TABLE dbo.SalesHeader ALTER COLUMN LocationId INT NULL;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockByMaterial
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.LocationId,
        l.LocationName,
        ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS AvailableStock
    FROM dbo.WarehouseLocation l
    LEFT JOIN dbo.StockLedger sl
        ON sl.LocationId = l.LocationId
       AND sl.MaterialId = @MaterialId
    WHERE l.IsActive = 1
    GROUP BY l.LocationId, l.LocationName
    ORDER BY l.LocationName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetSales
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.SalesId, h.SalesNo, h.SalesDate, h.LocationId,
        hl.LocationName AS HeaderLocationName,
        h.CustomerName, h.Remark, h.CreatedAt,
        d.SalesDetailId, d.MaterialId, m.MaterialName, m.Unit,
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
    @SalesDate    DATE,
    @CustomerName NVARCHAR(150) = NULL,
    @Remark       NVARCHAR(500) = NULL,
    @DetailsJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@DetailsJson)
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
            SELECT 1
            FROM OPENJSON(@DetailsJson)
            WITH (
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId'
            ) j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2)
               AND l.IsActive = 1
            WHERE l.LocationId IS NULL
        )
            THROW 50013, N'Invalid or inactive warehouse on one or more lines.', 1;

        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            CROSS APPLY (
                SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
                FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
                WHERE sl.MaterialId = COALESCE(j.MaterialId, j.MaterialId2)
                  AND sl.LocationId = COALESCE(j.LocationId, j.LocationId2)
            ) s
            WHERE COALESCE(j.Quantity, j.Quantity2) > s.Avail
        )
            THROW 50014, N'Insufficient stock for one or more items at selected warehouse.', 1;

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
        SELECT
            @SalesId,
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

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d
        WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0
            THROW 50016, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;

        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Sales line-level warehouse location applied.';
GO
