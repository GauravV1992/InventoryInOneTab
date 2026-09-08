/*
  Material Master — add SalesRate; existing Rate remains Purchase Rate.
  Run on PawanPutra database (SSMS).
*/

SET NOCOUNT ON;

IF COL_LENGTH('dbo.MaterialMaster', 'SalesRate') IS NULL
BEGIN
    ALTER TABLE dbo.MaterialMaster ADD SalesRate DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_MaterialMaster_SalesRate DEFAULT (0);
END
GO

IF COL_LENGTH('dbo.MaterialMaster', 'Size') IS NULL
BEGIN
    ALTER TABLE dbo.MaterialMaster ADD Size NVARCHAR(50) NULL;
END
GO

-- Seed sales rate from purchase rate where sales rate is still 0
UPDATE dbo.MaterialMaster
SET SalesRate = Rate
WHERE ISNULL(SalesRate, 0) = 0 AND ISNULL(Rate, 0) <> 0;
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

PRINT 'Material SalesRate column and procedures updated.';
