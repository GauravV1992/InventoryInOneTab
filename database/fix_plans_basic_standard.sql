/*
  Sync CompanyMaster plan caps to Basic / Standard / Trial limits.
  Run on PawanPutra database (SSMS).

  Basic / Trial: 1 user, 10 warehouses, 200 materials
  Standard:      1 user, 20 warehouses, 400 materials
  Premium:       left unchanged (legacy subscribers)
*/

SET NOCOUNT ON;

UPDATE dbo.CompanyMaster
SET
  MaxUsers = 1,
  MaxWarehouses = 10,
  MaxMaterials = 200
WHERE LOWER(LTRIM(RTRIM(ISNULL(PlanType, N'')))) IN (N'basic', N'trial');

UPDATE dbo.CompanyMaster
SET
  MaxUsers = 1,
  MaxWarehouses = 20,
  MaxMaterials = 400
WHERE LOWER(LTRIM(RTRIM(ISNULL(PlanType, N'')))) = N'standard';

-- Optional: show counts after update
SELECT PlanType, COUNT(*) AS Companies, MAX(MaxUsers) AS MaxUsers, MAX(MaxWarehouses) AS MaxWarehouses, MAX(MaxMaterials) AS MaxMaterials
FROM dbo.CompanyMaster
GROUP BY PlanType
ORDER BY PlanType;
