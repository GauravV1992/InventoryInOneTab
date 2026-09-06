/* ============================================================
   Material Master seed — from handwritten challans (Hanuman Motors)
   Dates: 31/8/26, 11/8/26
   Run in SSMS on database: PawanPutra
   ============================================================ */
USE PawanPutra;
GO

/* >>> SET YOUR COMPANY ID HERE <<< */
DECLARE @CompanyId INT = 10;
-- Or pick first company:
-- DECLARE @CompanyId INT = (SELECT TOP 1 CompanyId FROM dbo.CompanyMaster WHERE IsActive = 1 ORDER BY CompanyId);

IF @CompanyId IS NULL
BEGIN
    RAISERROR(N'No company found. Set @CompanyId manually.', 16, 1);
    RETURN;
END

PRINT N'Seeding materials for CompanyId = ' + CAST(@CompanyId AS NVARCHAR(20));

/* Helper: insert only if same company + name does not already exist */
;WITH Materials AS (
    SELECT * FROM (VALUES
        /* ----- Challan 1: Helmets (31/8/26) ----- */
        (N'Helmet SB Vintage 5.0',           NULL, NULL, CAST(1799 AS DECIMAL(18,2)), N'Pcs', N'Challan 31/8/26'),
        (N'Helmet VEGA LARK (D)',            NULL, NULL, 1484.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB SBA-11 LED',            NULL, NULL, 2299.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB SBA-20 (D)',            NULL, NULL, 2249.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB R2K S/V',               NULL, NULL, 1349.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB 999',                   NULL, NULL,  999.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB SXE (D)',               NULL, NULL, 3599.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB Fighter',               NULL, NULL, 2999.00, N'Pcs', N'Challan 31/8/26'),
        (N'Helmet SB Fighter-120',           NULL, NULL, 3999.00, N'Pcs', N'Challan 31/8/26'),

        /* ----- Delivery Challan: Helmets ----- */
        (N'Helmet Avant S-3 Vintage 5.0',    NULL, NULL, 1079.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet VOGA LARK (D)',            NULL, NULL, 1068.50, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SB SBA-11 LED DC',         NULL, NULL, 2219.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SBA-20 (D)',               NULL, NULL, 2249.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet P2K S/V',                  NULL, NULL, 1349.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet 999',                      NULL, NULL,  999.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SKE (D)',                  NULL, NULL, 2379.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet Firker',                   NULL, NULL, 4319.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet Fly Star (D)',             NULL, NULL, 3099.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SB SBA-1 (D)',             NULL, NULL, 2879.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet Avatar Star (D)',          NULL, NULL, 1860.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet Mini',                     NULL, NULL,  687.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SB SBA-7 (D)',             NULL, NULL, 1403.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet Avatar Targa',             N'Black', NULL, 1649.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SB SBA-20 (P)',            NULL, NULL, 1511.00, N'Pcs', N'Delivery Challan Hanuman Motors'),
        (N'Helmet SB A-11 (P)',              NULL, NULL, 1418.00, N'Pcs', N'Delivery Challan Hanuman Motors'),

        /* ----- Challan 2: Hunk SB ----- */
        (N'Hunk SB Finix (P)',               NULL, NULL,  974.00, N'Pcs', N'Challan Hunk SB'),
        (N'Hunk SB SHARP (P)',               NULL, NULL, 1199.00, N'Pcs', N'Challan Hunk SB'),
        (N'Hunk SB Aria S.N',                NULL, NULL, 1655.00, N'Pcs', N'Challan Hunk SB'),
        (N'Hunk SB St Tera (D)',             NULL, NULL, 2155.00, N'Pcs', N'Challan Hunk SB'),
        (N'Hunk SB Rohn II',                 NULL, NULL, 1537.00, N'Pcs', N'Challan Hunk SB'),

        /* ----- List: Accessories 11/8/26 Hanuman Motors Bhiwandi ----- */
        (N'Mobile Holder (BS)',              NULL, NULL,  550.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Small Leather Bag',               NULL, NULL,  300.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Pedal Bag 2 Jodi',                NULL, NULL, 1800.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Mobile Cover Meter',              NULL, NULL,  180.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'New Bungee Cord',                 NULL, NULL,   50.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Splendor Eng Plate',              NULL, NULL,   60.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Light Rod',                       NULL, NULL,  750.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Activa 6G 7D Matting',            NULL, NULL,  130.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Rayman 7D Matting',               NULL, NULL,  130.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Access 7D Matting',               NULL, NULL,  130.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Passion Hook',                    NULL, NULL,   40.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'PU Guddi',                        NULL, NULL,  700.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Bagman Belt',                     NULL, NULL,  700.00, N'Pcs', N'List 11/8/26 Hanuman Motors'),
        (N'Leather Big Bag',                 NULL, NULL,  800.00, N'Pcs', N'List 11/8/26 Hanuman Motors')
    ) AS v(MaterialName, Color, HSNCode, Rate, Unit, Remark)
)
INSERT INTO dbo.MaterialMaster (CompanyId, MaterialName, Color, HSNCode, Rate, Unit, Remark, IsActive)
SELECT
    @CompanyId,
    m.MaterialName,
    m.Color,
    m.HSNCode,
    m.Rate,
    m.Unit,
    m.Remark,
    1
FROM Materials m
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.MaterialMaster x
    WHERE x.CompanyId = @CompanyId
      AND x.IsActive = 1
      AND LOWER(LTRIM(RTRIM(x.MaterialName))) = LOWER(LTRIM(RTRIM(m.MaterialName)))
);

PRINT N'Inserted materials: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));
PRINT N'Done. Check Material Master in the app.';
GO
