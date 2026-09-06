/* Prorated payment for additional team users — self-contained (includes plan limit columns) */
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
        ELSE ISNULL(MaxUsers, 1)
    END,
    MaxWarehouses = CASE
        WHEN LOWER(ISNULL(PlanType, N'trial')) = N'premium' THEN 999999
        ELSE ISNULL(MaxWarehouses, 3)
    END,
    MaxMaterials = CASE
        WHEN LOWER(ISNULL(PlanType, N'trial')) = N'premium' THEN 999999
        ELSE ISNULL(MaxMaterials, 1000)
    END
WHERE PlanType IS NOT NULL;
GO

IF COL_LENGTH('dbo.Users', 'SubscriptionEnd') IS NULL
    ALTER TABLE dbo.Users ADD SubscriptionEnd DATETIME2 NULL;
IF COL_LENGTH('dbo.Users', 'PaymentStatus') IS NULL
    ALTER TABLE dbo.Users ADD PaymentStatus NVARCHAR(20) NULL;
GO

UPDATE u
SET u.PaymentStatus = ISNULL(u.PaymentStatus, N'Paid'),
    u.SubscriptionEnd = ISNULL(u.SubscriptionEnd, c.SubscriptionEnd)
FROM dbo.Users u
INNER JOIN dbo.CompanyMaster c ON c.CompanyId = u.CompanyId
WHERE u.PaymentStatus IS NULL OR u.SubscriptionEnd IS NULL;
GO

