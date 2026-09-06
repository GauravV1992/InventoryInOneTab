/* ============================================================
   InventoryInOneTap - Retailer Inventory Management Database
   Execute this script manually in SQL Server Management Studio
   ============================================================ */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'PawanPutra')
    CREATE DATABASE PawanPutra;
GO

USE PawanPutra;
GO

/* ===================== TABLES ===================== */

IF OBJECT_ID('dbo.SalesDetail', 'U') IS NOT NULL DROP TABLE dbo.SalesDetail;
IF OBJECT_ID('dbo.SalesHeader', 'U') IS NOT NULL DROP TABLE dbo.SalesHeader;
IF OBJECT_ID('dbo.PurchaseInwardDetail', 'U') IS NOT NULL DROP TABLE dbo.PurchaseInwardDetail;
IF OBJECT_ID('dbo.PurchaseInwardHeader', 'U') IS NOT NULL DROP TABLE dbo.PurchaseInwardHeader;
IF OBJECT_ID('dbo.OpeningStock', 'U') IS NOT NULL DROP TABLE dbo.OpeningStock;
IF OBJECT_ID('dbo.StockLedger', 'U') IS NOT NULL DROP TABLE dbo.StockLedger;
IF OBJECT_ID('dbo.MaterialMaster', 'U') IS NOT NULL DROP TABLE dbo.MaterialMaster;
IF OBJECT_ID('dbo.SupplierMaster', 'U') IS NOT NULL DROP TABLE dbo.SupplierMaster;
IF OBJECT_ID('dbo.WarehouseLocation', 'U') IS NOT NULL DROP TABLE dbo.WarehouseLocation;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
    UserId              INT IDENTITY(1,1) PRIMARY KEY,
    Username            NVARCHAR(50)  NOT NULL UNIQUE,
    PasswordHash        NVARCHAR(256) NOT NULL,
    FullName            NVARCHAR(100) NOT NULL,
    FirstName           NVARCHAR(100) NULL,
    LastName            NVARCHAR(100) NULL,
    Email               NVARCHAR(150) NULL,
    CompanyName         NVARCHAR(150) NULL,
    CompanyGSTNo        NVARCHAR(20)  NULL,
    CompanyAddress1     NVARCHAR(250) NULL,
    CompanyAddress2     NVARCHAR(250) NULL,
    CompanyLogo         NVARCHAR(MAX) NULL,
    CompanyDescription  NVARCHAR(1000) NULL,
    CompanyNameColor    NVARCHAR(20)  NULL,
    IsActive            BIT NOT NULL DEFAULT 1,
    CreatedAt           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.WarehouseLocation (
    LocationId   INT IDENTITY(1,1) PRIMARY KEY,
    LocationName NVARCHAR(100) NOT NULL,
    Address      NVARCHAR(250) NULL,
    City         NVARCHAR(100) NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.MaterialMaster (
    MaterialId   INT IDENTITY(1,1) PRIMARY KEY,
    MaterialName NVARCHAR(150) NOT NULL,
    Color        NVARCHAR(50)  NULL,
    HSNCode      NVARCHAR(20)  NULL,
    Rate         DECIMAL(18,2) NOT NULL DEFAULT 0,
    Unit         NVARCHAR(20)  NOT NULL DEFAULT N'Pcs',
    Remark       NVARCHAR(500) NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt    DATETIME2 NULL
);

CREATE TABLE dbo.SupplierMaster (
    SupplierId   INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName NVARCHAR(150) NOT NULL,
    GSTNo        NVARCHAR(20)  NULL,
    MobileNo     NVARCHAR(20)  NULL,
    Address1     NVARCHAR(250) NULL,
    Address2     NVARCHAR(250) NULL,
    Remark       NVARCHAR(500) NULL,
    Email        NVARCHAR(150) NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt    DATETIME2 NULL
);

CREATE TABLE dbo.OpeningStock (
    OpeningStockId INT IDENTITY(1,1) PRIMARY KEY,
    MaterialId     INT NOT NULL,
    LocationId     INT NOT NULL,
    Quantity       DECIMAL(18,3) NOT NULL DEFAULT 0,
    StockDate      DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Remark         NVARCHAR(500) NULL,
    CreatedAt      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_OpeningStock_Material FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId),
    CONSTRAINT FK_OpeningStock_Location FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId),
    CONSTRAINT UQ_OpeningStock_MaterialLocation UNIQUE (MaterialId, LocationId)
);

