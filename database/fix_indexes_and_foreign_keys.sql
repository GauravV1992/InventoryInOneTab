/* Non-clustered indexes + foreign keys — run after fix_multi_company.sql */
USE PawanPutra;
GO

SET NOCOUNT ON;
GO

/* ===================== ORPHAN CHECK (FK pre-requisites) ===================== */

IF OBJECT_ID('dbo.PaymentHistory', 'U') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1 FROM dbo.PaymentHistory ph
        LEFT JOIN dbo.Users u ON u.UserId = ph.UserId
        WHERE ph.UserId IS NOT NULL AND u.UserId IS NULL
    )
    BEGIN
        UPDATE ph SET UserId = NULL
        FROM dbo.PaymentHistory ph
        LEFT JOIN dbo.Users u ON u.UserId = ph.UserId
        WHERE ph.UserId IS NOT NULL AND u.UserId IS NULL;
        PRINT N'PaymentHistory: cleared invalid UserId references.';
    END
END
GO

/* ===================== FOREIGN KEYS ===================== */

IF OBJECT_ID('dbo.PaymentHistory', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.PaymentHistory', 'UserId') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PaymentHistory_User')
    ALTER TABLE dbo.PaymentHistory
        ADD CONSTRAINT FK_PaymentHistory_User
        FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId) ON DELETE SET NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInward_Location')
AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInwardHeader_Location')
    ALTER TABLE dbo.PurchaseInwardHeader
        ADD CONSTRAINT FK_PurchaseInwardHeader_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Sales_Location')
AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SalesHeader_Location')
    ALTER TABLE dbo.SalesHeader
        ADD CONSTRAINT FK_SalesHeader_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OpeningStock_Material')
    ALTER TABLE dbo.OpeningStock
        ADD CONSTRAINT FK_OpeningStock_Material
        FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_OpeningStock_Location')
    ALTER TABLE dbo.OpeningStock
        ADD CONSTRAINT FK_OpeningStock_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseDetail_Header')
AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInwardDetail_Header')
    ALTER TABLE dbo.PurchaseInwardDetail
        ADD CONSTRAINT FK_PurchaseInwardDetail_Header
        FOREIGN KEY (PurchaseId) REFERENCES dbo.PurchaseInwardHeader(PurchaseId) ON DELETE CASCADE;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseDetail_Material')
AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_PurchaseInwardDetail_Material')
    ALTER TABLE dbo.PurchaseInwardDetail
        ADD CONSTRAINT FK_PurchaseInwardDetail_Material
        FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SalesDetail_Header')
    ALTER TABLE dbo.SalesDetail
        ADD CONSTRAINT FK_SalesDetail_Header
        FOREIGN KEY (SalesId) REFERENCES dbo.SalesHeader(SalesId) ON DELETE CASCADE;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SalesDetail_Material')
    ALTER TABLE dbo.SalesDetail
        ADD CONSTRAINT FK_SalesDetail_Material
        FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SalesDetail_Location')
    ALTER TABLE dbo.SalesDetail
        ADD CONSTRAINT FK_SalesDetail_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StockLedger_Material')
    ALTER TABLE dbo.StockLedger
        ADD CONSTRAINT FK_StockLedger_Material
        FOREIGN KEY (MaterialId) REFERENCES dbo.MaterialMaster(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_StockLedger_Location')
    ALTER TABLE dbo.StockLedger
        ADD CONSTRAINT FK_StockLedger_Location
        FOREIGN KEY (LocationId) REFERENCES dbo.WarehouseLocation(LocationId);
GO

/* ===================== NON-CLUSTERED INDEXES ===================== */

/* Users — company membership & active-user counts */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Users_CompanyId' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE NONCLUSTERED INDEX IX_Users_CompanyId ON dbo.Users(CompanyId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Users_CompanyId_IsActive' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE NONCLUSTERED INDEX IX_Users_CompanyId_IsActive ON dbo.Users(CompanyId, IsActive);
GO

/* WarehouseLocation — list by company */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_WarehouseLocation_CompanyId_IsActive' AND object_id = OBJECT_ID('dbo.WarehouseLocation'))
    CREATE NONCLUSTERED INDEX IX_WarehouseLocation_CompanyId_IsActive ON dbo.WarehouseLocation(CompanyId, IsActive)
        INCLUDE (LocationName, Address, City);
GO

/* MaterialMaster — list & plan limits */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_MaterialMaster_CompanyId_IsActive' AND object_id = OBJECT_ID('dbo.MaterialMaster'))
    CREATE NONCLUSTERED INDEX IX_MaterialMaster_CompanyId_IsActive ON dbo.MaterialMaster(CompanyId, IsActive)
        INCLUDE (MaterialName, Rate, Unit);
GO

/* SupplierMaster — list by company */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SupplierMaster_CompanyId_IsActive' AND object_id = OBJECT_ID('dbo.SupplierMaster'))
    CREATE NONCLUSTERED INDEX IX_SupplierMaster_CompanyId_IsActive ON dbo.SupplierMaster(CompanyId, IsActive)
        INCLUDE (SupplierName, GSTNo, MobileNo);
GO

/* OpeningStock — FK lookups & company listing */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OpeningStock_CompanyId' AND object_id = OBJECT_ID('dbo.OpeningStock'))
    CREATE NONCLUSTERED INDEX IX_OpeningStock_CompanyId ON dbo.OpeningStock(CompanyId)
        INCLUDE (MaterialId, LocationId, Quantity, StockDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OpeningStock_MaterialId' AND object_id = OBJECT_ID('dbo.OpeningStock'))
    CREATE NONCLUSTERED INDEX IX_OpeningStock_MaterialId ON dbo.OpeningStock(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OpeningStock_LocationId' AND object_id = OBJECT_ID('dbo.OpeningStock'))
    CREATE NONCLUSTERED INDEX IX_OpeningStock_LocationId ON dbo.OpeningStock(LocationId);
GO

/* PurchaseInwardHeader — list by date, FK on location */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PurchaseInwardHeader_CompanyId_PurchaseDate' AND object_id = OBJECT_ID('dbo.PurchaseInwardHeader'))
    CREATE NONCLUSTERED INDEX IX_PurchaseInwardHeader_CompanyId_PurchaseDate
        ON dbo.PurchaseInwardHeader(CompanyId, PurchaseDate DESC, PurchaseId DESC)
        INCLUDE (PurchaseNo, LocationId, SupplierName);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PurchaseInwardHeader_LocationId' AND object_id = OBJECT_ID('dbo.PurchaseInwardHeader'))
    CREATE NONCLUSTERED INDEX IX_PurchaseInwardHeader_LocationId ON dbo.PurchaseInwardHeader(LocationId);
GO

/* PurchaseInwardDetail — joins & delete-protection checks */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PurchaseInwardDetail_PurchaseId' AND object_id = OBJECT_ID('dbo.PurchaseInwardDetail'))
    CREATE NONCLUSTERED INDEX IX_PurchaseInwardDetail_PurchaseId ON dbo.PurchaseInwardDetail(PurchaseId)
        INCLUDE (MaterialId, Quantity, Rate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PurchaseInwardDetail_MaterialId' AND object_id = OBJECT_ID('dbo.PurchaseInwardDetail'))
    CREATE NONCLUSTERED INDEX IX_PurchaseInwardDetail_MaterialId ON dbo.PurchaseInwardDetail(MaterialId);
GO

/* SalesHeader — list by date, FK on location */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesHeader_CompanyId_SalesDate' AND object_id = OBJECT_ID('dbo.SalesHeader'))
    CREATE NONCLUSTERED INDEX IX_SalesHeader_CompanyId_SalesDate
        ON dbo.SalesHeader(CompanyId, SalesDate DESC, SalesId DESC)
        INCLUDE (SalesNo, LocationId, CustomerName);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesHeader_LocationId' AND object_id = OBJECT_ID('dbo.SalesHeader'))
    CREATE NONCLUSTERED INDEX IX_SalesHeader_LocationId ON dbo.SalesHeader(LocationId);
GO

/* SalesDetail — joins & stock validation */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesDetail_SalesId' AND object_id = OBJECT_ID('dbo.SalesDetail'))
    CREATE NONCLUSTERED INDEX IX_SalesDetail_SalesId ON dbo.SalesDetail(SalesId)
        INCLUDE (MaterialId, LocationId, Quantity, Rate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesDetail_MaterialId' AND object_id = OBJECT_ID('dbo.SalesDetail'))
    CREATE NONCLUSTERED INDEX IX_SalesDetail_MaterialId ON dbo.SalesDetail(MaterialId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesDetail_LocationId' AND object_id = OBJECT_ID('dbo.SalesDetail'))
    CREATE NONCLUSTERED INDEX IX_SalesDetail_LocationId ON dbo.SalesDetail(LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_SalesDetail_MaterialId_LocationId' AND object_id = OBJECT_ID('dbo.SalesDetail'))
    CREATE NONCLUSTERED INDEX IX_SalesDetail_MaterialId_LocationId ON dbo.SalesDetail(MaterialId, LocationId);
GO

/* StockLedger — availability, reports, ledger deletes */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockLedger_CompanyMaterialLocation' AND object_id = OBJECT_ID('dbo.StockLedger'))
    CREATE NONCLUSTERED INDEX IX_StockLedger_CompanyMaterialLocation
        ON dbo.StockLedger(CompanyId, MaterialId, LocationId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockLedger_CompanyId_TransactionDate' AND object_id = OBJECT_ID('dbo.StockLedger'))
    CREATE NONCLUSTERED INDEX IX_StockLedger_CompanyId_TransactionDate
        ON dbo.StockLedger(CompanyId, TransactionDate DESC, LedgerId DESC)
        INCLUDE (TransactionType, ReferenceNo, MaterialId, LocationId, QuantityIn, QuantityOut);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockLedger_Company_Type_Reference' AND object_id = OBJECT_ID('dbo.StockLedger'))
    CREATE NONCLUSTERED INDEX IX_StockLedger_Company_Type_Reference
        ON dbo.StockLedger(CompanyId, TransactionType, ReferenceId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StockLedger_MaterialId_LocationId' AND object_id = OBJECT_ID('dbo.StockLedger'))
    CREATE NONCLUSTERED INDEX IX_StockLedger_MaterialId_LocationId ON dbo.StockLedger(MaterialId, LocationId);
GO

/* PaymentHistory — subscription invoices */
IF OBJECT_ID('dbo.PaymentHistory', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PaymentHistory_CompanyId_CreatedAt' AND object_id = OBJECT_ID('dbo.PaymentHistory'))
    CREATE NONCLUSTERED INDEX IX_PaymentHistory_CompanyId_CreatedAt
        ON dbo.PaymentHistory(CompanyId, CreatedAt DESC)
        INCLUDE (PlanType, BillingCycle, AmountPaise, PaymentStatus);
GO

IF OBJECT_ID('dbo.PaymentHistory', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.PaymentHistory', 'UserId') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PaymentHistory_UserId' AND object_id = OBJECT_ID('dbo.PaymentHistory'))
    CREATE NONCLUSTERED INDEX IX_PaymentHistory_UserId ON dbo.PaymentHistory(UserId)
        WHERE UserId IS NOT NULL;
GO

/* CompanyMaster — subscription expiry checks (after fix_subscription_users.sql) */
IF COL_LENGTH('dbo.CompanyMaster', 'SubscriptionStatus') IS NOT NULL
   AND COL_LENGTH('dbo.CompanyMaster', 'SubscriptionEnd') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CompanyMaster_SubscriptionStatus_End' AND object_id = OBJECT_ID('dbo.CompanyMaster'))
    CREATE NONCLUSTERED INDEX IX_CompanyMaster_SubscriptionStatus_End
        ON dbo.CompanyMaster(SubscriptionStatus, SubscriptionEnd)
        INCLUDE (CompanyId, PlanType);
GO

PRINT N'Indexes and foreign keys applied successfully.';
GO
