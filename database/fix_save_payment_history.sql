/* Align sp_SavePaymentHistory with the API (UserId + PaymentType).
   Fixes: Procedure or function sp_SavePaymentHistory has too many arguments specified.
   Run on SQL Server database PawanPutra. */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.PaymentHistory', 'UserId') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD UserId INT NULL;
IF COL_LENGTH('dbo.PaymentHistory', 'PaymentType') IS NULL
    ALTER TABLE dbo.PaymentHistory ADD PaymentType NVARCHAR(20) NULL;
GO

UPDATE dbo.PaymentHistory
SET PaymentType = ISNULL(PaymentType, N'Subscription')
WHERE PaymentType IS NULL;
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

PRINT N'sp_SavePaymentHistory updated (UserId, PaymentType).';
GO