CREATE TABLE dbo.PurchaseInwardHeader (
    PurchaseId   INT IDENTITY(1,1) PRIMARY KEY,
    PurchaseNo   NVARCHAR(30) NOT NULL UNIQUE,
    PurchaseDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    LocationId   INT NOT NULL,
    SupplierName NVARCHAR(150) NULL,
    Remark       NVARCHAR(500) NULL,
    CreatedAt    DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_PurchaseInward_Location FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId)
);

CREATE TABLE dbo.PurchaseInwardDetail (
    PurchaseDetailId INT IDENTITY(1,1) PRIMARY KEY,
    PurchaseId       INT NOT NULL,
    MaterialId       INT NOT NULL,
    Quantity         DECIMAL(18,3) NOT NULL,
    Rate             DECIMAL(18,2) NOT NULL DEFAULT 0,
    Amount           AS (Quantity * Rate) PERSISTED,
    CONSTRAINT FK_PurchaseDetail_Header FOREIGN KEY (PurchaseId) REFERENCES dbo.PurchaseInwardHeader(PurchaseId) ON DELETE CASCADE,
    CONSTRAINT FK_PurchaseDetail_Material FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId)
);

CREATE TABLE dbo.SalesHeader (
    SalesId          INT IDENTITY(1,1) PRIMARY KEY,
    SalesNo          NVARCHAR(30) NOT NULL UNIQUE,
    SalesDate        DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    LocationId       INT NULL,
    CustomerName     NVARCHAR(150) NULL,
    Remark           NVARCHAR(500) NULL,
    SubTotal         DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountType     NVARCHAR(10) NULL,
    DiscountPercent  DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountAmount   DECIMAL(18,2) NOT NULL DEFAULT 0,
    DiscountValue    DECIMAL(18,2) NOT NULL DEFAULT 0,
    GSTRate          DECIMAL(18,2) NOT NULL DEFAULT 0,
    GSTAmount        DECIMAL(18,2) NOT NULL DEFAULT 0,
    RoundOff         DECIMAL(18,2) NOT NULL DEFAULT 0,
    GrandTotal       DECIMAL(18,2) NOT NULL DEFAULT 0,
    CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Sales_Location FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId)
);

CREATE TABLE dbo.SalesDetail (
    SalesDetailId INT IDENTITY(1,1) PRIMARY KEY,
    SalesId       INT NOT NULL,
    MaterialId    INT NOT NULL,
    LocationId    INT NOT NULL,
    Quantity      DECIMAL(18,3) NOT NULL,
    Rate          DECIMAL(18,2) NOT NULL DEFAULT 0,
    Amount        AS (Quantity * Rate) PERSISTED,
    CONSTRAINT FK_SalesDetail_Header FOREIGN KEY (SalesId) REFERENCES dbo.SalesHeader(SalesId) ON DELETE CASCADE,
    CONSTRAINT FK_SalesDetail_Material FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId),
    CONSTRAINT FK_SalesDetail_Location FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId)
);

/* Stock ledger - single source of truth for stock movements */
CREATE TABLE dbo.StockLedger (
    LedgerId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    MaterialId       INT NOT NULL,
    LocationId       INT NOT NULL,
    TransactionType  NVARCHAR(20) NOT NULL,  -- OPENING, PURCHASE, SALES
    ReferenceId      INT NOT NULL,
    ReferenceNo      NVARCHAR(30) NULL,
    TransactionDate  DATE NOT NULL,
    QuantityIn       DECIMAL(18,3) NOT NULL DEFAULT 0,
    QuantityOut        DECIMAL(18,3) NOT NULL DEFAULT 0,
    CreatedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_StockLedger_Material FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId),
    CONSTRAINT FK_StockLedger_Location FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId)
);

