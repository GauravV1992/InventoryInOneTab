/* Add Rate column to OpeningStock + update procs */
USE PawanPutra;
GO

IF COL_LENGTH('dbo.OpeningStock', 'Rate') IS NULL
    ALTER TABLE dbo.OpeningStock ADD Rate DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_OpeningStock_Rate DEFAULT 0;
GO

/* Backfill from Material Master where rate is still 0 */
UPDATE os
SET Rate = m.Rate
FROM dbo.OpeningStock os
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId
WHERE ISNULL(os.Rate, 0) = 0 AND ISNULL(m.Rate, 0) > 0;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetOpeningStock
    @CompanyId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        os.OpeningStockId,
        os.MaterialId,
        m.MaterialName,
        m.Color,
        m.HSNCode,
        m.Unit,
        os.LocationId,
        l.LocationName,
        os.Quantity,
        os.Rate,
        CAST(os.Quantity * os.Rate AS DECIMAL(18,2)) AS Amount,
        os.StockDate,
        os.Remark,
        os.CreatedAt
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
            -- Upsert by company + material + location
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

PRINT N'OpeningStock.Rate column and procedures updated.';
GO
