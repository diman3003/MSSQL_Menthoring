USE Northwind
GO

-----------------------------------------------------------------------------------------------------------------------------
-- 9.1.	�������� ������ �������� ������� ��� ������� dbo.Employees ��� ���� PostalCode (��� ������� ������ ���� PostalCode).
-- ������� ������������ �������� ��� �������� ������� �� ������������� ������� ������� � �������.
-----------------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (Select TOP 1 NULL FROM sys.indexes WHERE [name] = 'IDX_PostalCode')
BEGIN	
	CREATE NONCLUSTERED INDEX  IDX_PostalCode ON dbo.Employees(PostalCode);
END
GO

-----------------------------------------------------------------------------------------------------------------------------
-- 9.2.	�������� ������, ������� ������� � ���� PostalCode ������� dbo.Employees ��� �� �������� ������� �� ����� ��������.
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
-- 9.3 ��������� ���� � �������������� ������, �������������� ����, 
-- ��� ����� ������ ������ PostalCode ������� �� �� ���������� ������������ (Index Scan), � �� Index Seek.
-----------------------------------------------------------------------------------------------------------

SELECT  EmployeeID
FROM    dbo.Employees
WHERE   LEFT(PostalCode, 2) = '98';

-- �������
SELECT  EmployeeID
FROM    dbo.Employees
WHERE   PostalCode like '98%'; --like '98%' is SARG

----------------------------------------------------------------------------------------------------------------------------------------
-- 9.4. ����������� � ������ �������, ��������������� ���� �������. �������������� ������.
-- �������� �������� ������ �� ��������, ��� ��� ������� ����������� �������� ������������ ������ ������ � �������� ��� ��������������?
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
-- ������� �������� �� null, ��� ��������� �������� �� ����������, ��������� ������ ���� �� ����� ��������� null ��������.
-- � ������������� ������� OrderDate ��������� included ���� (Index Scan ��������� �� Index Seek).
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
