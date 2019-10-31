USE Northwind

------
--6.1
------
IF OBJECT_ID(N'[dbo].[Accounts]', N'U') IS NOT NULL DROP TABLE [dbo].[Accounts];
GO
CREATE TABLE dbo.Accounts(
	[CounterpartyId] int IDENTITY(1 , 1) PRIMARY KEY
	,[Name] nvarchar(255) NOT NULL
	,[IsActive] bit NOT NULL
	);
GO

INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES (N'Иванов', 1);
INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES (N'Петров', 0);
INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES (N'Сидоров', 1);
GO

IF OBJECT_ID(N'[dbo].[Transactions]', N'U') IS NOT NULL DROP TABLE [dbo].[Transactions];
GO
CREATE TABLE dbo.Transactions(
	[TransID] int IDENTITY(1 , 1) PRIMARY KEY
	,[TransDate] datetime NOT NULL
	,[RcvID] int NOT NULL
	,[SndID] int NOT NULL
	,[AssetID] int NOT NULL
	,[Quantity] numeric(19, 8) NOT NULL
	);
GO

INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('2012.01.01', 1, 2, 1, 100);
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('2012.01.02', 1, 3, 2, 150);
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('2012.01.03', 3, 1, 1, 300);
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('2012.01.04', 2, 1, 3, 50);
GO

------------------------------------------------------------------------------------------------------
-- 6.1.1 Отобрать активные счета по которым есть проводки как минимум по двум разным активам. 
-- Выводимые поля: CounterpartyID, Name, Cnt(количество уникальных активов по которым есть проводки)
------------------------------------------------------------------------------------------------------
;WITH ActveTransactions AS(
	SELECT DISTINCT t.AssetID, a.CounterpartyID, a.Name, a.IsActive
	FROM dbo.Accounts a
	INNER JOIN dbo.Transactions t 
	ON CounterpartyId = SndID
	UNION
	SELECT DISTINCT t.AssetID, a.CounterpartyID, a.Name, a.IsActive
	FROM dbo.Accounts a
	INNER JOIN dbo.Transactions t
	ON CounterpartyId = RcvID
)

SELECT CounterpartyId, Name, COUNT(CounterpartyId) AS Cnt
FROM ActveTransactions
WHERE IsActive = 1
GROUP BY CounterpartyId, Name
HAVING COUNT(CounterpartyId) > 1;
GO
-------------------------------------------------------------------------------------------------------------------
-- 6.1.2 Посчитать суммарное число актива, образовавшееся на активных счетах, в результате проведенных проводок.
-- Выводимые поля: CounterpartyID, Name, AssetID, Quantity 
-------------------------------------------------------------------------------------------------------------------
;WITH AllTransactions AS(
	SELECT a.CounterpartyId, a.Name, t.AssetID, CAST(SUM(t.Quantity) AS DECIMAL(10,2)) AS Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.RcvID
	WHERE a.IsActive = 1
	GROUP BY a.CounterpartyId, a.Name, t.AssetID
	UNION ALL
	SELECT a.CounterpartyId, a.Name, t.AssetID, CAST(SUM(-t.Quantity) AS DECIMAL(10,2)) AS Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.SndID
	WHERE a.IsActive = 1
	GROUP BY a.CounterpartyId, a.Name, t.AssetID
)

SELECT DISTINCT CounterpartyId, Name, AssetID, SUM(Quantity) OVER (PARTITION BY CounterpartyId, AssetID) AS Quantity
FROM  AllTransactions;
GO
---------------------------------------------------------------------------------------------------------------------
-- 6.1.3
-- Посчитать средний дневной оборот по всем счетам по всем проводкам считая что AssetID во всех проводках одинаковый.
-- Выводимые поля: CounterpartyID, Name, Oborot
---------------------------------------------------------------------------------------------------------------------
;WITH AllTransactions AS(
	SELECT YEAR(t.TransDate) AS Y, MONTH(t.TransDate) AS M, DAY(t.TransDate) AS D, a.CounterpartyId, a.Name, t.Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.RcvID
	UNION ALL
	SELECT YEAR(t.TransDate) AS Y, MONTH(t.TransDate) AS M, DAY(t.TransDate) AS D, a.CounterpartyId, a.Name, -t.Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.SndID
)

SELECT CounterpartyID, Name, CAST(AVG(Quantity) AS DECIMAL(10,2)) AS Oborot
FROM  AllTransactions
GROUP BY Y, M, D, CounterpartyID, Name;
GO
-------------------------
-- 6.2.4
-- Посчитать средний месячный оборот по всем счетам по всем проводкам считая что AssetID во всех проводках одинаковый.
-- Выводимые поля: CounterpartyID, Name, Oborot
----------------------------------------------------------------------------------------------------------------------
;WITH AllTransactions AS(
	SELECT YEAR(t.TransDate) AS Y, MONTH(t.TransDate) AS M, a.CounterpartyId, a.Name, t.Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.RcvID
	UNION ALL
	SELECT YEAR(t.TransDate) AS Y, MONTH(t.TransDate) AS M, a.CounterpartyId, a.Name, -t.Quantity
	FROM dbo.Accounts a 
	INNER JOIN dbo.Transactions t ON a.CounterpartyId = t.SndID
)

SELECT CounterpartyID, Name, CAST(AVG(Quantity) AS DECIMAL(10,2)) AS Oborot
FROM  AllTransactions
GROUP BY Y, M, CounterpartyID, Name;
GO

------
--6.2
------
IF OBJECT_ID(N'[dbo].[GetNameById]', N'FN') IS NOT NULL DROP FUNCTION [dbo].[GetNameById];
GO
CREATE FUNCTION GetNameById (@id AS int)
RETURNS nvarchar(50)
AS
BEGIN
	RETURN (SELECT CONCAT(FirstName, N' ', LastName) AS FIO 
			FROM dbo.Employees
			WHERE EmployeeID = @id)
END
GO

--------------------------------------------------------------------------------------------------------------------------------------------------------
-- 6.2.1 По таблице dbo.Employees для каждого руководителя найти подчиненных на всех уровнях иерархии подчинения (напряму и через других подчиненных).
-- Вывести руководителя, подчиненного, непосредственного руководителя и уровень подчинения. 
-- Для построения иерархии в таблице используются поля EmploeeID и ReportsTo. Необходимо использовать рекурсивыный CTE.
--------------------------------------------------------------------------------------------------------------------------------------------------------
;WITH Reports
AS
(
	SELECT EmployeeID, ReportsTo, ReportsTo AS r1, 1 AS Level
	FROM dbo.Employees e
	UNION ALL
	SELECT r.EmployeeID, e.ReportsTo, r.ReportsTo, r.Level+1 AS Level
	FROM Reports r INNER JOIN Employees e ON e.EmployeeID = r.ReportsTo
)

SELECT dbo.GetnameById(ReportsTo) AS N'Руководитель'
		,dbo.GetnameById(EmployeeId) AS N'Подчиненный'
		,Level AS N'Уровень'
		,dbo.GetnameById(r1) AS N'Непосредственный руководитель'
FROM Reports
WHERE ReportsTo IS NOT NULL AND r1 IS NOT NULL;
