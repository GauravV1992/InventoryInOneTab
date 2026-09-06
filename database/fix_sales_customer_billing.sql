/* Sales — optional customer Address1, Address2, GST No (per sale, no master) */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.SalesHeader', 'CustomerAddress1') IS NULL
    ALTER TABLE dbo.SalesHeader ADD CustomerAddress1 NVARCHAR(250) NULL;
IF COL_LENGTH('dbo.SalesHeader', 'CustomerAddress2') IS NULL
    ALTER TABLE dbo.SalesHeader ADD CustomerAddress2 NVARCHAR(250) NULL;
IF COL_LENGTH('dbo.SalesHeader', 'CustomerGSTNo') IS NULL
    ALTER TABLE dbo.SalesHeader ADD CustomerGSTNo NVARCHAR(30) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetSales
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        h.SalesId, h.SalesNo, h.SalesDate, h.LocationId,
        hl.LocationName AS HeaderLocationName,
        h.CustomerName,
        h.CustomerAddress1, h.CustomerAddress2, h.CustomerGSTNo,
        h.Remark, h.TermsAndConditions, h.CreatedAt,
        h.SubTotal, h.DiscountType, h.DiscountPercent, h.DiscountAmount, h.DiscountValue,
        h.GSTRate, h.GSTAmount, h.RoundOff, h.GrandTotal,
        d.SalesDetailId, d.MaterialId, m.MaterialName, m.Unit, m.HSNCode,
        d.LocationId AS DetailLocationId,
        dl.LocationName AS DetailLocationName,
        d.Quantity, d.Rate, d.Amount
    FROM dbo.SalesHeader h
    LEFT JOIN dbo.WarehouseLocation hl ON hl.LocationId = h.LocationId AND hl.CompanyId = @CompanyId
    LEFT JOIN dbo.SalesDetail d ON d.SalesId = h.SalesId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
    LEFT JOIN dbo.WarehouseLocation dl ON dl.LocationId = d.LocationId AND dl.CompanyId = @CompanyId
    WHERE h.CompanyId = @CompanyId
    ORDER BY h.SalesDate DESC, h.SalesId DESC, d.SalesDetailId;
END
GO

PRINT N'Sales customer address/GST columns and sp_GetSales updated.';
GO
