USE [Northwind]

declare @y int = 1998
declare @c int = 5

EXEC dbo.GreatestOrders @y, @c
EXEC dbo.GreatestOrdersCur @y, @c

declare @name nvarchar(100) = 'Fuller Andrew'

SELECT top 3 Concat(e.LastName, ' ', e.Firstname) as Employee, ag.OrderID, Cast(ag.[Order Price]as decimal(10,2)) as [Order Price]
FROM Orders o
INNER JOIN Employees e ON E.EmployeeID = O.EmployeeID
INNER JOIN (SELECT [OrderID], Sum([Quantity] * ([UnitPrice] - [UnitPrice] * [Discount] )) as [Order Price]
			FROM [Order Details]
			GROUP BY OrderID) ag On ag.OrderID = o.OrderID
WHERE @name = e.LastName + ' ' + e.Firstname and Year(o.OrderDate) = @y
ORDER BY [Order Price] DESC
GO

EXEC dbo.ShippedOrdersDiff 35