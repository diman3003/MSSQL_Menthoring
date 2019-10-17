USE [Northwind]
GO

IF OBJECT_ID('[dbo].[GreatestOrders]', 'P') IS NOT NULL Drop Procedure [dbo].[GreatestOrders]
GO

IF OBJECT_ID('[dbo].[GreatestOrdersCur]', 'P') IS NOT NULL Drop Procedure [dbo].[GreatestOrdersCur]
GO

-------------------------------------------------
--[dbo].[GreatestOrders]
-------------------------------------------------
CREATE PROCEDURE [dbo].[GreatestOrders] @year int, @top int
AS

SET ROWCOUNT @top

SELECT Concat(e.LastName, ' ', e.Firstname) as Employee, ag2.OrderID, Cast(ag2.[Order Price] as decimal(10,2)) as [Order Price]
FROM Employees e
Inner Join (SELECT o.EmployeeID, ag.OrderID, ag.[Order Price], Row_Number() Over (Partition by o.EmployeeId ORDER BY [Order Price] DESC) as N
			From  Orders o
			Inner Join (SELECT [OrderID], Sum([Quantity] * ([UnitPrice] - [UnitPrice] * [Discount] )) as [Order Price]
						FROM [Order Details]
						GROUP BY OrderID) ag On ag.OrderID = o.OrderID
			WHERE Year(o.OrderDate) = @year) ag2 On e.EmployeeID = ag2.EmployeeID
WHERE ag2.N = 1
ORDER BY [Order Price] DESC

SET ROWCOUNT 0
GO

-------------------------------------------------
--[dbo].[GreatestOrdersCur]
-------------------------------------------------
CREATE PROCEDURE [dbo].[GreatestOrdersCur] @year int, @top int
AS

Declare @employee nvarchar(50)
Declare @id int
Declare @mFright decimal(10,2)
Declare cur CURSOR
For

SELECT Concat(e.LastName, ' ', e.Firstname) as Employee, ag2.OrderID, Cast(ag2.[Order Price] as decimal(10,2)) as [Order Price]
FROM Employees e
Inner Join (SELECT o.EmployeeID, ag.OrderID, ag.[Order Price], Row_Number() Over (Partition by o.EmployeeId ORDER BY [Order Price] DESC) as N
			From  Orders o
			Inner Join (SELECT [OrderID], Sum([Quantity] * ([UnitPrice] - [UnitPrice] * [Discount] )) as [Order Price]
						FROM [Order Details]
						GROUP BY OrderID) ag On ag.OrderID = o.OrderID
			WHERE Year(o.OrderDate) = @year) ag2 On e.EmployeeID = ag2.EmployeeID
WHERE ag2.N = 1
ORDER BY [Order Price] DESC

Open cur

While @top > 0
Begin
	Fetch Next From cur Into @employee, @id, @mFright
	Select @employee, @id, @mFright
	Set @top = @top - 1
End

Close cur
Deallocate cur
