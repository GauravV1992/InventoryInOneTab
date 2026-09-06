/* Run on existing PawanPutra database — Multi-company / Create Account support */
USE PawanPutra;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaNow()
RETURNS DATETIME2
AS
BEGIN
    RETURN DATEADD(MINUTE, 330, SYSUTCDATETIME());
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaDate()
RETURNS DATE
AS
BEGIN
    RETURN CAST(DATEADD(MINUTE, 330, SYSUTCDATETIME()) AS DATE);
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetFinancialYearCode(@Date DATE)
RETURNS NVARCHAR(4)
AS
BEGIN
    IF @Date IS NULL SET @Date = dbo.fn_GetIndiaDate();

    DECLARE @Year INT = YEAR(@Date);
    DECLARE @StartYear INT = CASE WHEN MONTH(@Date) >= 4 THEN @Year ELSE @Year - 1 END;
    DECLARE @EndYear INT = @StartYear + 1;

    RETURN RIGHT(N'00' + CAST(@StartYear % 100 AS NVARCHAR(2)), 2)
         + RIGHT(N'00' + CAST(@EndYear % 100 AS NVARCHAR(2)), 2);
END
GO

IF OBJECT_ID('dbo.CompanyMaster', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CompanyMaster (
        CompanyId            INT IDENTITY(1,1) PRIMARY KEY,
        CompanyName          NVARCHAR(150) NOT NULL,
        CompanyGSTNo         NVARCHAR(20)  NULL,
        CompanyAddress1      NVARCHAR(250) NULL,
        CompanyAddress2      NVARCHAR(250) NULL,
        CompanyLogo          NVARCHAR(MAX) NULL,
        CompanyDescription   NVARCHAR(1000) NULL,
        CompanyNameColor     NVARCHAR(20)  NULL DEFAULT N'#f97316',
        IsActive             BIT NOT NULL DEFAULT 1,
        CreatedAt            DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

IF COL_LENGTH('dbo.Users', 'CompanyId') IS NULL ALTER TABLE dbo.Users ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.WarehouseLocation', 'CompanyId') IS NULL ALTER TABLE dbo.WarehouseLocation ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.MaterialMaster', 'CompanyId') IS NULL ALTER TABLE dbo.MaterialMaster ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.SupplierMaster', 'CompanyId') IS NULL ALTER TABLE dbo.SupplierMaster ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.OpeningStock', 'CompanyId') IS NULL ALTER TABLE dbo.OpeningStock ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.PurchaseInwardHeader', 'CompanyId') IS NULL ALTER TABLE dbo.PurchaseInwardHeader ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.SalesHeader', 'CompanyId') IS NULL ALTER TABLE dbo.SalesHeader ADD CompanyId INT NULL;
IF COL_LENGTH('dbo.StockLedger', 'CompanyId') IS NULL ALTER TABLE dbo.StockLedger ADD CompanyId INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.CompanyMaster)
BEGIN
    INSERT INTO dbo.CompanyMaster (CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2, CompanyLogo, CompanyDescription, CompanyNameColor)
    SELECT TOP 1
        ISNULL(u.CompanyName, N'InventoryInOneTap'),
        u.CompanyGSTNo,
        ISNULL(u.CompanyAddress1, N'Ahmedabad, Gujarat, India'),
        u.CompanyAddress2,
        u.CompanyLogo,
        ISNULL(u.CompanyDescription, N'Inventory in One Tap'),
        ISNULL(u.CompanyNameColor, N'#f97316')
    FROM dbo.Users u
    WHERE u.Username = N'admin'
    ORDER BY u.UserId;

    IF @@ROWCOUNT = 0
        INSERT INTO dbo.CompanyMaster (CompanyName, CompanyAddress1, CompanyDescription, CompanyNameColor)
        VALUES (N'InventoryInOneTap', N'Ahmedabad, Gujarat, India', N'Inventory in One Tap', N'#f97316');
END
GO

