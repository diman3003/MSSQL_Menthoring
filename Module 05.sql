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
FROM Employees e
Inner Join Orders o ON e.EmployeeID = o.EmployeeID
Inner Join (SELECT o.OrderID, o.EmployeeID, SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) AS [Order Price]
			, ROW_NUMBER() OVER (PARTITION BY o.EmployeeId ORDER BY SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) DESC) AS N
			FROM Orders o
			inner Join [Order Details] od ON o.OrderID = od.OrderID
			WHERE  YEAR(o.OrderDate) = @year
			GROUP BY o.OrderID, o.EmployeeID) ag ON o.OrderID = ag.OrderID
WHERE ag.N = 1
ORDER BY [Order Price] DESC
GO

-------------------------------------------------
--[dbo].[GreatestOrdersCur]
-------------------------------------------------
IF OBJECT_ID('[dbo].[GreatestOrdersCur]', 'P') IS NOT NULL Drop Procedure [dbo].[GreatestOrdersCur]
GO
CREATE PROCEDURE [dbo].[GreatestOrdersCur] @year int, @top int
AS

Declare @employee nvarchar(50)
Declare @id int
Declare @mFright decimal(10,2)
Declare cur CURSOR
For

SELECT CONCAT(e.LastName, ' ', e.Firstname) as Employee, ag.OrderID, CAST(ag.[Order Price] AS DECIMAL(10,2)) AS [Order Price]
FROM Employees e
Inner Join Orders o ON e.EmployeeID = o.EmployeeID
Inner Join (SELECT o.OrderID, o.EmployeeID, SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) AS [Order Price]
			, ROW_NUMBER() OVER (PARTITION BY o.EmployeeId ORDER BY SUM(od.[Quantity] * (od.[UnitPrice] - od.[UnitPrice] * od.[Discount] )) DESC) AS N
			FROM Orders o
			inner Join [Order Details] od ON o.OrderID = od.OrderID
			WHERE  YEAR(o.OrderDate) = @year
			GROUP BY o.OrderID, o.EmployeeID) ag ON o.OrderID = ag.OrderID
WHERE ag.N = 1
ORDER BY [Order Price] DESC

Open cur

While @top > 0
Begin
	Fetch Next From cur Into @employee, @id, @mFright
	Select @employee as Employee, @id as [Order], @mFright as [Order Price]
	Set @top = @top - 1
End

Close cur
Deallocate cur
GO


-------------------------------------------------
--[dbo].[ShippedOrdersDiff]
-------------------------------------------------
IF OBJECT_ID('[dbo].[ShippedOrdersDiff]', 'P') IS NOT NULL Drop Procedure [dbo].[ShippedOrdersDiff]
GO
CREATE PROCEDURE [dbo].[ShippedOrdersDiff] @days int
AS

If (IsNull(@days, '') = '')
	Set @days = 35

Select  OrderID, OrderDate, ShippedDate, Datediff(Day, OrderDate, ShippedDate) as ShippedDelay, @days as SpecifiedDelay 
From Orders
Where ShippedDate - OrderDate > @days Or ShippedDate is Null
GO


--------------------
--IsBoss
--------------------
IF OBJECT_ID('[dbo].[IsBoss]', 'FN') IS NOT NULL Drop Function [dbo].[IsBoss]
GO
Create Function dbo.IsBoss(@id int)
Returns Bit
AS
Begin
	IF Exists(Select top 1 null From Employees Where ReportsTo = @id)
	Begin
		Return 1
	End
	Return 0
End
GO


--------------------
--Real Prices View 
--------------------
IF OBJECT_ID('[dbo].[RealPrices]', 'V') IS NOT NULL Drop View [dbo].[RealPrices]
GO
Create View RealPrices As
Select o.OrderID, o.CustomerID, Concat(e.LastName, ' ', e.Firstname) as Employee, o.OrderDate, o.RequiredDate
	 , p.ProductName, Cast(od.UnitPrice - od.UnitPrice * od.Discount as decimal(10,2)) as Price
From Orders o
Inner Join Employees e On e.EmployeeID = o.EmployeeID
Inner Join [Order Details] od On o.OrderID = od.OrderID
Inner Join Products p On p.ProductID = od.ProductID
Order By Price OffSet 0 Rows
GO

----------------------------------------------------------------------------------------------------------------
-- History table + trigger
--
-- Данные поля выбраны для того чтобы можно было однозначно идентифицировать объект и субъект манипуляции данными,
-- а так же для опеределения даты и времени на которую нужно выполнить откат измененных данных.
----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('[dbo].[_OrdersHistory]', 'U') IS NOT NULL Drop Table [dbo].[_OrdersHistory]
GO
Create Table dbo._OrdersHistory
(
	Id int Identity(1,1),
	ActionType nvarchar(50) Not Null,
	ActionDate DateTime Not Null,
	[User] nvarchar(50) Not Null,
	[RowId] nvarchar(50) Not Null,
)
GO

IF OBJECT_ID('[dbo].[HisTrgr]', 'TR') IS NOT NULL Drop Trigger [dbo].[HisTrgr]
GO
Create Trigger HisTrgr
On [dbo].[Orders]
After Insert, Update, Delete
As
Begin
	declare @rowId nvarchar(50)
	declare @aType char(6)

	If exists (Select 1 From inserted) AND not exists (Select 1 From deleted)
	Begin
		Set @atype = 'Insert'
		Set @rowid = (Select ins.OrderID From inserted ins)
	End Else
	Begin
		if exists (Select 1 From deleted) and not exists (Select 1 From inserted)
		Begin
			Set @atype = 'Delete'
			Set @rowid = (Select d.OrderID From deleted d)
		End Else
		Begin
			Set @atype = 'Update'
		    Set @rowid = (Select ins.OrderID From inserted ins)
		End
	End

	Insert Into dbo._OrdersHistory(ActionType, ActionDate, [User], RowId)
	Values(@aType, GETDATE(), SYSTEM_USER, @rowId)
End