CREATE INDEX IX_StockLedger_MaterialLocation ON dbo.StockLedger(MaterialId, LocationId);
CREATE INDEX IX_StockLedger_TransactionDate ON dbo.StockLedger(TransactionDate);
GO

/* ===================== SEED DATA ===================== */

-- Default login: admin / welcome123
INSERT INTO dbo.Users (Username, PasswordHash, FullName, FirstName, LastName, CompanyName, CompanyAddress1, CompanyDescription, CompanyNameColor)
VALUES (N'admin', N'welcome123', N'Administrator', N'Administrator', N'', N'InventoryInOneTap', N'Ahmedabad, Gujarat, India', N'Inventory in One Tap', N'#f97316');

INSERT INTO dbo.WarehouseLocation (LocationName, Address, City) VALUES
(N'Main Warehouse', N'Plot 12, Industrial Area', N'Ahmedabad'),
(N'Showroom Store', N'Shop 5, Market Road', N'Ahmedabad'),
(N'Godown - B', N'Near Ring Road', N'Gandhinagar');
GO

/* ===================== VIEWS ===================== */

CREATE OR ALTER VIEW dbo.vw_StockSummary
AS
SELECT
    m.MaterialId,
    m.MaterialName,
    m.Color,
    m.HSNCode,
    m.Rate,
    m.Unit,
    l.LocationId,
    l.LocationName,
    ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS CurrentStock
FROM dbo.MaterialMaster m
CROSS JOIN dbo.WarehouseLocation l
LEFT JOIN dbo.StockLedger sl
    ON sl.MaterialId = m.MaterialId
   AND sl.LocationId = l.LocationId
WHERE m.IsActive = 1 AND l.IsActive = 1
GROUP BY
    m.MaterialId, m.MaterialName, m.Color, m.HSNCode, m.Rate, m.Unit,
    l.LocationId, l.LocationName;
GO

CREATE OR ALTER VIEW dbo.vw_StockReport
AS
SELECT
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
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = sl.MaterialId
INNER JOIN dbo.WarehouseLocation l ON l.LocationId = sl.LocationId;
GO

CREATE OR ALTER VIEW dbo.vw_MaterialStockByLocation
AS
SELECT
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

/* ===================== STORED PROCEDURES ===================== */

