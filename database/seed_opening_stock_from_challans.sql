/* ============================================================
   Opening Stock seed — qty + rate from handwritten challans
   Requires:
     1) fix_opening_stock_rate.sql  (adds Rate column)
     2) seed_materials_from_challans.sql
   Run in SSMS on: PawanPutra
   ============================================================ */
USE PawanPutra;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH('dbo.OpeningStock', 'Rate') IS NULL
BEGIN
    RAISERROR(N'Run fix_opening_stock_rate.sql first (adds Rate column).', 16, 1);
    RETURN;
END

/* >>> SET COMPANY / WAREHOUSE / DATE <<< */
DECLARE @CompanyId INT = 10;

DECLARE @LocationId INT = (
    SELECT TOP 1 LocationId
    FROM dbo.WarehouseLocation
    WHERE CompanyId = @CompanyId AND IsActive = 1
    ORDER BY CASE WHEN LocationName LIKE N'%Main%' THEN 0 ELSE 1 END, LocationId
);

DECLARE @StockDate DATE = '2026-08-31';

IF @CompanyId IS NULL
BEGIN RAISERROR(N'No company found. Set @CompanyId.', 16, 1); RETURN; END
IF @LocationId IS NULL
BEGIN RAISERROR(N'No warehouse found for this company. Set @LocationId.', 16, 1); RETURN; END

PRINT N'CompanyId=' + CAST(@CompanyId AS NVARCHAR(20))
    + N', LocationId=' + CAST(@LocationId AS NVARCHAR(20))
    + N', StockDate=' + CONVERT(NVARCHAR(10), @StockDate, 23);

DECLARE @Lines TABLE (
    MaterialName NVARCHAR(150) NOT NULL,
    Quantity     DECIMAL(18,3) NOT NULL,
    Rate         DECIMAL(18,2) NOT NULL,
    Remark       NVARCHAR(500) NULL
);

INSERT INTO @Lines (MaterialName, Quantity, Rate, Remark) VALUES
/* ----- Challan 1: Helmets 31/8/26 ----- */
(N'Helmet SB Vintage 5.0',        5, 1799.00, N'Challan 31/8/26'),
(N'Helmet VEGA LARK (D)',         4, 1484.00, N'Challan 31/8/26'),
(N'Helmet SB SBA-11 LED',         3, 2299.00, N'Challan 31/8/26'),
(N'Helmet SB SBA-20 (D)',         2, 2249.00, N'Challan 31/8/26'),
(N'Helmet SB R2K S/V',            2, 1349.00, N'Challan 31/8/26'),
(N'Helmet SB 999',                3,  999.00, N'Challan 31/8/26'),
(N'Helmet SB SXE (D)',            1, 3599.00, N'Challan 31/8/26'),
(N'Helmet SB Fighter',            2, 2999.00, N'Challan 31/8/26'),
(N'Helmet SB Fighter-120',        1, 3999.00, N'Challan 31/8/26'),

/* ----- Delivery Challan ----- */
(N'Helmet Avant S-3 Vintage 5.0', 6, 1079.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet VOGA LARK (D)',         4, 1068.50, N'Delivery Challan Hanuman Motors'),
(N'Helmet SB SBA-11 LED DC',      3, 2219.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SBA-20 (D)',            2, 2249.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet P2K S/V',               3, 1349.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet 999',                   2,  999.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SKE (D)',               1, 2379.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet Firker',                1, 4319.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet Fly Star (D)',          1, 3099.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SB SBA-1 (D)',          1, 2879.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet Avatar Star (D)',       3, 1860.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet Mini',                  4,  687.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SB SBA-7 (D)',          3, 1403.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet Avatar Targa',          1, 1649.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SB SBA-20 (P)',         2, 1511.00, N'Delivery Challan Hanuman Motors'),
(N'Helmet SB A-11 (P)',           1, 1418.00, N'Delivery Challan Hanuman Motors'),

/* ----- Hunk SB ----- */
(N'Hunk SB Finix (P)',            2,  974.00, N'Challan Hunk SB'),
(N'Hunk SB SHARP (P)',            2, 1199.00, N'Challan Hunk SB'),
(N'Hunk SB Aria S.N',             1, 1655.00, N'Challan Hunk SB'),
(N'Hunk SB St Tera (D)',          1, 2155.00, N'Challan Hunk SB'),
(N'Hunk SB Rohn II',              1, 1537.00, N'Challan Hunk SB'),

/* ----- Accessories 11/8/26 ----- */
(N'Mobile Holder (BS)',           3,  550.00, N'List 11/8/26 Hanuman Motors'),
(N'Small Leather Bag',            5,  300.00, N'List 11/8/26 Hanuman Motors'),
(N'Pedal Bag 2 Jodi',             2, 1800.00, N'List 11/8/26 Hanuman Motors'),
(N'Mobile Cover Meter',           5,  180.00, N'List 11/8/26 Hanuman Motors'),
(N'New Bungee Cord',             20,   50.00, N'List 11/8/26 Hanuman Motors'),
(N'Splendor Eng Plate',          10,   60.00, N'List 11/8/26 Hanuman Motors'),
(N'Light Rod',                    2,  750.00, N'List 11/8/26 Hanuman Motors'),
(N'Activa 6G 7D Matting',         5,  130.00, N'List 11/8/26 Hanuman Motors'),
(N'Rayman 7D Matting',            5,  130.00, N'List 11/8/26 Hanuman Motors'),
(N'Access 7D Matting',            5,  130.00, N'List 11/8/26 Hanuman Motors'),
(N'Passion Hook',                10,   40.00, N'List 11/8/26 Hanuman Motors'),
(N'PU Guddi',                     5,  700.00, N'List 11/8/26 Hanuman Motors'),
(N'Bagman Belt',                  2,  700.00, N'List 11/8/26 Hanuman Motors'),
(N'Leather Big Bag',              2,  800.00, N'List 11/8/26 Hanuman Motors');

SELECT l.MaterialName, l.Quantity, l.Rate, N'MISSING in MaterialMaster' AS Status
FROM @Lines l
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.MaterialMaster m
    WHERE m.CompanyId = @CompanyId AND m.IsActive = 1
      AND LOWER(LTRIM(RTRIM(m.MaterialName))) = LOWER(LTRIM(RTRIM(l.MaterialName)))
);