DECLARE @DefaultCompanyId INT = (SELECT MIN(CompanyId) FROM dbo.CompanyMaster);

UPDATE dbo.Users SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.WarehouseLocation SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.MaterialMaster SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.SupplierMaster SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.OpeningStock SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.PurchaseInwardHeader SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.SalesHeader SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
UPDATE dbo.StockLedger SET CompanyId = @DefaultCompanyId WHERE CompanyId IS NULL;
GO

ALTER TABLE dbo.Users ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.WarehouseLocation ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.MaterialMaster ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.SupplierMaster ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.OpeningStock ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.PurchaseInwardHeader ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.SalesHeader ALTER COLUMN CompanyId INT NOT NULL;
ALTER TABLE dbo.StockLedger ALTER COLUMN CompanyId INT NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Users_Company')
    ALTER TABLE dbo.Users ADD CONSTRAINT FK_Users_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_WarehouseLocation_Company')
    ALTER TABLE dbo.WarehouseLocation ADD CONSTRAINT FK_WarehouseLocation_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_MaterialMaster_Company')
    ALTER TABLE dbo.MaterialMaster ADD CONSTRAINT FK_MaterialMaster_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SupplierMaster_Company')
    ALTER TABLE dbo.SupplierMaster ADD CONSTRAINT FK_SupplierMaster_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OpeningStock_Company')
    ALTER TABLE dbo.OpeningStock ADD CONSTRAINT FK_OpeningStock_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInwardHeader_Company')
    ALTER TABLE dbo.PurchaseInwardHeader ADD CONSTRAINT FK_PurchaseInwardHeader_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SalesHeader_Company')
    ALTER TABLE dbo.SalesHeader ADD CONSTRAINT FK_SalesHeader_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StockLedger_Company')
    ALTER TABLE dbo.StockLedger ADD CONSTRAINT FK_StockLedger_Company FOREIGN KEY (CompanyId) REFERENCES dbo.CompanyMaster(CompanyId);
GO

DECLARE @sql NVARCHAR(MAX);
SELECT @sql = N'ALTER TABLE dbo.PurchaseInwardHeader DROP CONSTRAINT ' + QUOTENAME(k.name)
FROM sys.key_constraints k
INNER JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE k.parent_object_id = OBJECT_ID('dbo.PurchaseInwardHeader') AND k.type = 'UQ' AND c.name = N'PurchaseNo';
IF @sql IS NOT NULL EXEC sp_executesql @sql;

SELECT @sql = N'ALTER TABLE dbo.SalesHeader DROP CONSTRAINT ' + QUOTENAME(k.name)
FROM sys.key_constraints k
INNER JOIN sys.index_columns ic ON ic.object_id = k.parent_object_id AND ic.index_id = k.unique_index_id
INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE k.parent_object_id = OBJECT_ID('dbo.SalesHeader') AND k.type = 'UQ' AND c.name = N'SalesNo';
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('dbo.OpeningStock') AND name = N'UQ_OpeningStock_MaterialLocation')
    ALTER TABLE dbo.OpeningStock DROP CONSTRAINT UQ_OpeningStock_MaterialLocation;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_PurchaseInwardHeader_CompanyNo' AND object_id = OBJECT_ID('dbo.PurchaseInwardHeader'))
    CREATE UNIQUE INDEX UQ_PurchaseInwardHeader_CompanyNo ON dbo.PurchaseInwardHeader(CompanyId, PurchaseNo);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_SalesHeader_CompanyNo' AND object_id = OBJECT_ID('dbo.SalesHeader'))
    CREATE UNIQUE INDEX UQ_SalesHeader_CompanyNo ON dbo.SalesHeader(CompanyId, SalesNo);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_OpeningStock_CompanyMaterialLocation' AND object_id = OBJECT_ID('dbo.OpeningStock'))
    CREATE UNIQUE INDEX UQ_OpeningStock_CompanyMaterialLocation ON dbo.OpeningStock(CompanyId, MaterialId, LocationId);
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

