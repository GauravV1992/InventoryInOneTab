/* Stock segregated by CompanyId — ledger, opening stock, reports & availability */
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

IF COL_LENGTH('dbo.OpeningStock', 'CompanyId') IS NULL
    ALTER TABLE dbo.OpeningStock ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.StockLedger', 'CompanyId') IS NULL
    ALTER TABLE dbo.StockLedger ADD CompanyId INT NULL;
GO

DECLARE @DefaultCompanyId INT = (SELECT TOP 1 CompanyId FROM dbo.CompanyMaster ORDER BY CompanyId);

UPDATE os SET CompanyId = m.CompanyId
FROM dbo.OpeningStock os
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId
WHERE os.CompanyId IS NULL OR os.CompanyId <> m.CompanyId;

UPDATE os SET CompanyId = @DefaultCompanyId
FROM dbo.OpeningStock os
WHERE os.CompanyId IS NULL AND @DefaultCompanyId IS NOT NULL;

UPDATE sl SET CompanyId = m.CompanyId
FROM dbo.StockLedger sl
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = sl.MaterialId
WHERE sl.CompanyId IS NULL OR sl.CompanyId <> m.CompanyId;

UPDATE sl SET CompanyId = @DefaultCompanyId
FROM dbo.StockLedger sl
WHERE sl.CompanyId IS NULL AND @DefaultCompanyId IS NOT NULL;
GO

IF EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE CompanyId IS NULL)
    RAISERROR(N'OpeningStock rows still missing CompanyId. Fix data manually before continuing.', 16, 1);
IF EXISTS (SELECT 1 FROM dbo.StockLedger WHERE CompanyId IS NULL)
    RAISERROR(N'StockLedger rows still missing CompanyId. Fix data manually before continuing.', 16, 1);
GO

ALTER TABLE dbo.OpeningStock ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.StockLedger ALTER COLUMN CompanyId INT NOT NULL;
GO

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('dbo.OpeningStock') AND name = N'UQ_OpeningStock_MaterialLocation')
    ALTER TABLE dbo.OpeningStock DROP CONSTRAINT UQ_OpeningStock_MaterialLocation;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_OpeningStock_CompanyMaterialLocation' AND object_id = OBJECT_ID('dbo.OpeningStock'))
    CREATE UNIQUE INDEX UQ_OpeningStock_CompanyMaterialLocation ON dbo.OpeningStock(CompanyId, MaterialId, LocationId);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockLedger_CompanyMaterialLocation' AND object_id = OBJECT_ID('dbo.StockLedger'))
    CREATE INDEX IX_StockLedger_CompanyMaterialLocation ON dbo.StockLedger(CompanyId, MaterialId, LocationId);
GO

CREATE OR ALTER VIEW dbo.vw_StockSummary
AS
SELECT
    m.CompanyId,
    m.MaterialId,
    m.MaterialName,
    m.Color,
    m.HSNCode,
    m.Rate,
    m.Unit,
    l.LocationId,
    l.LocationName,
    ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS CurrentStock
FROM dbo.MaterialMaster m
INNER JOIN dbo.WarehouseLocation l ON l.CompanyId = m.CompanyId
LEFT JOIN dbo.StockLedger sl
    ON sl.MaterialId = m.MaterialId
   AND sl.LocationId = l.LocationId
   AND sl.CompanyId = m.CompanyId
WHERE m.IsActive = 1 AND l.IsActive = 1
GROUP BY
    m.CompanyId, m.MaterialId, m.MaterialName, m.Color, m.HSNCode, m.Rate, m.Unit,
    l.LocationId, l.LocationName;
GO

CREATE OR ALTER VIEW dbo.vw_StockReport
AS
SELECT
    sl.CompanyId,
    sl.LedgerId,
    sl.TransactionDate,
    sl.TransactionType,
    sl.ReferenceNo,
    m.MaterialId,
    m.MaterialName,
    m.Color,
    m.HSNCode,
    m.Unit,
    l.LocationId,
    l.LocationName,
    sl.QuantityIn,
    sl.QuantityOut,
    (sl.QuantityIn - sl.QuantityOut) AS NetQty
FROM dbo.StockLedger sl
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = sl.MaterialId AND m.CompanyId = sl.CompanyId
INNER JOIN dbo.WarehouseLocation l ON l.LocationId = sl.LocationId AND l.CompanyId = sl.CompanyId;
GO

CREATE OR ALTER VIEW dbo.vw_MaterialStockByLocation
AS
SELECT
    CompanyId,
    MaterialId,
    MaterialName,
    Color,
    HSNCode,
    Rate,
    Unit,
    LocationId,
    LocationName,
    CurrentStock,
    CASE WHEN CurrentStock <= 0 THEN N'Out of Stock'
         WHEN CurrentStock < 10 THEN N'Low Stock'
         ELSE N'In Stock' END AS StockStatus
