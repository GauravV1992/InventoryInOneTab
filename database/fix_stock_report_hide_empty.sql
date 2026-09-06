/*
  Stock report was a full material × warehouse grid, so most rows were
  unused "Out of Stock" (never stocked at that location).

  Only keep material + warehouse pairs that have ledger history.
  Run on SQL Server (PawanPutra).
*/
SET NOCOUNT ON;
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
    SUM(sl.QuantityIn - sl.QuantityOut) AS CurrentStock
FROM dbo.StockLedger sl
INNER JOIN dbo.MaterialMaster m
    ON m.MaterialId = sl.MaterialId
   AND m.CompanyId = sl.CompanyId
   AND m.IsActive = 1
INNER JOIN dbo.WarehouseLocation l
    ON l.LocationId = sl.LocationId
   AND l.CompanyId = sl.CompanyId
   AND l.IsActive = 1
GROUP BY
    m.CompanyId, m.MaterialId, m.MaterialName, m.Color, m.HSNCode, m.Rate, m.Unit,
    l.LocationId, l.LocationName;
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
    ORDER BY
        CASE WHEN CurrentStock > 0 THEN 0 ELSE 1 END,
        LocationName,
        MaterialName;
END
GO