CREATE OR ALTER VIEW dbo.vw_StockReport
AS
SELECT
    sl.CompanyId,
    sl.LedgerId,
    sl.TransactionDate,
    sl.TransactionType,
    sl.ReferenceNo,
    m.MaterialId,
    m.MaterialName,
    m.Color,
    m.HSNCode,
    m.Unit,
    l.LocationId,
    l.LocationName,
    sl.QuantityIn,
    sl.QuantityOut,
    (sl.QuantityIn - sl.QuantityOut) AS NetQty
FROM dbo.StockLedger sl
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = sl.MaterialId AND m.CompanyId = sl.CompanyId
INNER JOIN dbo.WarehouseLocation l ON l.LocationId = sl.LocationId AND l.CompanyId = sl.CompanyId;
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

CREATE OR ALTER PROCEDURE dbo.sp_GetUserByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.PasswordHash, u.FullName, u.IsActive, u.CompanyId,
           c.CompanyName
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

        INSERT INTO dbo.CompanyMaster (CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2, CompanyDescription, CompanyNameColor)
        VALUES (@CompanyName, @CompanyGSTNo, @CompanyAddress1, @CompanyAddress2, @CompanyDescription, ISNULL(@CompanyNameColor, N'#f97316'));

        DECLARE @CompanyId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Users (Username, PasswordHash, FullName, FirstName, LastName, Email, CompanyId,
                               CompanyName, CompanyGSTNo, CompanyAddress1, CompanyAddress2, CompanyDescription, CompanyNameColor)
        VALUES (@Username, @PasswordHash, @FullName, @FirstName, @LastName, @Email, @CompanyId,
                @CompanyName, @CompanyGSTNo, @CompanyAddress1, @CompanyAddress2, @CompanyDescription, ISNULL(@CompanyNameColor, N'#f97316'));

        DECLARE @UserId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.WarehouseLocation (CompanyId, LocationName, Address, City)
        VALUES (@CompanyId, N'Main Warehouse', NULL, NULL);

        COMMIT TRANSACTION;

        SELECT @UserId AS UserId, @CompanyId AS CompanyId, @Username AS Username, @FullName AS FullName, @CompanyName AS CompanyName;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserProfile
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Username, u.FullName, u.FirstName, u.LastName, u.Email, u.CompanyId,
           c.CompanyName, c.CompanyGSTNo, c.CompanyAddress1, c.CompanyAddress2,
           c.CompanyLogo, c.CompanyDescription, c.CompanyNameColor
    FROM dbo.Users u
    INNER JOIN dbo.CompanyMaster c ON c.CompanyId = u.CompanyId
    WHERE u.UserId = @UserId AND u.IsActive = 1;
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

    DECLARE @CompanyId INT;
    SELECT @CompanyId = CompanyId FROM dbo.Users WHERE UserId = @UserId AND IsActive = 1;
    IF @CompanyId IS NULL
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

    UPDATE dbo.CompanyMaster
    SET CompanyName = @CompanyName,
        CompanyGSTNo = @CompanyGSTNo,
        CompanyAddress1 = @CompanyAddress1,
        CompanyAddress2 = @CompanyAddress2,
        CompanyLogo = @CompanyLogo,
        CompanyDescription = @CompanyDescription,
        CompanyNameColor = @CompanyNameColor
    WHERE CompanyId = @CompanyId;

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

CREATE OR ALTER PROCEDURE dbo.sp_GetLocations
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LocationId, LocationName, Address, City, IsActive, CreatedAt
    FROM dbo.WarehouseLocation
    WHERE IsActive = 1 AND CompanyId = @CompanyId
    ORDER BY LocationName;
END
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

CREATE OR ALTER PROCEDURE dbo.sp_GetMaterials
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaterialId, MaterialName, Color, HSNCode, Rate, Unit, Remark, IsActive, CreatedAt, UpdatedAt
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
    @HSNCode      NVARCHAR(20) = NULL,
    @Rate         DECIMAL(18,2),
    @Unit         NVARCHAR(20),
    @Remark       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @MaterialId IS NULL OR @MaterialId = 0
    BEGIN
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

