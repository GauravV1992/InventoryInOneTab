/* Run this script on existing PawanPutra database to add Supplier Master */
USE PawanPutra;
GO

IF OBJECT_ID('dbo.SupplierMaster', 'U') IS NULL
BEGIN
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
END
GO

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

PRINT 'Supplier Master setup completed.';
GO