DECLARE @Inserted INT = 0, @Updated INT = 0, @Skipped INT = 0;
DECLARE @MaterialName NVARCHAR(150), @Qty DECIMAL(18,3), @Rate DECIMAL(18,2), @Remark NVARCHAR(500);
DECLARE @MaterialId INT, @OpeningStockId INT;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT MaterialName, Quantity, Rate, Remark FROM @Lines;

OPEN c;
FETCH NEXT FROM c INTO @MaterialName, @Qty, @Rate, @Remark;

BEGIN TRY
    BEGIN TRANSACTION;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT TOP 1 @MaterialId = MaterialId
        FROM dbo.MaterialMaster
        WHERE CompanyId = @CompanyId AND IsActive = 1
          AND LOWER(LTRIM(RTRIM(MaterialName))) = LOWER(LTRIM(RTRIM(@MaterialName)));

        IF @MaterialId IS NULL
        BEGIN
            SET @Skipped += 1;
            PRINT N'SKIP (material not found): ' + @MaterialName;
        END
        ELSE
        BEGIN
            SELECT @OpeningStockId = OpeningStockId
            FROM dbo.OpeningStock
            WHERE CompanyId = @CompanyId AND MaterialId = @MaterialId AND LocationId = @LocationId;

            IF @OpeningStockId IS NULL
            BEGIN
                INSERT INTO dbo.OpeningStock (CompanyId, MaterialId, LocationId, Quantity, Rate, StockDate, Remark)
                VALUES (@CompanyId, @MaterialId, @LocationId, @Qty, @Rate, @StockDate, @Remark);
                SET @OpeningStockId = SCOPE_IDENTITY();

                INSERT INTO dbo.StockLedger
                    (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
                VALUES
                    (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId,
                     N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Qty, 0);

                IF OBJECT_ID('dbo.sp_FifoAddOrReplaceBatch', 'P') IS NOT NULL
                    EXEC dbo.sp_FifoAddOrReplaceBatch
                        @CompanyId = @CompanyId,
                        @MaterialId = @MaterialId,
                        @LocationId = @LocationId,
                        @SourceType = N'OPENING',
                        @SourceId = @OpeningStockId,
                        @TransactionDate = @StockDate,
                        @QuantityIn = @Qty,
                        @Rate = @Rate;

                SET @Inserted += 1;
            END
            ELSE
            BEGIN
                UPDATE dbo.OpeningStock
                SET Quantity = @Qty, Rate = @Rate, StockDate = @StockDate, Remark = @Remark
                WHERE OpeningStockId = @OpeningStockId AND CompanyId = @CompanyId;

                DELETE FROM dbo.StockLedger
                WHERE TransactionType = N'OPENING' AND ReferenceId = @OpeningStockId AND CompanyId = @CompanyId;

                INSERT INTO dbo.StockLedger
                    (CompanyId, MaterialId, LocationId, TransactionType, ReferenceId, ReferenceNo, TransactionDate, QuantityIn, QuantityOut)
                VALUES
                    (@CompanyId, @MaterialId, @LocationId, N'OPENING', @OpeningStockId,
                     N'OPN-' + CAST(@OpeningStockId AS NVARCHAR(20)), @StockDate, @Qty, 0);

                IF OBJECT_ID('dbo.sp_FifoAddOrReplaceBatch', 'P') IS NOT NULL
                    EXEC dbo.sp_FifoAddOrReplaceBatch
                        @CompanyId = @CompanyId,
                        @MaterialId = @MaterialId,
                        @LocationId = @LocationId,
                        @SourceType = N'OPENING',
                        @SourceId = @OpeningStockId,
                        @TransactionDate = @StockDate,
                        @QuantityIn = @Qty,
                        @Rate = @Rate;

                SET @Updated += 1;
            END
        END

        SET @MaterialId = NULL;
        SET @OpeningStockId = NULL;
        FETCH NEXT FROM c INTO @MaterialName, @Qty, @Rate, @Remark;
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    CLOSE c; DEALLOCATE c;
    THROW;
END CATCH

CLOSE c;
DEALLOCATE c;

PRINT N'Opening stock done. Inserted=' + CAST(@Inserted AS NVARCHAR(10))
    + N', Updated=' + CAST(@Updated AS NVARCHAR(10))
    + N', Skipped=' + CAST(@Skipped AS NVARCHAR(10));

SELECT
    m.MaterialName,
    l.LocationName,
    os.Quantity,
    os.Rate,
    CAST(os.Quantity * os.Rate AS DECIMAL(18,2)) AS Amount,
    os.StockDate,
    os.Remark
FROM dbo.OpeningStock os
INNER JOIN dbo.MaterialMaster m ON m.MaterialId = os.MaterialId
INNER JOIN dbo.WarehouseLocation l ON l.LocationId = os.LocationId
WHERE os.CompanyId = @CompanyId
  AND (
        os.Remark LIKE N'%Challan%'
     OR os.Remark LIKE N'%Hanuman%'
     OR os.Remark LIKE N'%Hunk%'
     OR os.Remark LIKE N'%List 11%'
  )
ORDER BY m.MaterialName;
GO
