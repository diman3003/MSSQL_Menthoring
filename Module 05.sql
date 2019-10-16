USE [Northwind]
GO
/****** Object:  StoredProcedure [dbo].[GreatestOrders]  Script Date: 15.10.2019 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GreatestOrders] @year int, @top int
AS

SET ROWCOUNT @top

SELECT Concat(e.LastName, ' ', e.Firstname) as Employee, ag.EmployeeID, ag.[Max Fright]
FROM Employees e 
INNER JOIN (SELECT o.EmployeeID, Max(Cast((o.Freight - (o.Freight * od.Discount)) AS decimal(10,2))) as [Max Fright]
			FROM Orders o
			INNER JOIN Employees e ON e.EmployeeID = o.EmployeeID
			INNER JOIN [Order Details] od ON od.OrderId = o.OrderId
			WHERE Year(o.OrderDate) = @year
			GROUP BY o.EmployeeID
			) ag ON e.EmployeeID = ag.EmployeeID
ORDER BY [Max Fright] DESC

SET ROWCOUNT 0