/* --- Auth --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetUserByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId, Username, PasswordHash, FullName, IsActive
    FROM dbo.Users
    WHERE Username = @Username AND IsActive = 1;
END
GO

/* --- Warehouse Location --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetLocations
AS
BEGIN
    SET NOCOUNT ON;
    SELECT LocationId, LocationName, Address, City, IsActive, CreatedAt
    FROM dbo.WarehouseLocation
    WHERE IsActive = 1
    ORDER BY LocationName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveLocation
    @LocationId   INT = NULL,
    @LocationName NVARCHAR(100),
    @Address      NVARCHAR(250) = NULL,
    @City         NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @LocationId IS NULL OR @LocationId = 0
    BEGIN
        INSERT INTO dbo.WarehouseLocation (LocationName, Address, City)
        VALUES (@LocationName, @Address, @City);
        SELECT SCOPE_IDENTITY() AS LocationId;
    END
    ELSE
    BEGIN
        UPDATE dbo.WarehouseLocation
        SET LocationName = @LocationName, Address = @Address, City = @City
        WHERE LocationId = @LocationId;
        SELECT @LocationId AS LocationId;
    END
END
GO

/* --- Material Master --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetMaterials
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MaterialId, MaterialName, Color, HSNCode, Rate, Unit, Remark, IsActive, CreatedAt, UpdatedAt
    FROM dbo.MaterialMaster
    WHERE IsActive = 1
    ORDER BY MaterialName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveMaterial
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
        INSERT INTO dbo.MaterialMaster (MaterialName, Color, HSNCode, Rate, Unit, Remark)
        VALUES (@MaterialName, @Color, @HSNCode, @Rate, @Unit, @Remark);
        SELECT SCOPE_IDENTITY() AS MaterialId;
    END
    ELSE
    BEGIN
        UPDATE dbo.MaterialMaster
        SET MaterialName = @MaterialName, Color = @Color, HSNCode = @HSNCode,
            Rate = @Rate, Unit = @Unit, Remark = @Remark, UpdatedAt = SYSUTCDATETIME()
        WHERE MaterialId = @MaterialId;
        SELECT @MaterialId AS MaterialId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteMaterial
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.MaterialMaster WHERE MaterialId = @MaterialId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Material not found.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE MaterialId = @MaterialId)
    BEGIN
        RAISERROR(N'Cannot delete: Material has opening stock records.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE MaterialId = @MaterialId)
    BEGIN
        RAISERROR(N'Cannot delete: Material is used in Purchase Inward.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE MaterialId = @MaterialId)
    BEGIN
        RAISERROR(N'Cannot delete: Material is used in Sales.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM dbo.StockLedger
        WHERE MaterialId = @MaterialId
        GROUP BY MaterialId
        HAVING ISNULL(SUM(QuantityIn - QuantityOut), 0) > 0
    )
    BEGIN
        RAISERROR(N'Cannot delete: Material still has stock present.', 16, 1);
        RETURN;
    END

    UPDATE dbo.MaterialMaster SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE MaterialId = @MaterialId;
END
GO

/* --- Supplier Master --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetSuppliers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SupplierId, SupplierName, GSTNo, MobileNo, Address1, Address2, Remark, Email, IsActive, CreatedAt, UpdatedAt
    FROM dbo.SupplierMaster
    WHERE IsActive = 1
    ORDER BY SupplierName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSupplier
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
        INSERT INTO dbo.SupplierMaster (SupplierName, GSTNo, MobileNo, Address1, Address2, Remark, Email)
        VALUES (@SupplierName, @GSTNo, @MobileNo, @Address1, @Address2, @Remark, @Email);
        SELECT SCOPE_IDENTITY() AS SupplierId;
    END
    ELSE
    BEGIN
        UPDATE dbo.SupplierMaster
        SET SupplierName = @SupplierName,
            GSTNo = @GSTNo,
            MobileNo = @MobileNo,
            Address1 = @Address1,
            Address2 = @Address2,
            Remark = @Remark,
            Email = @Email,
            UpdatedAt = SYSUTCDATETIME()
        WHERE SupplierId = @SupplierId;
        SELECT @SupplierId AS SupplierId;
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSupplier
    @SupplierId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.SupplierMaster WHERE SupplierId = @SupplierId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Supplier not found.', 16, 1);
        RETURN;
    END

    DECLARE @SupplierName NVARCHAR(150);
    SELECT @SupplierName = SupplierName FROM dbo.SupplierMaster WHERE SupplierId = @SupplierId;

    IF EXISTS (
        SELECT 1 FROM dbo.PurchaseInwardHeader
        WHERE SupplierName = @SupplierName
    )
    BEGIN
        RAISERROR(N'Cannot delete: Supplier is used in Purchase Inward.', 16, 1);
        RETURN;
    END

    UPDATE dbo.SupplierMaster
    SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE SupplierId = @SupplierId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteLocation
    @LocationId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND IsActive = 1)
    BEGIN
        RAISERROR(N'Warehouse location not found.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE LocationId = @LocationId)
    BEGIN
        RAISERROR(N'Cannot delete: Warehouse has opening stock records.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE LocationId = @LocationId)
    BEGIN
        RAISERROR(N'Cannot delete: Warehouse is used in Purchase Inward.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE LocationId = @LocationId)
    BEGIN
        RAISERROR(N'Cannot delete: Warehouse is used in Sales.', 16, 1);
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM dbo.StockLedger
        WHERE LocationId = @LocationId
        GROUP BY LocationId
        HAVING ISNULL(SUM(QuantityIn - QuantityOut), 0) > 0
    )
    BEGIN
        RAISERROR(N'Cannot delete: Warehouse still has stock present.', 16, 1);
        RETURN;
    END

    UPDATE dbo.WarehouseLocation SET IsActive = 0 WHERE LocationId = @LocationId;
END
GO

/* --- Opening Stock --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetOpeningStock
AS
BEGIN
    SET NOCOUNT ON;
    SELECT os.OpeningStockId, os.MaterialId, m.MaterialName, m.Color, m.HSNCode, m.Unit,
           os.LocationId, l.LocationName, os.Quantity, os.StockDate, os.Remark, os.CreatedAt
    FROM dbo.OpeningStock os
    INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = os.LocationId
    ORDER BY os.StockDate DESC, m.MaterialName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveOpeningStock
    @MaterialId INT,
    @LocationId INT,
    @Quantity   DECIMAL(18,3),
    @StockDate  DATE = NULL,
    @Remark     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @StockDate IS NULL SET @StockDate = CAST(GETDATE() AS DATE);

        DECLARE @OpeningStockId INT;

        IF EXISTS (SELECT 1 FROM dbo.OpeningStock WHERE MaterialId = @MaterialId AND LocationId = @LocationId)
        BEGIN
            SELECT @OpeningStockId = OpeningStockId
            FROM dbo.OpeningStock
            WHERE MaterialId = @MaterialId AND LocationId = @LocationId;

            UPDATE dbo.OpeningStock
            SET Quantity = @Quantity, StockDate = @StockDate, Remark = @Remark
            WHERE OpeningStockId = @OpeningStockId;

            DELETE FROM dbo.StockLedger
            WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId;
        END
        ELSE
        BEGIN
            INSERT INTO dbo.OpeningStock (MaterialId, LocationId, Quantity, StockDate, Remark)
            VALUES (@MaterialId, @LocationId, @Quantity, @StockDate, @Remark);
            SET @OpeningStockId = SCOPE_IDENTITY();
        END

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        VALUES (@MaterialId, @LocationId, N'OPENING', @OpeningStockId, N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Quantity, 0);

        COMMIT TRANSACTION;
        SELECT @OpeningStockId AS OpeningStockId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* --- Purchase Inward --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetPurchaseInward
AS
BEGIN
    SET NOCOUNT ON;
    SELECT h.PurchaseId, h.PurchaseNo, h.PurchaseDate, h.LocationId, l.LocationName,
           h.SupplierName, h.Remark, h.CreatedAt,
           d.PurchaseDetailId, d.MaterialId, m.MaterialName, m.Unit, d.Quantity, d.Rate, d.Amount
    FROM dbo.PurchaseInwardHeader h
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = h.LocationId
    LEFT JOIN dbo.PurchaseInwardDetail d ON d.PurchaseId = h.PurchaseId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
    ORDER BY h.PurchaseDate DESC, h.PurchaseId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SavePurchaseInward
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

        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @NextNo INT = ISNULL((SELECT MAX(PurchaseId) FROM dbo.PurchaseInwardHeader WITH (UPDLOCK, HOLDLOCK)), 0) + 1;
        SET @PurchaseNo = N'PIN-' + FORMAT(GETDATE(), 'yyyyMM') + N'-' + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        INSERT INTO dbo.PurchaseInwardHeader (PurchaseNo, PurchaseDate, LocationId, SupplierName, Remark)
        VALUES (@PurchaseNo, @PurchaseDate, @LocationId, @SupplierName, @Remark);

        DECLARE @PurchaseId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.PurchaseInwardDetail (PurchaseId, MaterialId, Quantity, Rate)
        SELECT @PurchaseId,
               COALESCE(MaterialId, MaterialId2) AS MaterialId,
               COALESCE(Quantity, Quantity2) AS Quantity,
               COALESCE(Rate, Rate2, 0) AS Rate
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId  INT             '$.MaterialId',
            MaterialId2 INT             '$.materialId',
            Quantity    DECIMAL(18,3)   '$.Quantity',
            Quantity2   DECIMAL(18,3)   '$.quantity',
            Rate        DECIMAL(18,2)   '$.Rate',
            Rate2       DECIMAL(18,2)   '$.rate'
        )
        WHERE COALESCE(MaterialId, MaterialId2) IS NOT NULL
          AND COALESCE(Quantity, Quantity2) > 0;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId)
            THROW 50003, N'No valid purchase items found. Check material and quantity.', 1;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
        FROM dbo.PurchaseInwardDetail d
        WHERE d.PurchaseId = @PurchaseId;

        IF @@ROWCOUNT = 0
            THROW 50004, N'Stock ledger update failed for purchase inward.', 1;

        COMMIT TRANSACTION;

        SELECT @PurchaseId AS PurchaseId, @PurchaseNo AS PurchaseNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdatePurchaseInward
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
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId)
            THROW 50022, N'Purchase record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50001, N'Purchase details are required.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND IsActive = 1)
            THROW 50002, N'Invalid or inactive warehouse location.', 1;

        DECLARE @PurchaseNo NVARCHAR(30);
        DECLARE @OldLocationId INT;
        DECLARE @StockError NVARCHAR(500);

        SELECT @PurchaseNo = PurchaseNo, @OldLocationId = LocationId
        FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot update — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @OldLocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @OldLocationId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;

        UPDATE dbo.PurchaseInwardHeader
        SET PurchaseDate = @PurchaseDate, LocationId = @LocationId,
            SupplierName = @SupplierName, Remark = @Remark
        WHERE PurchaseId = @PurchaseId;

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

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, @LocationId, N'PURCHASE', @PurchaseId, @PurchaseNo, @PurchaseDate, d.Quantity, 0
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
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId)
            THROW 50020, N'Purchase record not found.', 1;

        DECLARE @LocationId INT;
        DECLARE @StockError NVARCHAR(500);
        SELECT @LocationId = LocationId FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': stock would become ' + CAST(s.Avail - d.TotalQty AS NVARCHAR(30))
            + N' (cannot delete — quantity already used in sales)'
        FROM (
            SELECT MaterialId, SUM(Quantity) AS TotalQty
            FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId GROUP BY MaterialId
        ) d
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = @LocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = @LocationId
        ) s
        WHERE s.Avail - d.TotalQty < 0;

        IF @StockError IS NOT NULL THROW 50021, @StockError, 1;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'PURCHASE' AND ReferenceId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardDetail WHERE PurchaseId = @PurchaseId;
        DELETE FROM dbo.PurchaseInwardHeader WHERE PurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
        SELECT @PurchaseId AS PurchaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* --- Sales --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetSales
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
    LEFT JOIN dbo.WarehouseLocation hl ON hl.LocationId = h.LocationId
    LEFT JOIN dbo.SalesDetail d ON d.SalesId = h.SalesId
    LEFT JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
    LEFT JOIN dbo.WarehouseLocation dl ON dl.LocationId = d.LocationId
    ORDER BY h.SalesDate DESC, h.SalesId DESC, d.SalesDetailId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetAvailableStock
    @MaterialId INT,
    @LocationId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0) AS AvailableStock
    FROM dbo.StockLedger
    WHERE MaterialId = @MaterialId AND LocationId = @LocationId;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockByMaterial
    @MaterialId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        l.LocationId,
        l.LocationName,
        ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS AvailableStock
    FROM dbo.WarehouseLocation l
    LEFT JOIN dbo.StockLedger sl
        ON sl.LocationId = l.LocationId
       AND sl.MaterialId = @MaterialId
    WHERE l.IsActive = 1
    GROUP BY l.LocationId, l.LocationName
    ORDER BY l.LocationName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
    @SalesDate        DATE,
    @CustomerName     NVARCHAR(150) = NULL,
    @Remark           NVARCHAR(500) = NULL,
    @DetailsJson      NVARCHAR(MAX),
    @GSTRate          DECIMAL(18,2) = 0,
    @DiscountType     NVARCHAR(10) = NULL,
    @DiscountPercent  DECIMAL(18,2) = 0,
    @DiscountAmount   DECIMAL(18,2) = 0,
    @RoundOff         DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@DetailsJson)
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
            SELECT 1
            FROM OPENJSON(@DetailsJson)
            WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId') j
            LEFT JOIN dbo.WarehouseLocation l
                ON l.LocationId = COALESCE(j.LocationId, j.LocationId2) AND l.IsActive = 1
            WHERE l.LocationId IS NULL
        )
            THROW 50013, N'Invalid or inactive warehouse on one or more lines.', 1;

        DECLARE @StockError NVARCHAR(500);

        SELECT TOP 1 @StockError =
            m.MaterialName + N' @ ' + l.LocationName
            + N': required ' + CAST(d.TotalQty AS NVARCHAR(30))
            + N', available ' + CAST(ISNULL(s.Avail, 0) AS NVARCHAR(30))
        FROM (
            SELECT
                COALESCE(j.MaterialId, j.MaterialId2) AS MaterialId,
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
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId
              AND sl.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL
            THROW 50014, @StockError, 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @NextNo INT = ISNULL((SELECT MAX(SalesId) FROM dbo.SalesHeader WITH (UPDLOCK, HOLDLOCK)), 0) + 1;
        SET @SalesNo = N'SAL-' + FORMAT(GETDATE(), 'yyyyMM') + N'-' + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson)
        WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        INSERT INTO dbo.SalesHeader (SalesNo, SalesDate, LocationId, CustomerName, Remark)
        VALUES (@SalesNo, @SalesDate, @HeaderLocationId, @CustomerName, @Remark);

        DECLARE @SalesId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, LocationId, Quantity, Rate)
        SELECT @SalesId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(LocationId, LocationId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
        FROM OPENJSON(@DetailsJson)
        WITH (
            MaterialId  INT             '$.MaterialId',
            MaterialId2 INT             '$.materialId',
            LocationId  INT             '$.LocationId',
            LocationId2 INT             '$.locationId',
            Quantity    DECIMAL(18,3)   '$.Quantity',
            Quantity2   DECIMAL(18,3)   '$.quantity',
            Rate        DECIMAL(18,2)   '$.Rate',
            Rate2       DECIMAL(18,2)   '$.rate'
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
        ELSE
            SET @DiscountValue = 0;

        IF @DiscountValue > @SubTotal SET @DiscountValue = @SubTotal;
        IF @DiscountValue < 0 SET @DiscountValue = 0;

        SET @TaxableAmount = @SubTotal - @DiscountValue;
        SET @GSTAmount = ROUND(@TaxableAmount * ISNULL(@GSTRate, 0) / 100.0, 2);
        SET @GrandTotal = @TaxableAmount + @GSTAmount + ISNULL(@RoundOff, 0);

        UPDATE dbo.SalesHeader
        SET SubTotal = @SubTotal,
            DiscountType = @DiscountType,
            DiscountPercent = ISNULL(@DiscountPercent, 0),
            DiscountAmount = ISNULL(@DiscountAmount, 0),
            DiscountValue = @DiscountValue,
            GSTRate = ISNULL(@GSTRate, 0),
            GSTAmount = @GSTAmount,
            RoundOff = ISNULL(@RoundOff, 0),
            GrandTotal = @GrandTotal
        WHERE SalesId = @SalesId;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d
        WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0
            THROW 50016, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;

        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo, @GrandTotal AS GrandTotal;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteSales
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId)
            THROW 50030, N'Sales record not found.', 1;
        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;
        DELETE FROM dbo.SalesHeader WHERE SalesId = @SalesId;
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
        IF NOT EXISTS (SELECT 1 FROM dbo.SalesHeader WHERE SalesId = @SalesId)
            THROW 50031, N'Sales record not found.', 1;
        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @StockError NVARCHAR(500);
        SELECT @SalesNo = SalesNo FROM dbo.SalesHeader WHERE SalesId = @SalesId;

        DELETE FROM dbo.StockLedger WHERE TransactionType = N'SALES' AND ReferenceId = @SalesId;
        DELETE FROM dbo.SalesDetail WHERE SalesId = @SalesId;

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
        INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId
        INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId
        CROSS APPLY (
            SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
            FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
            WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId
        ) s
        WHERE d.TotalQty > ISNULL(s.Avail, 0);

        IF @StockError IS NOT NULL THROW 50014, @StockError, 1;

        DECLARE @HeaderLocationId INT;
        SELECT TOP 1 @HeaderLocationId = COALESCE(LocationId, LocationId2)
        FROM OPENJSON(@DetailsJson) WITH (LocationId INT '$.LocationId', LocationId2 INT '$.locationId');

        UPDATE dbo.SalesHeader
        SET SalesDate = @SalesDate, LocationId = @HeaderLocationId,
            CustomerName = @CustomerName, Remark = @Remark
        WHERE SalesId = @SalesId;

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

        DECLARE @SubTotal DECIMAL(18,2), @DiscountValue DECIMAL(18,2),
                @TaxableAmount DECIMAL(18,2), @GSTAmount DECIMAL(18,2), @GrandTotal DECIMAL(18,2);

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
        WHERE SalesId = @SalesId;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, d.LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
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

/* --- Stock Report --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetStockReport
    @LocationId INT = NULL,
    @MaterialId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT MaterialId, MaterialName, Color, HSNCode, Rate, Unit,
           LocationId, LocationName, CurrentStock, StockStatus
    FROM dbo.vw_MaterialStockByLocation
    WHERE (@LocationId IS NULL OR LocationId = @LocationId)
      AND (@MaterialId IS NULL OR MaterialId = @MaterialId)
    ORDER BY LocationName, MaterialName;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetStockLedgerReport
    @LocationId INT = NULL,
    @FromDate   DATE = NULL,
    @ToDate     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @FromDate IS NULL SET @FromDate = DATEADD(MONTH, -1, GETDATE());
    IF @ToDate IS NULL SET @ToDate = GETDATE();

    SELECT LedgerId, TransactionDate, TransactionType, ReferenceNo,
           MaterialId, MaterialName, Color, HSNCode, Unit,
           LocationId, LocationName, QuantityIn, QuantityOut, NetQty
    FROM dbo.vw_StockReport
    WHERE (@LocationId IS NULL OR LocationId = @LocationId)
      AND TransactionDate BETWEEN @FromDate AND @ToDate
    ORDER BY TransactionDate DESC, LedgerId DESC;
END
GO

/* --- Dashboard stats --- */
CREATE OR ALTER PROCEDURE dbo.sp_GetDashboardStats
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM dbo.MaterialMaster WHERE IsActive = 1) AS TotalMaterials,
        (SELECT COUNT(*) FROM dbo.WarehouseLocation WHERE IsActive = 1) AS TotalLocations,
        (SELECT COUNT(*) FROM dbo.PurchaseInwardHeader) AS TotalPurchases,
        (SELECT COUNT(*) FROM dbo.SalesHeader) AS TotalSales,
        (SELECT ISNULL(SUM(CurrentStock), 0) FROM dbo.vw_StockSummary) AS TotalStockQty,
        (SELECT COUNT(*) FROM dbo.vw_MaterialStockByLocation WHERE StockStatus = N'Low Stock') AS LowStockItems;
END
GO

/* --- User Account --- */
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

PRINT 'InventoryInOneTap database setup completed successfully.';
PRINT 'Default login: admin / welcome123';
GO
