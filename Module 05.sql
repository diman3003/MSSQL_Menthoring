USE [Northwind]
GO

-------------------------------------------------
--[dbo].[GreatestOrders]
-------------------------------------------------
IF OBJECT_ID('[dbo].[GreatestOrders]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[GreatestOrders]
GO
CREATE PROCEDURE [dbo].[GreatestOrders] @year INT, @top INT
AS

SELECT TOP (@top) CONCAT(e.LastName, ' ', e.Firstname) as Employee, ag.OrderID, CAST(ag.[Order Price] AS DECIMAL(10,2)) AS [Order Price]
FROM dbo.Employees e
INNER JOIN Orders o ON e.EmployeeID = o.EmployeeID
INNER JOIN (SELECT o.OrderID, o.EmployeeID, SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) AS [Order Price]
			, ROW_NUMBER() OVER (PARTITION BY o.EmployeeId ORDER BY SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) DESC) AS N
			FROM dbo.Orders o
			INNER JOIN dbo.[Order Details] od ON o.OrderID = od.OrderID
			WHERE  YEAR(o.OrderDate) = @year
			GROUP BY o.OrderID, o.EmployeeID) ag ON o.OrderID = ag.OrderID
WHERE ag.N = 1
ORDER BY [Order Price] DESC
GO

-------------------------------------------------
--[dbo].[GreatestOrdersCur]
-------------------------------------------------
IF OBJECT_ID('[dbo].[GreatestOrdersCur]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[GreatestOrdersCur]
GO
CREATE PROCEDURE [dbo].[GreatestOrdersCur] @year int, @top int
AS

DECLARE @employee nvarchar(50)
DECLARE @id int
DECLARE @mFright decimal(10,2)
DECLARE cur CURSOR
FOR

SELECT CONCAT(e.LastName, ' ', e.Firstname) as Employee, ag.OrderID, CAST(ag.[Order Price] AS DECIMAL(10,2)) AS [Order Price]
FROM Employees e
INNER JOIN Orders o ON e.EmployeeID = o.EmployeeID
INNER JOIN (SELECT o.OrderID, o.EmployeeID, SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) AS [Order Price]
			, ROW_NUMBER() OVER (PARTITION BY o.EmployeeId ORDER BY SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) DESC) AS N
			FROM Orders o
			INNER JOIN [Order Details] od ON o.OrderID = od.OrderID
			WHERE  YEAR(o.OrderDate) = @year
			GROUP BY o.OrderID, o.EmployeeID) ag ON o.OrderID = ag.OrderID
WHERE ag.N = 1
ORDER BY [Order Price] DESC

OPEN cur

WHILE @top > 0
BEGIN
	FETCH NEXT FROM cur Into @employee, @id, @mFright
	SELECT @employee as Employee, @id as [Order], @mFright as [Order Price]
	Set @top = @top - 1
END

Close cur
Deallocate cur
GO


-------------------------------------------------
--[dbo].[ShippedOrdersDiff]
-------------------------------------------------
IF OBJECT_ID('[dbo].[ShippedOrdersDiff]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[ShippedOrdersDiff]
GO
CREATE PROCEDURE [dbo].[ShippedOrdersDiff] @days int
AS

IF (ISNULL(@days, '') = '')
	Set @days = 35

SELECT  OrderID, OrderDate, ShippedDate, Datediff(Day, OrderDate, ShippedDate) as ShippedDelay, @days as SpecifiedDelay 
FROM Orders
WHERE ShippedDate - OrderDate > @days Or ShippedDate is Null
GO


--------------------
--IsBoss
--------------------
IF OBJECT_ID('[dbo].[IsBoss]', 'FN') IS NOT NULL DROP FUNCTION [dbo].[IsBoss]
GO
CREATE Function dbo.IsBoss(@id int)
RETURNS BIT
AS
BEGIN
	IF Exists(SELECT top 1 null FROM Employees WHERE ReportsTo = @id)
	BEGIN
		RETURN 1
	END
	RETURN 0
END
GO


--------------------
--Real Prices View 
--------------------
IF OBJECT_ID('[dbo].[RealPrices]', 'V') IS NOT NULL DROP VIEW [dbo].[RealPrices]
GO
CREATE VIEW RealPrices AS
SELECT o.OrderID, o.CustomerID, Concat(e.LastName, ' ', e.Firstname) as Employee, o.OrderDate, o.RequiredDate
	 , p.ProductName, Cast(od.UnitPrice - od.UnitPrice * od.Discount as decimal(10,2)) as Price
FROM Orders o
INNER JOIN Employees e ON e.EmployeeID = o.EmployeeID
INNER JOIN [Order Details] od ON o.OrderID = od.OrderID
INNER JOIN Products p ON p.ProductID = od.ProductID
ORDER BY Price OffSet 0 ROWS
GO

----------------------------------------------------------------------------------------------------------------
-- History table + trigger
--
-- Данные поля выбраны для того чтобы можно было однозначно идентифицировать объект и субъект манипуляции данными,
-- а так же для опеределения даты и времени на которую нужно выполнить откат измененных данных.
----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('[dbo].[_OrdersHistory]', 'U') IS NOT NULL DROP TABLE [dbo].[_OrdersHistory]
GO
CREATE Table dbo._OrdersHistory
(
	Id int Identity(1,1),
	ActionType nvarchar(50) Not Null,
	ActionDate DateTime Not Null,
	[User] nvarchar(50) Not Null,
	[RowId] nvarchar(50) Not Null,
)
GO

IF OBJECT_ID('[dbo].[HisTrgr]', 'TR') IS NOT NULL DROP TRIGGER [dbo].[HisTrgr]
GO
CREATE Trigger HisTrgr
ON [dbo].[Orders]
After Insert, Update, Delete
AS
BEGIN
	DECLARE @rowId nvarchar(50)
	DECLARE @aType char(6)

	IF exists (SELECT 1 FROM inserted) AND not exists (SELECT 1 FROM deleted)
	BEGIN
		Set @atype = 'Insert'
		Set @rowid = (SELECT ins.OrderID FROM inserted ins)
	END Else
	BEGIN
		if exists (SELECT 1 FROM deleted) and not exists (SELECT 1 FROM inserted)
		BEGIN
			Set @atype = 'Delete'
			Set @rowid = (SELECT d.OrderID FROM deleted d)
		END Else
		BEGIN
			Set @atype = 'Update'
		    Set @rowid = (SELECT ins.OrderID FROM inserted ins)
		END
	END

	INSERT INTO dbo._OrdersHistory(ActionType, ActionDate, [User], RowId)
	VALUES(@aType, GETDATE(), SYSTEM_USER, @rowId)
END
