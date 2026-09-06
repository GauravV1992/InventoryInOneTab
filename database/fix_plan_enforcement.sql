/* Enforce plan limits when saving warehouse, material and user */
USE PawanPutra;
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveLocation
    @CompanyId    INT,
    @LocationId   INT = NULL,
    @LocationName NVARCHAR(100),
    @Address      NVARCHAR(250) = NULL,
    @City         NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @LocationId IS NULL OR @LocationId = 0
    BEGIN
        DECLARE @MaxWarehouses INT;
        DECLARE @ActiveWarehouses INT;
        DECLARE @PlanType NVARCHAR(20);

        SELECT @MaxWarehouses = ISNULL(MaxWarehouses, 3),
               @PlanType = ISNULL(PlanType, N'Trial')
        FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

        IF LOWER(@PlanType) = N'trial' AND @MaxWarehouses IS NULL SET @MaxWarehouses = 3;
        IF LOWER(@PlanType) = N'basic' AND @MaxWarehouses IS NULL SET @MaxWarehouses = 3;
        IF LOWER(@PlanType) = N'standard' AND @MaxWarehouses IS NULL SET @MaxWarehouses = 5;
        IF LOWER(@PlanType) = N'premium' AND @MaxWarehouses IS NULL SET @MaxWarehouses = 10;

        SELECT @ActiveWarehouses = COUNT(*)
        FROM dbo.WarehouseLocation
        WHERE CompanyId = @CompanyId AND IsActive = 1;

        IF @ActiveWarehouses >= @MaxWarehouses
        BEGIN
            RAISERROR(N'Warehouse limit reached for your plan. Upgrade on Pricing page.', 16, 1);
            RETURN;
        END

        INSERT INTO dbo.WarehouseLocation (CompanyId, LocationName, Address, City)
        VALUES (@CompanyId, @LocationName, @Address, @City);
        SELECT SCOPE_IDENTITY() AS LocationId;
    END
    ELSE
    BEGIN
        UPDATE dbo.WarehouseLocation
        SET LocationName = @LocationName, Address = @Address, City = @City
        WHERE LocationId = @LocationId AND CompanyId = @CompanyId;
        SELECT @LocationId AS LocationId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveMaterial
    @CompanyId    INT,
    @MaterialId   INT = NULL,
    @MaterialName NVARCHAR(150),
    @Color        NVARCHAR(50) = NULL,
    @HSNCode      NVARCHAR(20) = NULL,
    @Rate         DECIMAL(18,2),
    @Unit         NVARCHAR(20),
    @Remark       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

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

        INSERT INTO dbo.MaterialMaster (CompanyId, MaterialName, Color, HSNCode, Rate, Unit, Remark)
        VALUES (@CompanyId, @MaterialName, @Color, @HSNCode, @Rate, @Unit, @Remark);
        SELECT SCOPE_IDENTITY() AS MaterialId;
    END
    ELSE
    BEGIN
        UPDATE dbo.MaterialMaster
        SET MaterialName = @MaterialName, Color = @Color, HSNCode = @HSNCode,
            Rate = @Rate, Unit = @Unit, Remark = @Remark, UpdatedAt = SYSUTCDATETIME()
        WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId;
        SELECT @MaterialId AS MaterialId;
    END
END
GO

PRINT 'Plan limit enforcement on save procedures applied.';
GO

UPDATE dbo.CompanyMaster
SET MaxMaterials = 3000
WHERE LOWER(ISNULL(PlanType, N'')) = N'premium';
GO

PRINT 'Premium plan MaxMaterials set to 3000.';
GO

UPDATE dbo.CompanyMaster
SET MaxMaterials = 300
WHERE LOWER(ISNULL(PlanType, N'')) = N'standard';
GO

PRINT 'Standard plan MaxMaterials set to 300.';
GO
