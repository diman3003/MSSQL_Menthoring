USE [Northwind];
GO

-------------------------------------------------------------------------------------------------------------------------------------
-- 7.1.1 �������� ���������� ������� �� �������� ����������: ��� ������ ��������� �������� (���� CategoryName  �� ������� Categories)
-- ������� ������� ��������� ������� ��� ����������� �� �������� AK, BC, CA, Co. Cork (���� Region  �� ������� Customers)
-------------------------------------------------------------------------------------------------------------------------------------
;WITH CTE
AS(
	SELECT cat.CategoryName, c.Region AS R, CAST((od.Quantity * (od.UnitPrice - od.UnitPrice * od.Discount )) AS decimal(10,2)) AS P
	FROM dbo.Customers c 
	INNER JOIN dbo.Orders o ON c.CustomerID = o.CustomerID
	INNER JOIN dbo.[Order Details] od ON o.OrderID = od.OrderId
	INNER JOIN dbo.Products p ON p.ProductID = od.ProductID
	INNER JOIN dbo.Categories cat ON p.CategoryID = cat.CategoryID
	WHERE c.Region IN ('AK', 'BC', 'CA', 'Co. Cork' )
)
SELECT CategoryName as Category, [AK], [BC], [CA], [Co. Cork]
FROM CTE
PIVOT(AVG(P) FOR R IN ([AK], [BC], [CA], [Co. Cork])) AS PT;
GO

-----------------------------------------------------------------------------
-- 7.2.	������� ��������� ������� #Periods � ����� ������: PeriodID, Value. 
-----------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Periods') IS NOT NULL DROP TABLE [dbo].[#Periods];
GO

CREATE TABLE dbo.#Periods
(
	[Period] int
	,[Value] int
);
GO

DELETE FROM #Periods
INSERT INTO #Periods([Period], [Value]) VALUES(1,10);
INSERT INTO #Periods([Period], [Value]) VALUES(3,10);
INSERT INTO #Periods([Period], [Value]) VALUES(5,20);
INSERT INTO #Periods([Period], [Value]) VALUES(6,20);
INSERT INTO #Periods([Period], [Value]) VALUES(7,30);
INSERT INTO #Periods([Period], [Value]) VALUES(9,40);
INSERT INTO #Periods([Period], [Value]) VALUES(10,40);

-------------------------------------------------------------------------------------------------------------------
-- 7.2.1. ��������� �������� ������� � ������� �������� Value ���������� �� �������� Value � ���������� �������. 
-- ��������� ����: PeriodID, Value. � ������� ���� ������ ���� �������� �������� 1, 5, 7, 9
-------------------------------------------------------------------------------------------------------------------
;WITH CTE
AS
(
	SELECT [Period], [Value], SUM([Value]) OVER(ORDER BY [Period] ROWS BETWEEN  1 PRECEDING AND CURRENT ROW) AS V
	FROM #Periods
)
SELECT [Period]
FROM CTE
WHERE [Value] != V/2;
GO

-------------------------------------------------------------------------------------------------------------------
-- 7.2.2. ��������� ������� �� ������� ������� � ������� �������� Value ����� �������� Value � ���������� �������.
-- ��������� ����: PeriodID, Value. � ������� ���� ������ ���� ������� �������� 3, 6, 10.
-------------------------------------------------------------------------------------------------------------------
;WITH CTE
AS
(
	SELECT [Period], [Value], SUM([Value]) OVER(ORDER BY [Period] ROWS BETWEEN  1 PRECEDING AND CURRENT ROW) AS V
	FROM #Periods
)
DELETE
FROM CTE
WHERE [Value] = V/2;
GO

SELECT * FROM #Periods

-------------------------------------------------------------------------------------------------
-- 7.3.1 ������������ ������ �� ������� Orders � ������� ���������� ������� ������ �� ��������.
-------------------------------------------------------------------------------------------------

SELECT OrderID, OrderDate, ShippedDate, DATEDIFF(day, OrderDate, ShippedDate) AS Delta
		,ROW_NUMBER() OVER(ORDER BY DATEDIFF(day, OrderDate, ShippedDate) DESC) AS N
FROM dbo.Orders
WHERE ShippedDate IS NOT NULL

-------------------------------------------------------------------------------------------------------
-- 7.3.2 �������� �� ��������� ���������, � ������� ���������� ����������� �� ����� ������ ������ ����.
-------------------------------------------------------------------------------------------------------
;WITH CTE
AS
(
	SELECT *, ROW_NUMBER() OVER(PARTITION BY CategoryName, Country ORDER BY Country ) AS N
	FROM
	(
		SELECT DISTINCT s.SupplierID, s.Country, c.CategoryName
		FROM dbo.Suppliers s
		INNER JOIN dbo.Products p ON p.SupplierID = s.SupplierID
		INNER JOIN dbo.Categories c ON c.CategoryID = p.CategoryID
	) AS t
)

SELECT CategoryName
FROM CTE
WHERE N > 1
GO

-----------------------------------------------------------------------------------------------------------------------------
-- 7.3.3.	�������� ������� GetNums(@low bigint, @high bigint), ������� ���������� ������� � �������� n bigint.
-- � ���� ������� ������ ���� ������������� �� ����������� �������� �� @low �� @high (����������� ������� @high - @low + 1).
-----------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID(N'[dbo].[GetNums]', N'FN') IS NOT NULL DROP FUNCTION [dbo].[GetNums]
GO

CREATE FUNCTION dbo.GetNums(@low bigint, @high bigint)
RETURNS @t TABLE   
(  
    n bigint  
)  
AS  
BEGIN  
WITH Cte(n)
    AS (  
			SELECT @low [n]
			UNION ALL
			SELECT [n]+1 FROM Cte WHERE [n] < @high
        )  

   INSERT @t
   SELECT n
   FROM Cte  
   RETURN  
END;  
GO 

SELECT * FROM dbo.GetNums(1,5)