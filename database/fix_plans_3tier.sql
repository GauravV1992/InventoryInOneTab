/* 3-tier plans — Basic, Standard, Premium */
USE PawanPutra;
GO

UPDATE dbo.CompanyMaster
SET MaxUsers = CASE LOWER(ISNULL(PlanType, N'trial'))
        WHEN N'premium' THEN 5
        WHEN N'standard' THEN 1
        WHEN N'basic' THEN 1
        ELSE 1
    END,
    MaxWarehouses = CASE LOWER(ISNULL(PlanType, N'trial'))
        WHEN N'premium' THEN 10
        WHEN N'standard' THEN 5
        WHEN N'basic' THEN 3
        ELSE 3
    END,
    MaxMaterials = CASE LOWER(ISNULL(PlanType, N'trial'))
        WHEN N'premium' THEN 3000
        WHEN N'standard' THEN 300
        WHEN N'basic' THEN 100
        ELSE 100
    END
WHERE PlanType IS NOT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegisterAccount
    @Username            NVARCHAR(50),
    @PasswordHash        NVARCHAR(256),
    @FirstName           NVARCHAR(100),
    @LastName            NVARCHAR(100) = NULL,
    @Email               NVARCHAR(150) = NULL,
    @CompanyName         NVARCHAR(150),
    @CompanyGSTNo        NVARCHAR(20) = NULL,
    @CompanyAddress1     NVARCHAR(250) = NULL,
    @CompanyAddress2     NVARCHAR(250) = NULL,
    @CompanyDescription  NVARCHAR(1000) = NULL,
    @CompanyNameColor    NVARCHAR(20) = N'#f97316'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE LOWER(Username) = LOWER(@Username))
    BEGIN
        RAISERROR(N'Username already exists.', 16, 1);
        RETURN;
    END

    IF @CompanyName IS NULL OR LTRIM(RTRIM(@CompanyName)) = N''
    BEGIN
        RAISERROR(N'Company name is required.', 16, 1);
        RETURN;
    END

    DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@FirstName, N'') + N' ' + ISNULL(@LastName, N'')));
    IF @FullName = N'' SET @FullName = @Username;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.CompanyMaster (CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2, CompanyDescription, CompanyNameColor,
                                       PlanType, BillingCycle, SubscriptionStatus, SubscriptionStart, SubscriptionEnd,
                                       MaxUsers, MaxWarehouses, MaxMaterials)
        VALUES (@CompanyName, @CompanyGSTNo, @CompanyAddress1, @CompanyAddress2, @CompanyDescription, ISNULL(@CompanyNameColor, N'#f97316'),
                N'Trial', N'monthly', N'Active', SYSUTCDATETIME(), DATEADD(DAY, 3, SYSUTCDATETIME()),
                1, 3, 100);

        DECLARE @CompanyId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Users (Username, PasswordHash, FullName, FirstName, LastName, Email, CompanyId, Role,
                               CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2, CompanyDescription, CompanyNameColor)
        VALUES (@Username, @PasswordHash, @FullName, @FirstName, @LastName, @Email, @CompanyId, N'Admin',
                @CompanyName, @CompanyGSTNo, @CompanyAddress1, @CompanyAddress2, @CompanyDescription, ISNULL(@CompanyNameColor, N'#f97316'));

        DECLARE @UserId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.WarehouseLocation (CompanyId, LocationName, Address, City)
        VALUES (@CompanyId, N'Main Warehouse', NULL, NULL);

        COMMIT TRANSACTION;

        SELECT @UserId AS UserId, @CompanyId AS CompanyId, @Username AS Username, @FullName AS FullName,
               @CompanyName AS CompanyName, N'Admin' AS Role;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT '3-tier plan limits applied.';
GO
