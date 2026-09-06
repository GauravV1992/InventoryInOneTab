/* ============================================================
   PawanPutra - Prevent delete when stock is used or present
   Run this script manually in SSMS on PawanPutra database
   ============================================================ */
USE PawanPutra;
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
        SELECT 1
        FROM dbo.StockLedger
        WHERE MaterialId = @MaterialId
        GROUP BY MaterialId
        HAVING ISNULL(SUM(QuantityIn - QuantityOut), 0) > 0
    )
    BEGIN
        RAISERROR(N'Cannot delete: Material still has stock present.', 16, 1);
        RETURN;
    END

    UPDATE dbo.MaterialMaster
    SET IsActive = 0, UpdatedAt = SYSUTCDATETIME()
    WHERE MaterialId = @MaterialId;
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
        SELECT 1
        FROM dbo.StockLedger
        WHERE LocationId = @LocationId
        GROUP BY LocationId
        HAVING ISNULL(SUM(QuantityIn - QuantityOut), 0) > 0
    )
    BEGIN
        RAISERROR(N'Cannot delete: Warehouse still has stock present.', 16, 1);
        RETURN;
    END

    UPDATE dbo.WarehouseLocation
    SET IsActive = 0
    WHERE LocationId = @LocationId;
END
GO

PRINT 'Delete protection for Material and Warehouse applied.';
GO
