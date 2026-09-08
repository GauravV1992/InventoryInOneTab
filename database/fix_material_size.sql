/*
  Material Master — optional Size text field.
  Run on PawanPutra database (SSMS).
*/

USE PawanPutra;
GO

SET NOCOUNT ON;

IF COL_LENGTH('dbo.MaterialMaster', 'Size') IS NULL
BEGIN
    ALTER TABLE dbo.MaterialMaster ADD Size NVARCHAR(50) NULL;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetMaterials
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaterialId, MaterialName, Color, Size, HSNCode,
           Rate, ISNULL(SalesRate, 0) AS SalesRate,
           Unit, Remark, IsActive, CreatedAt, UpdatedAt
    FROM dbo.MaterialMaster
    WHERE IsActive = 1 AND CompanyId = @CompanyId
    ORDER BY MaterialName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveMaterial
    @CompanyId    INT,
    @MaterialId   INT = NULL,
    @MaterialName NVARCHAR(150),
    @Color        NVARCHAR(50) = NULL,
    @Size         NVARCHAR(50) = NULL,
    @HSNCode      NVARCHAR(20) = NULL,
    @Rate         DECIMAL(18,2),
    @SalesRate    DECIMAL(18,2) = 0,
    @Unit         NVARCHAR(20),
    @Remark       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @SalesRate = ISNULL(@SalesRate, 0);

    IF @MaterialId IS NULL OR @MaterialId = 0
    BEGIN
        DECLARE @MaxMaterials INT;
        DECLARE @ActiveMaterials INT;
        DECLARE @PlanType NVARCHAR(20);

        SELECT @MaxMaterials = ISNULL(MaxMaterials, 100),
               @PlanType = ISNULL(PlanType, N'Trial')
        FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

        IF LOWER(@PlanType) = N'trial' AND @MaxMaterials IS NULL SET @MaxMaterials = 100;
        IF LOWER(@PlanType) = N'basic' AND @MaxMaterials IS NULL SET @MaxMaterials = 100;
        IF LOWER(@PlanType) = N'standard' AND @MaxMaterials IS NULL SET @MaxMaterials = 300;
        IF LOWER(@PlanType) = N'premium' AND @MaxMaterials IS NULL SET @MaxMaterials = 3000;

        SELECT @ActiveMaterials = COUNT(*)
        FROM dbo.MaterialMaster
        WHERE CompanyId = @CompanyId AND IsActive = 1;

        IF @ActiveMaterials >= @MaxMaterials
        BEGIN
            RAISERROR(N'Material limit reached for your plan. Upgrade on Pricing page.', 16, 1);
            RETURN;
        END

        INSERT INTO dbo.MaterialMaster (CompanyId, MaterialName, Color, Size, HSNCode, Rate, SalesRate, Unit, Remark)
        VALUES (@CompanyId, @MaterialName, @Color, @Size, @HSNCode, @Rate, @SalesRate, @Unit, @Remark);
        SELECT SCOPE_IDENTITY() AS MaterialId;
    END
    ELSE
    BEGIN
        UPDATE dbo.MaterialMaster
        SET MaterialName = @MaterialName,
            Color = @Color,
            Size = @Size,
            HSNCode = @HSNCode,
            Rate = @Rate,
            SalesRate = @SalesRate,
            Unit = @Unit,
            Remark = @Remark,
            UpdatedAt = SYSUTCDATETIME()
        WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId;
        SELECT @MaterialId AS MaterialId;
    END
END
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
        d.PurchaseDetailId, d.MaterialId, m.MaterialName, m.Color, m.Size, m.Unit,
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
        d.SalesDetailId, d.MaterialId, m.MaterialName, m.Color, m.Size, m.Unit, m.HSNCode,
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
        m.Size,
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

PRINT N'Material Size column and related procedures updated.';
GO