CREATE OR ALTER PROCEDURE dbo.sp_DeleteMaterial
    @CompanyId INT,
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Material not found.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId)
    BEGIN
        RAISERROR(N'Cannot delete: Material has opening stock records.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM dbo.PurchaseInwardDetail d
        INNER JOIN dbo.PurchaseInwardHeader h ON h.PurchaseId = d.PurchaseId
        WHERE d.MaterialId = @MaterialId AND h.CompanyId = @CompanyId
    )
    BEGIN
        RAISERROR(N'Cannot delete: Material is used in Purchase Inward.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM dbo.SalesDetail d
        INNER JOIN dbo.SalesHeader h ON h.SalesId = d.SalesId
        WHERE d.MaterialId = @MaterialId AND h.CompanyId = @CompanyId
    )
    BEGIN
        RAISERROR(N'Cannot delete: Material is used in Sales.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM dbo.StockLedger
        WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId
        GROUP BY MaterialId
        HAVING ISNULL(SUM(QuantityIn - QuantityOut), 0) > 0
    )
    BEGIN
        RAISERROR(N'Cannot delete: Material still has stock present.', 16, 1);
        RETURN;
    END

    UPDATE dbo.MaterialMaster SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetSuppliers
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SupplierId, SupplierName, GSTNo, MobileNo, Address1, Address2, Remark, Email, IsActive, CreatedAt, UpdatedAt
    FROM dbo.SupplierMaster
    WHERE IsActive = 1 AND CompanyId = @CompanyId
    ORDER BY SupplierName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSupplier
    @CompanyId    INT,
    @SupplierId   INT = NULL,
    @SupplierName NVARCHAR(150),
    @GSTNo        NVARCHAR(20) = NULL,
    @MobileNo     NVARCHAR(20) = NULL,
    @Address1     NVARCHAR(250) = NULL,
    @Address2     NVARCHAR(250) = NULL,
    @Remark       NVARCHAR(500) = NULL,
    @Email        NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @SupplierId IS NULL OR @SupplierId = 0
    BEGIN
        INSERT INTO dbo.SupplierMaster (CompanyId, SupplierName, GSTNo, MobileNo, Address1, Address2, Remark, Email)
        VALUES (@CompanyId, @SupplierName, @GSTNo, @MobileNo, @Address1, @Address2, @Remark, @Email);
        SELECT SCOPE_IDENTITY() AS SupplierId;
    END
    ELSE
    BEGIN
        UPDATE dbo.SupplierMaster
        SET SupplierName = @SupplierName, GSTNo = @GSTNo, MobileNo = @MobileNo,
            Address1 = @Address1, Address2 = @Address2, Remark = @Remark, Email = @Email,
            UpdatedAt = SYSUTCDATETIME()
        WHERE SupplierId = @SupplierId AND CompanyId = @CompanyId;
        SELECT @SupplierId AS SupplierId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSupplier
    @CompanyId INT,
    @SupplierId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.SupplierMaster WHERE SupplierId = @SupplierId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Supplier not found.', 16, 1);
        RETURN;
    END

    DECLARE @SupplierName NVARCHAR(150);
    SELECT @SupplierName = SupplierName FROM dbo.SupplierMaster WHERE SupplierId = @SupplierId AND CompanyId = @CompanyId;

    IF EXISTS (
        SELECT 1 FROM dbo.PurchaseInwardHeader
        WHERE CompanyId = @CompanyId AND SupplierName = @SupplierName
    )
    BEGIN
        RAISERROR(N'Cannot delete: Supplier is used in Purchase Inward.', 16, 1);
        RETURN;
    END

    UPDATE dbo.SupplierMaster SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE SupplierId = @SupplierId AND CompanyId = @CompanyId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetOpeningStock
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        os.OpeningStockId, os.MaterialId, m.MaterialName, m.Color, m.HSNCode, m.Unit,
        os.LocationId, l.LocationName, os.Quantity, ISNULL(os.Rate, 0) AS Rate,
        CAST(os.Quantity * ISNULL(os.Rate, 0) AS DECIMAL(18,2)) AS Amount,
        os.StockDate, os.Remark, os.CreatedAt
    FROM dbo.OpeningStock os
    INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId AND m.CompanyId = @CompanyId
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = os.LocationId AND l.CompanyId = @CompanyId
    WHERE os.CompanyId = @CompanyId
    ORDER BY os.StockDate DESC, os.OpeningStockId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveOpeningStock
    @CompanyId      INT,
    @OpeningStockId INT = NULL,
    @MaterialId     INT,
    @LocationId     INT,
    @Quantity       DECIMAL(18,3),
    @Rate           DECIMAL(18,2) = NULL,
    @StockDate      DATE = NULL,
    @Remark         NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @StockDate IS NULL SET @StockDate = dbo.fn_GetIndiaDate();

    IF NOT EXISTS (SELECT 1 FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN RAISERROR(N'Invalid material.', 16, 1); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1)
    BEGIN RAISERROR(N'Invalid warehouse location.', 16, 1); RETURN; END

    IF @Rate IS NULL
        SELECT @Rate = Rate FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId;
    SET @Rate = ISNULL(@Rate, 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @OpeningStockId IS NULL OR @OpeningStockId = 0
        BEGIN
            SELECT @OpeningStockId = OpeningStockId
            FROM dbo.OpeningStock
            WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId;

            IF @OpeningStockId IS NULL
            BEGIN
                INSERT INTO dbo.OpeningStock (CompanyId, MaterialId, LocationId, Quantity, Rate, StockDate, Remark)
                VALUES (@CompanyId, @MaterialId, @LocationId, @Quantity, @Rate, @StockDate, @Remark);
                SET @OpeningStockId = SCOPE_IDENTITY();
            END
            ELSE
            BEGIN
                UPDATE dbo.OpeningStock
                SET Quantity = @Quantity, Rate = @Rate, StockDate = @StockDate, Remark = @Remark
                WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;
                DELETE FROM dbo.StockLedger
                WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;
            END

            INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
            VALUES (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId)
            BEGIN RAISERROR(N'Opening stock record not found.', 16, 1); RETURN; END

            UPDATE dbo.OpeningStock
            SET MaterialId = @MaterialId, LocationId = @LocationId, Quantity = @Quantity,
                Rate = @Rate, StockDate = @StockDate, Remark = @Remark
            WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;

            DELETE FROM dbo.StockLedger WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;

            INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
            VALUES (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);
        END

        COMMIT TRANSACTION;
        SELECT @OpeningStockId AS OpeningStockId, @Rate AS Rate;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetPurchaseInward
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT h.PurchaseId, h.PurchaseNo, h.PurchaseDate, h.LocationId, l.LocationName,
           h.SupplierName, h.Remark, h.CreatedAt,
           d.PurchaseDetailId, d.MaterialId, m.MaterialName, m.Unit, d.Quantity, d.Rate, d.Amount
    FROM dbo.PurchaseInwardHeader h
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = h.LocationId AND l.CompanyId = @CompanyId
    LEFT JOIN dbo.PurchaseInwardDetail d ON d.PurchaseId = h.PurchaseId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
    WHERE h.CompanyId = @CompanyId
    ORDER BY h.PurchaseDate DESC, h.PurchaseId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePurchaseInward
    @CompanyId     INT,
    @PurchaseDate  DATE,
    @LocationId    INT,
    @SupplierName  NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @DetailsJson   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @FyCode NVARCHAR(4) = dbo.fn_GetFinancialYearCode(@PurchaseDate);
        DECLARE @PeriodPrefix NVARCHAR(20) = N'PIN-' + @FyCode + N'-';
        DECLARE @NextNo INT = ISNULL((
            SELECT MAX(TRY_CAST(RIGHT(h.PurchaseNo, 4) AS INT))
            FROM dbo.PurchaseInwardHeader h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.CompanyId = @CompanyId
              AND h.PurchaseNo LIKE @PeriodPrefix + N'%'
        ), 0) + 1;
        SET @PurchaseNo = @PeriodPrefix + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        INSERT INTO dbo.PurchaseInwardHeader (CompanyId, PurchaseNo, PurchaseDate, LocationId, SupplierName, Remark)
        VALUES (@CompanyId, @PurchaseNo, @PurchaseDate, @LocationId, @SupplierName, @Remark);

        DECLARE @PurchaseId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, Quantity, Rate)
        SELECT @PurchaseId, COALESCE(MaterialId, MaterialId2), COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found. Check material and quantity.', 1;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d
        WHERE d.PurchaseId = @PurchaseId;

        IF @@ROWCOUNT = 0 THROW 50004, N'Stock ledger update failed for purchase inward.', 1;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdatePurchaseInward
    @CompanyId     INT,
    @PurchaseId    INT,
    @PurchaseDate  DATE,
    @LocationId    INT,
    @SupplierName  NVARCHAR(150) = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @DetailsJson   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId)
            THROW 50022, N'Purchase record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @OldLocationId INT;
        DECLARE @StockError NVARCHAR(500);

        SELECT @PurchaseNo = PurchaseNo, @OldLocationId = LocationId
        FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot update — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @OldLocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @OldLocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId AND CompanyId = @CompanyId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;

        UPDATE dbo.PurchaseInwardHeader
        SET PurchaseDate = @PurchaseDate, LocationId = @LocationId, SupplierName = @SupplierName, Remark = @Remark
        WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, Quantity, Rate)
        SELECT @PurchaseId, COALESCE(MaterialId, MaterialId2), COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found.', 1;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d WHERE d.PurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeletePurchaseInward
    @CompanyId INT,
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId)
            THROW 50020, N'Purchase record not found.', 1;

        DECLARE @LocationId INT;
        DECLARE @StockError NVARCHAR(500);
        SELECT @LocationId = LocationId FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot delete — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @LocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId AND CompanyId = @CompanyId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
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
        h.CustomerName, h.Remark, h.CreatedAt,
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