FROM dbo.vw_StockSummary;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetOpeningStock
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        os.OpeningStockId,
        os.MaterialId,
        m.MaterialName,
        m.Color,
        m.HSNCode,
        m.Unit,
        os.LocationId,
        l.LocationName,
        os.Quantity,
        ISNULL(os.Rate, 0) AS Rate,
        CAST(os.Quantity * ISNULL(os.Rate, 0) AS DECIMAL(18,2)) AS Amount,
        os.StockDate,
        os.Remark,
        os.CreatedAt
    FROM dbo.OpeningStock os
    INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId AND m.CompanyId = @CompanyId
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = os.LocationId AND l.CompanyId = @CompanyId
    WHERE os.CompanyId = @CompanyId
    ORDER BY os.StockDate DESC, os.OpeningStockId DESC;
END
GO

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
        BEGIN
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
                UPDATE dbo.OpeningStock
                SET Quantity = @Quantity, Rate = @Rate, StockDate = @StockDate, Remark = @Remark
                WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;
                DELETE FROM dbo.StockLedger
                WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;
            END

            INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
            VALUES (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId)
            BEGIN RAISERROR(N'Opening stock record not found.', 16, 1); RETURN; END

            UPDATE dbo.OpeningStock
            SET MaterialId = @MaterialId, LocationId = @LocationId, Quantity = @Quantity,
                Rate = @Rate, StockDate = @StockDate, Remark = @Remark
            WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;

            DELETE FROM dbo.StockLedger WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;

            INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
            VALUES (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);
        END

        COMMIT TRANSACTION;
        SELECT @OpeningStockId AS OpeningStockId, @Rate AS Rate;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAvailableStock
    @CompanyId INT,
    @MaterialId INT,
    @LocationId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0) AS AvailableStock
    FROM dbo.StockLedger
    WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockByMaterial
    @CompanyId INT,
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Material not found.', 16, 1);
        RETURN;
    END

    SELECT l.LocationId, l.LocationName,
           ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS AvailableStock
    FROM dbo.WarehouseLocation l
    LEFT JOIN dbo.StockLedger sl
        ON sl.LocationId = l.LocationId AND sl.MaterialId = @MaterialId AND sl.CompanyId = @CompanyId
    WHERE l.IsActive = 1 AND l.CompanyId = @CompanyId
    GROUP BY l.LocationId, l.LocationName
    ORDER BY l.LocationName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockReport
    @CompanyId INT,
    @LocationId INT = NULL,
    @MaterialId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaterialId, MaterialName, Color, HSNCode, Rate, Unit,
           LocationId, LocationName, CurrentStock, StockStatus
    FROM dbo.vw_MaterialStockByLocation
    WHERE CompanyId = @CompanyId
      AND (@LocationId IS NULL OR LocationId = @LocationId)
      AND (@MaterialId IS NULL OR MaterialId = @MaterialId)
    ORDER BY LocationName, MaterialName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockLedgerReport
    @CompanyId INT,
    @LocationId INT = NULL,
    @FromDate   DATE = NULL,
    @ToDate     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -1, dbo.fn_GetIndiaNow());
    IF @ToDate IS NULL SET @ToDate = dbo.fn_GetIndiaNow();

    SELECT LedgerId, TransactionDate, TransactionType, ReferenceNo,
           MaterialId, MaterialName, Color, HSNCode, Unit,
           LocationId, LocationName, QuantityIn, QuantityOut, NetQty
    FROM dbo.vw_StockReport
    WHERE CompanyId = @CompanyId
      AND (@LocationId IS NULL OR LocationId = @LocationId)
      AND TransactionDate BETWEEN @FromDate AND @ToDate
    ORDER BY TransactionDate DESC, LedgerId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetDashboardStats
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.MaterialMaster WHERE IsActive = 1 AND CompanyId = @CompanyId) AS TotalMaterials,
        (SELECT COUNT(*) FROM dbo.WarehouseLocation WHERE IsActive = 1 AND CompanyId = @CompanyId) AS TotalLocations,
        (SELECT COUNT(*) FROM dbo.PurchaseInwardHeader WHERE CompanyId = @CompanyId) AS TotalPurchases,
        (SELECT COUNT(*) FROM dbo.SalesHeader WHERE CompanyId = @CompanyId) AS TotalSales,
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.vw_StockSummary WHERE CompanyId = @CompanyId) AS TotalStockQty,
        (SELECT COUNT(*) FROM dbo.vw_MaterialStockByLocation WHERE CompanyId = @CompanyId AND StockStatus = N'Low Stock') AS LowStockItems;
END
GO

PRINT 'Company-scoped stock views and procedures applied.';
GO