IF COL_LENGTH('dbo.PaymentHistory', 'UserId') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD UserId INT NULL;
IF COL_LENGTH('dbo.PaymentHistory', 'PaymentType') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD PaymentType NVARCHAR(20) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.PasswordHash, u.FullName, u.IsActive, u.CompanyId, u.Role,
           u.PaymentStatus, u.SubscriptionEnd,
           c.CompanyName, c.PlanType, c.BillingCycle, c.SubscriptionStatus, c.SubscriptionEnd AS CompanySubscriptionEnd, c.MaxUsers
    FROM dbo.Users u
    INNER JOIN dbo.CompanyMaster c ON c.CompanyId = u.CompanyId
    WHERE u.Username = @Username;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanySubscription
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CompanyId, CompanyName, PlanType, BillingCycle, SubscriptionStatus,
           SubscriptionStart, SubscriptionEnd, MaxUsers, MaxWarehouses, MaxMaterials,
           RazorpayOrderId, RazorpayPaymentId,
           (SELECT COUNT(*) FROM dbo.Users
            WHERE CompanyId = @CompanyId AND IsActive = 1 AND ISNULL(PaymentStatus, N'Paid') = N'Paid') AS ActiveUsers,
           (SELECT COUNT(*) FROM dbo.WarehouseLocation WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveWarehouses,
           (SELECT COUNT(*) FROM dbo.MaterialMaster WHERE CompanyId = @CompanyId AND IsActive = 1) AS ActiveMaterials
    FROM dbo.CompanyMaster
    WHERE CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanyUsers
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, FullName, FirstName, LastName, Email, Role, IsActive,
           PaymentStatus, SubscriptionEnd, CreatedAt
    FROM dbo.Users
    WHERE CompanyId = @CompanyId
    ORDER BY Role DESC, FullName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddCompanyUser
    @CompanyId         INT,
    @RequestedBy       INT,
    @Username          NVARCHAR(50),
    @PasswordHash      NVARCHAR(256),
    @FirstName         NVARCHAR(100),
    @LastName          NVARCHAR(100) = NULL,
    @Email             NVARCHAR(150) = NULL,
    @IsActive          BIT = 1,
    @PaymentStatus     NVARCHAR(20) = N'Paid',
    @SubscriptionEnd   DATETIME2 = NULL,
    @AllowOverLimit    BIT = 0
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

    IF @AllowOverLimit = 0
    BEGIN
        DECLARE @MaxUsers INT;
        DECLARE @ActiveUsers INT;
        SELECT @MaxUsers = ISNULL(MaxUsers, 1) FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;
        SELECT @ActiveUsers = COUNT(*) FROM dbo.Users
        WHERE CompanyId = @CompanyId AND IsActive = 1 AND ISNULL(PaymentStatus, N'Paid') = N'Paid';

        IF @ActiveUsers >= @MaxUsers
        BEGIN
            RAISERROR(N'User limit reached. Payment required to add more users.', 16, 1);
            RETURN;
        END
    END

    DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@FirstName, N'') + N' ' + ISNULL(@LastName, N'')));
    IF @FullName = N'' SET @FullName = @Username;

    DECLARE @CompanyName NVARCHAR(150);
    DECLARE @CompanyEnd DATETIME2;
    SELECT @CompanyName = CompanyName, @CompanyEnd = SubscriptionEnd
    FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

    IF @SubscriptionEnd IS NULL SET @SubscriptionEnd = @CompanyEnd;

    INSERT INTO dbo.Users (Username, PasswordHash, FullName, FirstName, LastName, Email, CompanyId, Role,
                           CompanyName, IsActive, PaymentStatus, SubscriptionEnd)
    VALUES (@Username, @PasswordHash, @FullName, @FirstName, @LastName, @Email, @CompanyId, N'User',
            @CompanyName, @IsActive, @PaymentStatus, @SubscriptionEnd);

    SELECT UserId, Username, FullName, FirstName, LastName, Email, Role, IsActive,
           PaymentStatus, SubscriptionEnd, CreatedAt
    FROM dbo.Users WHERE UserId = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_ActivateCompanyUser
    @CompanyId         INT,
    @RequestedBy       INT,
    @UserId            INT,
    @RazorpayOrderId   NVARCHAR(100) = NULL,
    @RazorpayPaymentId NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @RequestedBy AND CompanyId = @CompanyId AND Role = N'Admin' AND IsActive = 1)
    BEGIN
        RAISERROR(N'Only company admin can activate users.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId AND CompanyId = @CompanyId AND PaymentStatus = N'Pending')
    BEGIN
        RAISERROR(N'Pending user not found.', 16, 1);
        RETURN;
    END

    DECLARE @CompanyEnd DATETIME2;
    SELECT @CompanyEnd = SubscriptionEnd FROM dbo.CompanyMaster WHERE CompanyId = @CompanyId;

    UPDATE dbo.Users
    SET IsActive = 1,
        PaymentStatus = N'Paid',
        SubscriptionEnd = ISNULL(@CompanyEnd, SubscriptionEnd)
    WHERE UserId = @UserId AND CompanyId = @CompanyId;

    UPDATE dbo.CompanyMaster
    SET MaxUsers = ISNULL(MaxUsers, 1) + 1
    WHERE CompanyId = @CompanyId;

    SELECT UserId, Username, FullName, FirstName, LastName, Email, Role, IsActive,
           PaymentStatus, SubscriptionEnd, CreatedAt
    FROM dbo.Users WHERE UserId = @UserId;
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
    INSERT INTO dbo.PaymentHistory (CompanyId, PlanType, BillingCycle, AmountPaise, RazorpayOrderId, RazorpayPaymentId, PaymentStatus, UserId, PaymentType)
    VALUES (@CompanyId, @PlanType, @BillingCycle, @AmountPaise, @RazorpayOrderId, @RazorpayPaymentId, @PaymentStatus, @UserId, @PaymentType);
    SELECT SCOPE_IDENTITY() AS PaymentHistoryId;
END
GO

PRINT 'User prorated payment setup completed.';
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

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId AND CompanyId = @CompanyId AND (IsActive = 1 OR PaymentStatus = N'Pending'))
    BEGIN
        RAISERROR(N'User not found in your company.', 16, 1);
        RETURN;
    END

    UPDATE dbo.Users SET IsActive = 0, PaymentStatus = N'Cancelled' WHERE UserId = @UserId AND CompanyId = @CompanyId;
    SELECT @UserId AS UserId;
END
GO
