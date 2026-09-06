/* Standard plan — 300 materials */
USE PawanPutra;
GO

UPDATE dbo.CompanyMaster
SET MaxMaterials = 300
WHERE LOWER(ISNULL(PlanType, N'')) = N'standard';
GO

PRINT 'Standard plan MaxMaterials set to 300.';
GO
