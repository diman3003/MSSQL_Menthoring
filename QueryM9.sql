USE Northwind
GO

-----------------------------------------------------------------------------------------------------------------------------
-- 9.1.	Ќаписать скрипт создани€ индекса дл€ таблицы dbo.Employees дл€ пол€ PostalCode (им€ индекса должно быть PostalCode).
-- —делать об€зательную проверку при создании индекса на существование данного индекса в таблице.
-----------------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (Select TOP 1 NULL FROM sys.indexes WHERE [name] = 'IDX_PostalCode')
BEGIN	
	CREATE NONCLUSTERED INDEX  IDX_PostalCode ON dbo.Employees(PostalCode);
END
GO

-----------------------------------------------------------------------------------------------------------------------------
-- 9.2.	Ќаписать скрипт, который обновит в поле PostalCode таблицы dbo.Employees все не числовые символы на любые числовые.
-----------------------------------------------------------------------------------------------------------------------------
IF EXISTS (SELECT top 1 NULL FROM sys.objects WHERE [type] = 'FN' AND [name] = 'SetDigits')
BEGIN
	DROP FUNCTION dbo.SetDigits
END
GO

CREATE FUNCTION dbo.SetDigits(@str varchar(10))
RETURNS varchar(10)
AS
BEGIN
    DECLARE @range as varchar(50) = '%[^0-9]%'
    WHILE PATINDEX(@range, @str) > 0
        SET @str = STUFF(@str, PATINDEX(@range, @str), 1, '0')
    RETURN @str
END
GO

DECLARE @range as varchar(50) = '%[^0-9]%'
UPDATE dbo.Employees
SET PostalCode = dbo.SetDigits(PostalCode)
WHERE PostalCode LIKE @range
GO


SELECT PostalCode
FROM dbo.Employees

GO

-----------------------------------------------------------------------------------------------------------
-- 9.3 ѕостроить план и оптимизировать запрос, представленный ниже, 
-- так чтобы индекс индекс PostalCode работал не по табличному сканированию (Index Scan), а по Index Seek.
-----------------------------------------------------------------------------------------------------------

SELECT  EmployeeID
FROM    dbo.Employees
WHERE   LEFT(PostalCode, 2) = '98';

-- –ешение
SELECT  EmployeeID
FROM    dbo.Employees
WHERE   PostalCode like '98%'; --like '98%' is SARG

----------------------------------------------------------------------------------------------------------------------------------------
-- 9.4. –азобратьс€ с планом запроса, представленного ниже скрипта. ќптимизировать запрос.
-- ѕо€снить подробно почему вы считаете, что ваш вариант оптимизации наиболее оптимизирует данный запрос и увеличит его быстродействие?
----------------------------------------------------------------------------------------------------------------------------------------


set statistics time on 
DECLARE @OrderDate DATETIME = N'1996-01-01 00:00:00'

SELECT  OrderId = ordr.OrderID,
                 EmployeeName = ISNULL(empl.FirstName, '') + ' ' + ISNULL(empl.LastName, ''),
                 CustomerId = ordr.CustomerID,
	             CompanyName = cust.CompanyName,
                 ShippedDate = ordr.ShippedDate,
                 ProductName = prod.ProductName
FROM    dbo.Orders ordr
INNER JOIN dbo.[Order Details] ord ON ord.OrderID = ordr.OrderID
INNER JOIN dbo.Products prod ON ord.ProductID = prod.ProductID
INNER JOIN dbo.Customers cust ON ordr.CustomerID = cust.CustomerID
INNER JOIN dbo.Employees empl ON ordr.EmployeeID = empl.EmployeeID
WHERE ordr.OrderDate >= @OrderDate

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ”далена проверак на null, дл€ уменьшен€ действий со значени€ми, поскольку данные пол€ не могут содержать null значени€.
--   существующему индексу OrderDate добавлены included пол€ (Index Scan изменилс€ на Index Seek).
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- 
set statistics time on 
DECLARE @OrderDate DATETIME = N'1996-01-01 00:00:00'

SELECT  ordr.OrderID AS OrderId,
        CONCAT(empl.FirstName, ' ', empl.LastName) AS EmployeeName,
        ordr.CustomerID AS CustomerId,
	    cust.CompanyName AS CompanyName,
        ordr.ShippedDate AS ShippedDate,
        prod.ProductName AS ProductName
FROM  dbo.Orders ordr --WITH(INDEX(OrderDate))
INNER JOIN dbo.[Order Details] ord ON ord.OrderID = ordr.OrderID
INNER JOIN dbo.Products prod ON ord.ProductID = prod.ProductID
INNER JOIN dbo.Customers cust ON ordr.CustomerID = cust.CustomerID
INNER JOIN dbo.Employees empl ON ordr.EmployeeID = empl.EmployeeID
WHERE ordr.OrderDate >= @OrderDate
