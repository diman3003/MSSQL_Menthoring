USE [Northwind];
GO

-------------------------------------------------------------------------------------------------------------------------------------
-- 7.1.1 ѕолучить статистику заказов по регионам покуателей: ƒл€ каждой категории продукта (поле CategoryName  из таблицы Categories)
-- вывести средную стоимость заказов дл€ покупателей из регионов AK, BC, CA, Co. Cork (поле Region  из таблицы Customers)
-------------------------------------------------------------------------------------------------------------------------------------
;WITH CTE
AS(
	SELECT cat.CategoryName, c.Region AS R, CAST((od.Quantity * (od.UnitPrice - od.UnitPrice * od.Discount )) AS decimal(10,2)) as P
	FROM dbo.Customers c 
	INNER JOIN dbo.Orders o ON c.CustomerID = o.CustomerID
	INNER JOIN dbo.[Order Details] od ON o.OrderID = od.OrderId
	INNER JOIN dbo.Products p ON p.ProductID = od.ProductID
	INNER JOIN dbo.Categories cat ON p.CategoryID = cat.CategoryID
	WHERE c.Region IN ('AK', 'BC', 'CA', 'Co. Cork' )
)
SELECT CategoryName as Category, [AK], [BC], [CA], [Co. Cork]
FROM CTE
PIVOT(AVG(P) FOR R IN ([AK], [BC], [CA], [Co. Cork])) as PT;
GO
exec sp_help #Periods
-----------------------------------------------------------------------------
-- 7.2.	—оздать временную таблицу #Periods с двум€ пол€ми: PeriodID, Value. 
-----------------------------------------------------------------------------
IF OBJECT_ID('[dbo].[#Periods]', 'U') IS NOT NULL DROP TABLE [dbo].[#Periods];
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
	SELECT [Period], [Value], SUM(Value) OVER(ORDER BY [Period] ROWS BETWEEN  1 PRECEDING AND CURRENT ROW) AS V
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
	SELECT [Period], [Value], SUM(Value) OVER(ORDER BY [Period] ROWS BETWEEN  1 PRECEDING AND CURRENT ROW) AS V
	FROM #Periods
)
DELETE
FROM CTE
WHERE [Value] = V/2;
GO

SELECT * FROM #Periods