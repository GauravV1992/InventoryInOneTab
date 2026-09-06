/* India Standard Time (IST = UTC+5:30) — use instead of GETDATE() on server */
USE PawanPutra;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaNow()
RETURNS DATETIME2
AS
BEGIN
  /* Fixed offset: India has no daylight saving */
  RETURN DATEADD(MINUTE, 330, SYSUTCDATETIME());
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetIndiaDate()
RETURNS DATE
AS
BEGIN
  RETURN CAST(DATEADD(MINUTE, 330, SYSUTCDATETIME()) AS DATE);
END
GO

CREATE OR ALTER FUNCTION dbo.fn_GetFinancialYearCode(@Date DATE)
RETURNS NVARCHAR(4)
AS
BEGIN
    IF @Date IS NULL SET @Date = dbo.fn_GetIndiaDate();

    DECLARE @Year INT = YEAR(@Date);
    DECLARE @StartYear INT = CASE WHEN MONTH(@Date) >= 4 THEN @Year ELSE @Year - 1 END;
    DECLARE @EndYear INT = @StartYear + 1;

    RETURN RIGHT(N'00' + CAST(@StartYear % 100 AS NVARCHAR(2)), 2)
         + RIGHT(N'00' + CAST(@EndYear % 100 AS NVARCHAR(2)), 2);
END
GO

PRINT 'India Standard Time functions created: fn_GetIndiaNow(), fn_GetIndiaDate(), fn_GetFinancialYearCode() updated.';
GO
