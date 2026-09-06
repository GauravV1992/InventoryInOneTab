/* Same as fix_purchase_sales_transaction.sql - run either file in SSMS */
USE PawanPutra;
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

CREATE OR ALTER PROCEDURE dbo.sp_SaveSales
    @SalesDate    DATE,
    @LocationId   INT,
    @CustomerName NVARCHAR(150) = NULL,
    @Remark       NVARCHAR(500) = NULL,
    @DetailsJson  NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @DetailsJson IS NULL OR LTRIM(RTRIM(@DetailsJson)) = N''
            THROW 50011, N'Sales details are required.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.WarehouseLocation WHERE LocationId = @LocationId AND IsActive = 1)
            THROW 50012, N'Invalid or inactive warehouse location.', 1;

        IF EXISTS (
            SELECT 1
            FROM OPENJSON(@DetailsJson)
            WITH (
                MaterialId INT '$.MaterialId', MaterialId2 INT '$.materialId',
                Quantity DECIMAL(18,3) '$.Quantity', Quantity2 DECIMAL(18,3) '$.quantity'
            ) j
            CROSS APPLY (
                SELECT ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0) AS Avail
                FROM dbo.StockLedger sl WITH (UPDLOCK, HOLDLOCK)
                WHERE sl.MaterialId = COALESCE(j.MaterialId, j.MaterialId2)
                  AND sl.LocationId = @LocationId
            ) s
            WHERE COALESCE(j.MaterialId, j.MaterialId2) IS NOT NULL
              AND COALESCE(j.Quantity, j.Quantity2) > 0
              AND COALESCE(j.Quantity, j.Quantity2) > s.Avail
        )
            THROW 50013, N'Insufficient stock for one or more items at selected location.', 1;

        DECLARE @SalesNo NVARCHAR(30);
        DECLARE @NextNo INT = ISNULL((SELECT MAX(SalesId) FROM dbo.SalesHeader WITH (UPDLOCK, HOLDLOCK)), 0) + 1;
        SET @SalesNo = N'SAL-' + FORMAT(GETDATE(), 'yyyyMM') + N'-' + RIGHT(N'0000' + CAST(@NextNo AS NVARCHAR(10)), 4);

        INSERT INTO dbo.SalesHeader (SalesNo, SalesDate, LocationId, CustomerName, Remark)
        VALUES (@SalesNo, @SalesDate, @LocationId, @CustomerName, @Remark);

        DECLARE @SalesId INT = SCOPE_IDENTITY();

        INSERT INTO dbo.SalesDetail (SalesId, MaterialId, Quantity, Rate)
        SELECT @SalesId,
               COALESCE(MaterialId, MaterialId2),
               COALESCE(Quantity, Quantity2),
               COALESCE(Rate, Rate2, 0)
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

        IF NOT EXISTS (SELECT 1 FROM dbo.SalesDetail WHERE SalesId = @SalesId)
            THROW 50014, N'No valid sales items found. Check material and quantity.', 1;

        INSERT INTO dbo.StockLedger (MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
        SELECT d.MaterialId, @LocationId, N'SALES', @SalesId, @SalesNo, @SalesDate, 0, d.Quantity
        FROM dbo.SalesDetail d
        WHERE d.SalesId = @SalesId;

        IF @@ROWCOUNT = 0
            THROW 50015, N'Stock ledger update failed for sales.', 1;

        COMMIT TRANSACTION;

        SELECT @SalesId AS SalesId, @SalesNo AS SalesNo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Purchase/Sales procedures updated with transaction support.';
GO
