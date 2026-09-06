/* Plan limits — Standard & Premium only */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.CompanyMaster', 'MaxWarehouses') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD MaxWarehouses INT NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'MaxMaterials') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD MaxMaterials INT NULL;
GO

UPDATE dbo.CompanyMaster
SET MaxUsers = CASE
        WHEN LOWER(ISNULL(PlanType, N'trial')) = N'premium' THEN 3
        ELSE 1
    END,
    MaxWarehouses = CASE
        WHEN LOWER(ISNULL(PlanType, N'trial')) = N'premium' THEN 999999
        ELSE 3
    END,
    MaxMaterials = CASE
        WHEN LOWER(ISNULL(PlanType, N'trial')) = N'premium' THEN 999999
        ELSE 1000
    END
WHERE PlanType IS NOT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanySubscription
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CompanyId, CompanyName, PlanType, BillingCycle, SubscriptionStatus,
           SubscriptionStart, SubscriptionEnd, MaxUsers, MaxWarehouses, MaxMaterials,
           RazorpayOrderId, RazorpayPaymentId,
           (SELECT COUNT(*) FROM dbo.Users WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveUsers,
           (SELECT COUNT(*) FROM dbo.WarehouseLocation WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveWarehouses,
           (SELECT COUNT(*) FROM dbo.MaterialMaster WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveMaterials
    FROM dbo.CompanyMaster
    WHERE CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateCompanySubscription
    @CompanyId           INT,
    @PlanType            NVARCHAR(20),
    @BillingCycle        NVARCHAR(10),
    @SubscriptionStatus  NVARCHAR(20),
    @SubscriptionStart   DATETIME2,
    @SubscriptionEnd     DATETIME2,
    @MaxUsers            INT,
    @MaxWarehouses       INT = NULL,
    @MaxMaterials        INT = NULL,
    @RazorpayOrderId     NVARCHAR(100) = NULL,
    @RazorpayPaymentId   NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.CompanyMaster
    SET PlanType = @PlanType,
        BillingCycle = @BillingCycle,
        SubscriptionStatus = @SubscriptionStatus,
        SubscriptionStart = @SubscriptionStart,
        SubscriptionEnd = @SubscriptionEnd,
        MaxUsers = @MaxUsers,
        MaxWarehouses = @MaxWarehouses,
        MaxMaterials = @MaxMaterials,
        RazorpayOrderId = @RazorpayOrderId,
        RazorpayPaymentId = @RazorpayPaymentId
    WHERE CompanyId = @CompanyId;

    EXEC dbo.sp_GetCompanySubscription @CompanyId = @CompanyId;
END
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

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username)
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
                1, 3, 1000);

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

CREATE OR ALTER PROCEDURE dbo.sp_AddCompanyUser
    @CompanyId      INT,
    @RequestedBy    INT,
    @Username       NVARCHAR(50),
    @PasswordHash   NVARCHAR(256),
    @FirstName      NVARCHAR(100),
    @LastName       NVARCHAR(100) = NULL,
    @Email          NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @RequestedBy AND CompanyId = @CompanyId AND Role = N'Admin' AND IsActive = 1)
    BEGIN
        RAISERROR(N'Only company admin can add users.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username)
    BEGIN
        RAISERROR(N'Username already exists.', 16, 1);
        RETURN;
    END

    DECLARE @MaxUsers INT;
    DECLARE @ActiveUsers INT;
    DECLARE @PlanType NVARCHAR(20);
    SELECT @MaxUsers = ISNULL(MaxUsers, 1), @PlanType = ISNULL(PlanType, N'Trial')
    FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

    SELECT @ActiveUsers = COUNT(*) FROM dbo.Users WHERE CompanyId = @CompanyId AND IsActive = 1;

    IF @ActiveUsers >= @MaxUsers
    BEGIN
        RAISERROR(N'User limit reached for your plan. Upgrade to Premium to add more users.', 16, 1);
        RETURN;
    END

    DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@FirstName, N'') + N' ' + ISNULL(@LastName, N'')));
    IF @FullName = N'' SET @FullName = @Username;

    DECLARE @CompanyName NVARCHAR(150);
    SELECT @CompanyName = CompanyName FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

    INSERT INTO dbo.Users (Username, PasswordHash, FullName, FirstName, LastName, Email, CompanyId, Role, CompanyName)
    VALUES (@Username, @PasswordHash, @FullName, @FirstName, @LastName, @Email, @CompanyId, N'User', @CompanyName);

    SELECT UserId, Username, FullName, FirstName, LastName, Email, Role, IsActive, CreatedAt
    FROM dbo.Users WHERE UserId = SCOPE_IDENTITY();
END
GO

PRINT 'Plan limits (Standard & Premium) applied.';
GO
