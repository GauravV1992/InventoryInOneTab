/* Run on existing PawanPutra database — My Account / company profile */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.Users', 'FirstName') IS NULL
    ALTER TABLE dbo.Users ADD FirstName NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.Users', 'LastName') IS NULL
    ALTER TABLE dbo.Users ADD LastName NVARCHAR(100) NULL;
IF COL_LENGTH('dbo.Users', 'Email') IS NULL
    ALTER TABLE dbo.Users ADD Email NVARCHAR(150) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyName') IS NULL
    ALTER TABLE dbo.Users ADD CompanyName NVARCHAR(150) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyGSTNo') IS NULL
    ALTER TABLE dbo.Users ADD CompanyGSTNo NVARCHAR(20) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyAddress1') IS NULL
    ALTER TABLE dbo.Users ADD CompanyAddress1 NVARCHAR(250) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyAddress2') IS NULL
    ALTER TABLE dbo.Users ADD CompanyAddress2 NVARCHAR(250) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyLogo') IS NULL
    ALTER TABLE dbo.Users ADD CompanyLogo NVARCHAR(MAX) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyDescription') IS NULL
    ALTER TABLE dbo.Users ADD CompanyDescription NVARCHAR(1000) NULL;
IF COL_LENGTH('dbo.Users', 'CompanyNameColor') IS NULL
    ALTER TABLE dbo.Users ADD CompanyNameColor NVARCHAR(20) NULL;
GO

UPDATE dbo.Users
SET CompanyName = ISNULL(CompanyName, N'InventoryInOneTap'),
    CompanyAddress1 = ISNULL(CompanyAddress1, N'Ahmedabad, Gujarat, India'),
    CompanyDescription = ISNULL(CompanyDescription, N'Inventory in One Tap'),
    CompanyNameColor = ISNULL(CompanyNameColor, N'#f97316'),
    FirstName = ISNULL(FirstName, CASE WHEN FullName LIKE N'% %' THEN LEFT(FullName, CHARINDEX(N' ', FullName) - 1) ELSE FullName END),
    LastName = ISNULL(LastName, CASE WHEN FullName LIKE N'% %' THEN LTRIM(SUBSTRING(FullName, CHARINDEX(N' ', FullName) + 1, 100)) ELSE N'' END)
WHERE IsActive = 1;
GO

UPDATE dbo.Users
SET CompanyName = N'InventoryInOneTap',
    CompanyDescription = CASE WHEN CompanyDescription = N'Retailer Inventory' THEN N'Inventory in One Tap' ELSE CompanyDescription END
WHERE CompanyName = N'PawanPutra';
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserProfile
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, FullName, FirstName, LastName, Email,
           CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2,
           CompanyLogo, CompanyDescription, CompanyNameColor
    FROM dbo.Users
    WHERE UserId = @UserId AND IsActive = 1;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveUserProfile
    @UserId              INT,
    @FirstName           NVARCHAR(100) = NULL,
    @LastName            NVARCHAR(100) = NULL,
    @Email               NVARCHAR(150) = NULL,
    @CompanyName         NVARCHAR(150) = NULL,
    @CompanyGSTNo        NVARCHAR(20) = NULL,
    @CompanyAddress1     NVARCHAR(250) = NULL,
    @CompanyAddress2     NVARCHAR(250) = NULL,
    @CompanyLogo         NVARCHAR(MAX) = NULL,
    @CompanyDescription  NVARCHAR(1000) = NULL,
    @CompanyNameColor    NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId AND IsActive = 1)
    BEGIN
        RAISERROR(N'User not found.', 16, 1);
        RETURN;
    END

    DECLARE @FullName NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@FirstName, N'') + N' ' + ISNULL(@LastName, N'')));
    IF @FullName = N'' SET @FullName = NULL;

    UPDATE dbo.Users
    SET FirstName = @FirstName,
        LastName = @LastName,
        FullName = ISNULL(@FullName, FullName),
        Email = @Email,
        CompanyName = @CompanyName,
        CompanyGSTNo = @CompanyGSTNo,
        CompanyAddress1 = @CompanyAddress1,
        CompanyAddress2 = @CompanyAddress2,
        CompanyLogo = @CompanyLogo,
        CompanyDescription = @CompanyDescription,
        CompanyNameColor = @CompanyNameColor
    WHERE UserId = @UserId;

    EXEC dbo.sp_GetUserProfile @UserId = @UserId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateUserPassword
    @UserId INT,
    @PasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.Users SET PasswordHash = @PasswordHash WHERE UserId = @UserId AND IsActive = 1;
END
GO

PRINT 'User account profile setup completed.';
GO
