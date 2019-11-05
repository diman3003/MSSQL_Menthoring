USE [Northwind];
GO

-------------------------------------------------------------------------------------------------------------------------------------
-- 7.1.1 ѕолучить статистику заказов по регионам покуателей: ƒл€ каждой категории продукта (поле CategoryName  из таблицы Categories)
-- вывести средную стоимость заказов дл€ покупателей из регионов AK, BC, CA, Co. Cork (поле Region  из таблицы Customers)
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
-- 7.2.	—оздать временную таблицу #Periods с двум€ пол€ми: PeriodID, Value. 
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
-- 7.2.1. “ребуетс€ отобрать периоды в которых значение Value отличаетс€ от значени€ Value в предыдущем периоде. 
-- ¬ыводимые пол€: PeriodID, Value. ¬ примере выше должны быть выведены значени€ 1, 5, 7, 9
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
-- 7.2.2. “ребуетс€ удалить из таблицы периоды в которых значение Value равно значению Value в предыдущем периоде.
-- ¬ыводимые пол€: PeriodID, Value. ¬ примере выше должны быть удалены значени€ 3, 6, 10.
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
-- 7.3.1 ѕронумеруйте заказы из таблицы Orders в пор€дке уменьшени€ времени затрат на доставку.
-------------------------------------------------------------------------------------------------

SELECT OrderID, OrderDate, ShippedDate, DATEDIFF(day, OrderDate, ShippedDate) AS Delta
		,ROW_NUMBER() OVER(ORDER BY DATEDIFF(day, OrderDate, ShippedDate) DESC) AS N
FROM dbo.Orders
WHERE ShippedDate IS NOT NULL

-------------------------------------------------------------------------------------------------------
-- 7.3.2 ¬ыберите те категории продуктов, у которых количество поставщиков из одной страны больше трех.
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
-- 7.3.3.	—оздайте функцию GetNums(@low bigint, @high bigint), котора€ возвращает таблицу с колонкой n bigint.
-- ¬ этой таблице должны быть упор€доченные по возрастанию значени€ от @low до @high (количеством записей @high - @low + 1).
-----------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.GetNums', N'TF') IS NOT NULL DROP FUNCTION [dbo].[GetNums]
GO

CREATE FUNCTION dbo.GetNums(@low bigint, @high bigint)
RETURNS TABLE   
AS  
RETURN
with
	b0 as (select n from (values (0),(0x00000001),(0x00000002),(0x00000003),(0x00000004),(0x00000005),(0x00000006),(0x00000007),(0x00000008),(0x00000009),(0x0000000A),(0x0000000B),(0x0000000C),(0x0000000D),(0x0000000E),(0x0000000F)) as b0(n)),
	b1 as (select n from (values (0),(0x00000010),(0x00000020),(0x00000030),(0x00000040),(0x00000050),(0x00000060),(0x00000070),(0x00000080),(0x00000090),(0x000000A0),(0x000000B0),(0x000000C0),(0x000000D0),(0x000000E0),(0x000000F0)) as b1(n)),
	b2 as (select n from (values (0),(0x00000100),(0x00000200),(0x00000300),(0x00000400),(0x00000500),(0x00000600),(0x00000700),(0x00000800),(0x00000900),(0x00000A00),(0x00000B00),(0x00000C00),(0x00000D00),(0x00000E00),(0x00000F00)) as b2(n)),
	b3 as (select n from (values (0),(0x00001000),(0x00002000),(0x00003000),(0x00004000),(0x00005000),(0x00006000),(0x00007000),(0x00008000),(0x00009000),(0x0000A000),(0x0000B000),(0x0000C000),(0x0000D000),(0x0000E000),(0x0000F000)) as b3(n)),
	b4 as (select n from (values (0),(0x00010000),(0x00020000),(0x00030000),(0x00040000),(0x00050000),(0x00060000),(0x00070000),(0x00080000),(0x00090000),(0x000A0000),(0x000B0000),(0x000C0000),(0x000D0000),(0x000E0000),(0x000F0000)) as b4(n)),
	b5 as (select n from (values (0),(0x00100000),(0x00200000),(0x00300000),(0x00400000),(0x00500000),(0x00600000),(0x00700000),(0x00800000),(0x00900000),(0x00A00000),(0x00B00000),(0x00C00000),(0x00D00000),(0x00E00000),(0x00F00000)) as b5(n)),
	b6 as (select n from (values (0),(0x01000000),(0x02000000),(0x03000000),(0x04000000),(0x05000000),(0x06000000),(0x07000000),(0x08000000),(0x09000000),(0x0A000000),(0x0B000000),(0x0C000000),(0x0D000000),(0x0E000000),(0x0F000000)) as b6(n)),
	b7 as (select n from (values (0),(0x10000000),(0x20000000),(0x30000000),(0x40000000),(0x50000000),(0x60000000),(0x70000000)) as b7(n))

	select s.n
	from (
		select
			  b7.n
			| b6.n
			| b5.n
			| b4.n
			| b3.n
			| b2.n
			| b1.n
			| b0.n
			+ @low
			 n
		from b0
		join b1 on b0.n <= @high-@low and b1.n <= @high-@low
		join b2 on b2.n <= @high-@low
		join b3 on b3.n <= @high-@low
		join b4 on b4.n <= @high-@low
		join b5 on b5.n <= @high-@low
		join b6 on b6.n <= @high-@low
		join b7 on b7.n <= @high-@low
	) s
	where @high >= s.n
GO 

SELECT * FROM dbo.GetNums(100, 250)