CREATE OR ALTER PROCEDURE dbo.sp_GetAvailableStock
    @CompanyId INT,
    @MaterialId INT,
    @LocationId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0) AS AvailableStock
    FROM dbo.StockLedger
    WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockByMaterial
    @CompanyId INT,
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT l.LocationId, l.LocationName,
           ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS AvailableStock
    FROM dbo.WarehouseLocation l
    LEFT JOIN dbo.StockLedger sl
        ON sl.LocationId = l.LocationId AND sl.MaterialId = @MaterialId AND sl.CompanyId = @CompanyId
    WHERE l.IsActive = 1 AND l.CompanyId = @CompanyId
    GROUP BY l.LocationId, l.LocationName
    ORDER BY l.LocationName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
    @CompanyId         INT,
    @SalesDate         DATE,
    @CustomerName      NVARCHAR(150) = NULL,
    @Remark            NVARCHAR(500) = NULL,
    @DetailsJson       NVARCHAR(MAX),
    @GSTRate           DECIMAL(18,2) = 0,
    @DiscountType      NVARCHAR(10) = NULL,
    @DiscountPercent   DECIMAL(18,2) = 0,
    @DiscountAmount    DECIMAL(18,2) = 0,
    @RoundOff          DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            WHERE COALESCE(j.MaterialId, j.MaterialId2) IS NULL
               OR COALESCE(j.LocationId, j.LocationId2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) IS NULL
               OR COALESCE(j.Quantity, j.Quantity2) <= 0
        )
            THROW 50012, N'Each line must have material, warehouse location and quantity.', 1;

        IF EXISTS (
            SELECT 1 FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId', MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId') j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2) AND l.CompanyId = @CompanyId AND l.IsActive = 1
            LEFT JOIN dbo.MaterialMaster m
                ON m.MaterialId = COALESCE(j.MaterialId, j.MaterialId2) AND m.CompanyId = @CompanyId AND m.IsActive = 1
            WHERE l.LocationId IS NULL OR m.MaterialId IS NULL
        )
            THROW 50013, N'Invalid or inactive warehouse on one or more lines.', 1;

        DECLARE @StockError NVARCHAR(500);

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT COALESCE(j.MaterialId, j.MaterialId2) AS MaterialId,
                   COALESCE(j.LocationId, j.LocationId2) AS LocationId,
                   SUM(COALESCE(j.Quantity, j.Quantity2)) AS TotalQty
            FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            GROUP BY COALESCE(j.MaterialId, j.MaterialId2), COALESCE(j.LocationId, j.LocationId2)
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL THROW 50014, @StockError, 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @FyCode NVARCHAR(4) = dbo.fn_GetFinancialYearCode(@SalesDate);
        DECLARE @PeriodPrefix NVARCHAR(20) = N'SAL-' + @FyCode + N'-';
        DECLARE @NextNo INT = ISNULL((
            SELECT MAX(TRY_CAST(RIGHT(h.SalesNo, 4) AS INT))
            FROM dbo.SalesHeader h WITH (UPDLOCK, HOLDLOCK)
            WHERE h.CompanyId = @CompanyId
              AND h.SalesNo LIKE @PeriodPrefix + N'%'
        ), 0) + 1;
        SET @SalesNo = @PeriodPrefix + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson) WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        INSERT INTO dbo.SalesHeader (CompanyId, SalesNo, SalesDate, LocationId, CustomerName, Remark)
        VALUES (@CompanyId, @SalesNo, @SalesDate, @HeaderLocationId, @CustomerName, @Remark);

        DECLARE @SalesId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId, COALESCE(MaterialId, MaterialId2), COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(LocationId, LocationId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
            THROW 50015, N'No valid sales items found.', 1;

        DECLARE @SubTotal DECIMAL(18,2);
        DECLARE @DiscountValue DECIMAL(18,2);
        DECLARE @TaxableAmount DECIMAL(18,2);
        DECLARE @GSTAmount DECIMAL(18,2);
        DECLARE @GrandTotal DECIMAL(18,2);

        SELECT @SubTotal = ISNULL(SUM(Amount), 0) FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        IF UPPER(ISNULL(@DiscountType, N'')) = N'PERCENT'
            SET @DiscountValue = ROUND(@SubTotal * ISNULL(@DiscountPercent, 0) / 100.0, 2);
        ELSE IF UPPER(ISNULL(@DiscountType, N'')) = N'AMOUNT'
            SET @DiscountValue = ISNULL(@DiscountAmount, 0);
        ELSE SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET SubTotal = @SubTotal, DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0), DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue, GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount, RoundOff = ISNULL(@RoundOff, 0), GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0 THROW 50016, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSales
    @CompanyId INT,
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId)
            THROW 50030, N'Sales record not found.', 1;
        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId AND CompanyId = @CompanyId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;
        DELETE FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId;
        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateSales
    @CompanyId INT,
    @SalesId INT,
    @SalesDate DATE,
    @CustomerName NVARCHAR(150) = NULL,
    @Remark NVARCHAR(500) = NULL,
    @DetailsJson NVARCHAR(MAX),
    @GSTRate DECIMAL(18,2) = 0,
    @DiscountType NVARCHAR(10) = NULL,
    @DiscountPercent DECIMAL(18,2) = 0,
    @DiscountAmount DECIMAL(18,2) = 0,
    @RoundOff DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId)
            THROW 50031, N'Sales record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        DECLARE @SalesNo NVARCHAR(30);
        SELECT @SalesNo = SalesNo FROM dbo.SalesHeader WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId AND CompanyId = @CompanyId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        UPDATE dbo.SalesHeader
        SET SalesDate = @SalesDate, CustomerName = @CustomerName, Remark = @Remark
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId, COALESCE(MaterialId, MaterialId2), COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2), COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
            LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
            Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity',
            Rate DECIMAL(18,2) '$.Rate', Rate2 DECIMAL(18,2) '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(LocationId, LocationId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
            THROW 50015, N'No valid sales items found.', 1;

        DECLARE @StockError NVARCHAR(500);
        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT COALESCE(j.MaterialId, j.MaterialId2) AS MaterialId,
                   COALESCE(j.LocationId, j.LocationId2) AS LocationId,
                   SUM(COALESCE(j.Quantity, j.Quantity2)) AS TotalQty
            FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                LocationId INT '$.LocationId', LocationId2 INT '$.locationId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            GROUP BY COALESCE(j.MaterialId, j.MaterialId2), COALESCE(j.LocationId, j.LocationId2)
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL THROW 50014, @StockError, 1;

        DECLARE @SubTotal DECIMAL(18,2);
        DECLARE @DiscountValue DECIMAL(18,2);
        DECLARE @TaxableAmount DECIMAL(18,2);
        DECLARE @GSTAmount DECIMAL(18,2);
        DECLARE @GrandTotal DECIMAL(18,2);

        SELECT @SubTotal = ISNULL(SUM(Amount), 0) FROM dbo.SalesDetail WHERE SalesId = @SalesId;

        IF UPPER(ISNULL(@DiscountType, N'')) = N'PERCENT'
            SET @DiscountValue = ROUND(@SubTotal * ISNULL(@DiscountPercent, 0) / 100.0, 2);
        ELSE IF UPPER(ISNULL(@DiscountType, N'')) = N'AMOUNT'
            SET @DiscountValue = ISNULL(@DiscountAmount, 0);
        ELSE SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET SubTotal = @SubTotal, DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0), DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue, GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount, RoundOff = ISNULL(@RoundOff, 0), GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId AND CompanyId = @CompanyId;

        INSERT INTO dbo.StockLedger (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT @CompanyId, d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d WHERE d.SalesId = @SalesId;

        COMMIT TRANSACTION;
        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
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

CREATE OR ALTER PROCEDURE dbo.sp_GetStockLedgerReport
    @CompanyId INT,
    @LocationId INT = NULL,
    @FromDate   DATE = NULL,
    @ToDate     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -1, dbo.fn_GetIndiaNow());
    IF @ToDate IS NULL SET @ToDate = dbo.fn_GetIndiaNow();

    SELECT LedgerId, TransactionDate, TransactionType, ReferenceNo,
           MaterialId, MaterialName, Color, HSNCode, Unit,
           LocationId, LocationName, QuantityIn, QuantityOut, NetQty
    FROM dbo.vw_StockReport
    WHERE CompanyId = @CompanyId
      AND (@LocationId IS NULL OR LocationId = @LocationId)
      AND TransactionDate BETWEEN @FromDate AND @ToDate
    ORDER BY TransactionDate DESC, LedgerId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetDashboardStats
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.MaterialMaster WHERE IsActive = 1 AND CompanyId = @CompanyId) AS TotalMaterials,
        (SELECT COUNT(*) FROM dbo.WarehouseLocation WHERE IsActive = 1 AND CompanyId = @CompanyId) AS TotalLocations,
        (SELECT COUNT(*) FROM dbo.PurchaseInwardHeader WHERE CompanyId = @CompanyId) AS TotalPurchases,
        (SELECT COUNT(*) FROM dbo.SalesHeader WHERE CompanyId = @CompanyId) AS TotalSales,
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.vw_StockSummary WHERE CompanyId = @CompanyId) AS TotalStockQty,
        (SELECT COUNT(*) FROM dbo.vw_MaterialStockByLocation WHERE CompanyId = @CompanyId AND StockStatus = N'Low Stock') AS LowStockItems;
END
GO

PRINT 'Multi-company setup completed.';
GO
