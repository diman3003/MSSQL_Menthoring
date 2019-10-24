USE Northwind

-------------------------------------------
--6.1
--
--------------------------------------------
IF OBJECT_ID('[dbo].[Accounts]', 'U') IS NOT NULL DROP TABLE [dbo].[Accounts]
GO
CREATE TABLE dbo.Accounts(
	[CounterpartyId] int IDENTITY(1 , 1) PRIMARY KEY
	,[Name] nvarchar(255) NOT NULL
	,[IsActive] bit NOT NULL
	)
GO

INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES ('Иванов', 1)
INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES ('Петров', 0)
INSERT INTO dbo.Accounts ([Name], [IsActive]) VALUES ('Сидоров', 1)
GO

IF OBJECT_ID('[dbo].[Transactions]', 'U') IS NOT NULL DROP TABLE [dbo].[Transactions]
GO
CREATE TABLE dbo.Transactions(
	[TransID] int IDENTITY(1 , 1) PRIMARY KEY
	,[TransDate] datetime NOT NULL
	,[RcvID] int NOT NULL
	,[SndID] int NOT NULL
	,[AssetID] int NOT NULL
	,[Quantity] numeric(19, 8) NOT NULL
	)
GO

INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('01.01.2012', 1, 2, 1, 100)
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('02.01.2012', 1, 3, 2, 150)
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('01.01.2012', 3, 1, 1, 300)
INSERT INTO dbo.Transactions ([TransDate], [RcvID], [SndID], [AssetID], [Quantity]) VALUES ('01.01.2012', 2, 1, 3, 50)
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

SELECT CounterpartyId, Name, COUNT(CounterpartyId) as Cnt
FROM ActveTransactions
WHERE IsActive = 1
GROUP BY CounterpartyId, Name
HAVING COUNT(CounterpartyId) > 1

-------------------------------------------------------------------------------------------------------------------
-- 6.1.2 Посчитать суммарное число актива, образовавшееся на активных счетах, в результате проведенных проводок.
-- Выводимые поля: CounterpartyID, Name, AssetID, Quantity 
-------------------------------------------------------------------------------------------------------------------

;WITH ActveTransactions AS(
	SELECT a.CounterpartyId, t.AssetID, t.Quantity 
	FROM Accounts a 
	INNER JOIN Transactions t ON a.CounterpartyId = t.RcvID
	WHERE a.IsActive = 1)

SELECT CounterpartyId, AssetID, SUM(Quantity) as Quantity
FROM ActveTransactions
GROUP BY AssetID, CounterpartyId
