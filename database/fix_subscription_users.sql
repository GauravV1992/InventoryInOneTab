/* Run on existing PawanPutra database — Roles, subscription plans, company users */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.Users', 'Role') IS NULL
    ALTER TABLE dbo.Users ADD Role NVARCHAR(20) NOT NULL CONSTRAINT DF_Users_Role DEFAULT N'User';
GO

IF COL_LENGTH('dbo.CompanyMaster', 'PlanType') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD PlanType NVARCHAR(20) NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'BillingCycle') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD BillingCycle NVARCHAR(10) NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'SubscriptionStatus') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD SubscriptionStatus NVARCHAR(20) NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'SubscriptionStart') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD SubscriptionStart DATETIME2 NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'SubscriptionEnd') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD SubscriptionEnd DATETIME2 NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'MaxUsers') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD MaxUsers INT NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'RazorpayOrderId') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD RazorpayOrderId NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'RazorpayPaymentId') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD RazorpayPaymentId NVARCHAR(100) NULL;
GO

IF OBJECT_ID('dbo.PaymentHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PaymentHistory (
        PaymentHistoryId INT IDENTITY(1,1) PRIMARY KEY,
        CompanyId          INT NOT NULL,
        PlanType           NVARCHAR(20) NOT NULL,
        BillingCycle       NVARCHAR(10) NOT NULL,
        AmountPaise        INT NOT NULL,
        RazorpayOrderId    NVARCHAR(100) NULL,
        RazorpayPaymentId  NVARCHAR(100) NULL,
        PaymentStatus      NVARCHAR(20) NOT NULL DEFAULT N'Created',
        CreatedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_PaymentHistory_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId)
    );
END
GO

UPDATE dbo.Users SET Role = N'Admin'
WHERE Role IS NULL OR Role = N'' OR Role = N'User'
  AND UserId IN (SELECT MIN(UserId) FROM dbo.Users GROUP BY CompanyId);

UPDATE dbo.Users SET Role = N'Admin' WHERE Username = N'admin';

UPDATE dbo.CompanyMaster
SET PlanType = ISNULL(PlanType, N'Trial'),
    BillingCycle = ISNULL(BillingCycle, N'monthly'),
    SubscriptionStatus = ISNULL(SubscriptionStatus, N'Active'),
    SubscriptionStart = ISNULL(SubscriptionStart, SYSUTCDATETIME()),
    SubscriptionEnd = ISNULL(SubscriptionEnd, DATEADD(DAY, 3, SYSUTCDATETIME())),
    MaxUsers = ISNULL(MaxUsers, 1)
WHERE PlanType IS NULL OR SubscriptionStatus IS NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.PasswordHash, u.FullName, u.IsActive, u.CompanyId, u.Role,
           c.CompanyName, c.PlanType, c.BillingCycle, c.SubscriptionStatus, c.SubscriptionEnd, c.MaxUsers
    FROM dbo.Users u
    INNER JOIN dbo.CompanyMaster c ON c.CompanyId = u.CompanyId
    WHERE u.Username = @Username AND u.IsActive = 1;
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
                                       PlanType, BillingCycle, SubscriptionStatus, SubscriptionStart, SubscriptionEnd, MaxUsers)
        VALUES (@CompanyName, @CompanyGSTNo, @CompanyAddress1, @CompanyAddress2, @CompanyDescription, ISNULL(@CompanyNameColor, N'#f97316'),
                N'Trial', N'monthly', N'Active', SYSUTCDATETIME(), DATEADD(DAY, 3, SYSUTCDATETIME()), 3);

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

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanySubscription
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CompanyId, CompanyName, PlanType, BillingCycle, SubscriptionStatus,
           SubscriptionStart, SubscriptionEnd, MaxUsers, RazorpayOrderId, RazorpayPaymentId,
           (SELECT COUNT(*) FROM dbo.Users WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveUsers
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
        RazorpayOrderId = @RazorpayOrderId,
        RazorpayPaymentId = @RazorpayPaymentId
    WHERE CompanyId = @CompanyId;

    EXEC dbo.sp_GetCompanySubscription @CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePaymentHistory
    @CompanyId         INT,
    @PlanType          NVARCHAR(20),
    @BillingCycle      NVARCHAR(10),
    @AmountPaise       INT,
    @RazorpayOrderId   NVARCHAR(100) = NULL,
    @RazorpayPaymentId NVARCHAR(100) = NULL,
    @PaymentStatus     NVARCHAR(20),
    @UserId            INT = NULL,
    @PaymentType       NVARCHAR(20) = N'Subscription'
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.PaymentHistory (
        CompanyId, PlanType, BillingCycle, AmountPaise,
        RazorpayOrderId, RazorpayPaymentId, PaymentStatus, UserId, PaymentType
    )
    VALUES (
        @CompanyId, @PlanType, @BillingCycle, @AmountPaise,
        @RazorpayOrderId, @RazorpayPaymentId, @PaymentStatus, @UserId, @PaymentType
    );
    SELECT SCOPE_IDENTITY() AS PaymentHistoryId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanyUsers
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, FullName, FirstName, LastName, Email, Role, IsActive, CreatedAt
    FROM dbo.Users
    WHERE CompanyId = @CompanyId
    ORDER BY Role DESC, FullName;
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
    SELECT @MaxUsers = ISNULL(MaxUsers, 1) FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;
    SELECT @ActiveUsers = COUNT(*) FROM dbo.Users WHERE CompanyId = @CompanyId AND IsActive = 1;

    IF @ActiveUsers >= @MaxUsers
    BEGIN
        RAISERROR(N'User limit reached for your plan. Upgrade subscription to add more users.', 16, 1);
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

CREATE OR ALTER PROCEDURE dbo.sp_DeactivateCompanyUser
    @CompanyId   INT,
    @RequestedBy INT,
    @UserId      INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @RequestedBy AND CompanyId = @CompanyId AND Role = N'Admin' AND IsActive = 1)
    BEGIN
        RAISERROR(N'Only company admin can remove users.', 16, 1);
        RETURN;
    END

    IF @UserId = @RequestedBy
    BEGIN
        RAISERROR(N'You cannot deactivate your own account.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        RAISERROR(N'User not found in your company.', 16, 1);
        RETURN;
    END

    UPDATE dbo.Users SET IsActive = 0 WHERE UserId = @UserId AND CompanyId = @CompanyId;
    SELECT @UserId AS UserId;
END
GO

PRINT 'Subscription and company users setup completed.';
GO

/* Set trial period to 3 days for active trial companies */
UPDATE dbo.CompanyMaster
SET SubscriptionEnd = DATEADD(DAY, 3, ISNULL(SubscriptionStart, SYSUTCDATETIME()))
WHERE PlanType = N'Trial' AND SubscriptionStatus = N'Active';
GO
