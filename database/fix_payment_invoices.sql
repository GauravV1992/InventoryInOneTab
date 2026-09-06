/* Payment invoice history for My Account — self-contained */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.PaymentHistory', 'UserId') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD UserId INT NULL;
IF COL_LENGTH('dbo.PaymentHistory', 'PaymentType') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD PaymentType NVARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.CompanyMaster', 'MaxWarehouses') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD MaxWarehouses INT NULL;
IF COL_LENGTH('dbo.CompanyMaster', 'MaxMaterials') IS NULL
    ALTER TABLE dbo.CompanyMaster ADD MaxMaterials INT NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetCompanyPaymentHistory
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ph.PaymentHistoryId,
        ph.CompanyId,
        ph.PlanType,
        ph.BillingCycle,
        ph.AmountPaise,
        ph.RazorpayOrderId,
        ph.RazorpayPaymentId,
        ph.PaymentStatus,
        ph.PaymentType,
        ph.UserId,
        ph.CreatedAt,
        u.Username AS UserUsername,
        u.FullName AS UserFullName
    FROM dbo.PaymentHistory ph
    LEFT JOIN dbo.Users u ON u.UserId = ph.UserId
    WHERE ph.CompanyId = @CompanyId
      AND ph.PaymentStatus = N'Paid'
    ORDER BY ph.CreatedAt DESC;
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

PRINT 'Payment invoice history procedure ready.';
GO
