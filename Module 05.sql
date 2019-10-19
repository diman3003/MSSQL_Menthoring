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
	Select @employee as Employee, @id as [Order], @mFright as [Order Price]
	Set @top = @top - 1
End

Close cur
Deallocate cur
GO


-------------------------------------------------
--[dbo].[ShippedOrdersDiff]
-------------------------------------------------
CREATE PROCEDURE [dbo].[ShippedOrdersDiff] @days int
AS

Select  OrderID, OrderDate, ShippedDate, Datediff(Day, OrderDate, ShippedDate) as ShippedDelay, @days as SpecifiedDelay 
From Orders
Where ShippedDate - OrderDate > @days Or ShippedDate is Null
GO


--------------------
--IsBoss
--------------------
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

--------------------
--Real Prices View 
--------------------
Create View RealPrices As
Select o.OrderID, o.CustomerID, Concat(e.LastName, ' ', e.Firstname) as Employee, o.OrderDate, o.RequiredDate
	 , p.ProductName, Cast(od.UnitPrice - od.UnitPrice * od.Discount as decimal(10,2)) as Price
From Orders o
Inner Join Employees e On e.EmployeeID = o.EmployeeID
Inner Join [Order Details] od On o.OrderID = od.OrderID
Inner Join Products p On p.ProductID = od.ProductID
Order By Price OffSet 0 Rows
GO

--------------------------
--History table + trigger
--------------------------
Create Table dbo._OrdersHistory
(
	Id int Identity(1,1),
	ActionType nvarchar(50) Not Null,
	ActionDate DateTime Not Null,
	[User] nvarchar(50) Not Null,
	[RowId] nvarchar(50) NULL,
)
GO

Create Trigger HisTrgr
On [Northwind].[dbo].[Orders]
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
	Values(@aType, GETDATE(), CURRENT_USER, @rowId)
End
