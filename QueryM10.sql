-----------------------------------------------------------------------------------------
-- 10.1.1 Разработать формат XML сообщения для передачи/получения информации о заказах.
-----------------------------------------------------------------------------------------
<Order OrderID="10248" CustomerID="VINET" EmployeeID="5" OrderDate="1996-07-04T00:00:00" RequiredDate="1996-08-01T00:00:00" ShippedDate="1996-07-16T00:00:00" ShipVia="3"
		Freight="32.3800" ShipName="Vins et alcools Chevalier" ShipAddress="59 rue de l'Abbaye" ShipCity="Reims" ShipRegion="RJ" ShipPostalCode="51100" ShipCountry="France">
  <Product OrderID="10248" ProductID="11" UnitPrice="14.0000" Quantity="12" Discount="0.0000000e+000" />
  <Product OrderID="10248" ProductID="42" UnitPrice="9.8000" Quantity="10" Discount="0.0000000e+000" />
  <Product OrderID="10248" ProductID="72" UnitPrice="34.8000" Quantity="5" Discount="0.0000000e+000" />
</Order>

-----------------------------------------------------------------------------------------------
-- 10.1.2 Разработать хранимую процедуру, которая будет формировать XML по конкретному заказу.
-----------------------------------------------------------------------------------------------
IF OBJECT_ID('[dbo].[GetOrderXML]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[GetOrderXML]
GO

CREATE PROCEDURE [dbo].[GetOrderXML]
@id int,
@xml xml OUTPUT
AS
	SET @xml = (SELECT * FROM Northwind.dbo.Orders AS [Order]
	INNER JOIN Northwind.dbo.[Order Details] AS [Product]
	ON [Order].OrderID = [Product].OrderID
	WHERE [Order].OrderID = @id
	FOR XML AUTO)
GO

-----------------------------------------------------------------------------------------------------------------------------------------
-- 10.1.3 3. Разработать хранимую процедуру, которая будет получать XML с информацией о заказе и записывать данные в таблицы БД.
-- При этом необходимо учитывать, что информация по заказу в таблицах уже может быть, но отличатся количеством записей, значениями полей.
-----------------------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('[dbo].[UpdateOrders]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[UpdateOrders]
GO
CREATE PROCEDURE [dbo].[UpdateOrders] @id int  = 10248
AS
DECLARE @res nvarchar(255)
DECLARE @xml xml

EXEC dbo.GetOrderXML @id, @xml OUT

SET IDENTITY_INSERT dbo.Orders ON
MERGE INTO dbo.Orders AS ord
USING (
	SELECT x.value(N'@OrderID', N'int') AS OrderID,
			x.value(N'@CustomerID', N'nchar(5)') AS CustomerID,
			x.value(N'@EmployeeID', N'int') AS EmployeeID,
			x.value(N'@OrderDate', N'datetime') AS OrderDate,
			x.value(N'@RequiredDate', N'datetime') AS RequiredDate,
			x.value(N'@ShippedDate', N'datetime') AS ShippedDate,
			x.value(N'@ShipVia', N'int') AS ShipVia,
			x.value(N'@Freight', N'money') AS Freight,
			x.value(N'@ShipName', N'nvarchar(40)') AS ShipName,
			x.value(N'@ShipAddress', N'nvarchar(60)') AS ShipAddress,
			x.value(N'@ShipCity', N'nvarchar(15)') AS ShipCity,
			x.value(N'@ShipRegion', N'nvarchar(15)') AS ShipRegion,
			x.value(N'@ShipPostalCode', N'nvarchar(10)') AS ShipPostalCode,
			x.value(N'@ShipCountry', N'nvarchar(15)') AS ShipCountry
	FROM @xml.nodes(N'/Order') t(x)
) AS imp 
ON ord.OrderId = imp.OrderID
WHEN NOT MATCHED THEN 
	INSERT (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, ShipVia, Freight, ShipName, ShipAddress, ShipCity, ShipRegion, ShipPostalCode, ShipCountry)
	VALUES (imp.OrderID, imp.CustomerID, imp.EmployeeID, imp.OrderDate, imp.RequiredDate, imp.ShippedDate, imp.ShipVia, imp.Freight, imp.ShipName, imp.ShipAddress, imp.ShipCity,
			imp.ShipRegion, imp.ShipPostalCode, imp.ShipCountry)
WHEN MATCHED THEN 
	UPDATE SET RequiredDate = imp.RequiredDate, ShippedDate = imp.ShippedDate, ShipVia = imp.ShipVia, Freight = imp.Freight, ShipName = imp.ShipName,
				ShipAddress = imp.ShipAddress, ShipCity = imp.ShipCity, ShipRegion = imp.ShipRegion, ShipPostalCode = imp.ShipPostalCode, ShipCountry = imp.ShipCountry;

SET IDENTITY_INSERT dbo.Orders OFF

MERGE INTO dbo.[Order Details] AS od
USING (
	SELECT x.value(N'@OrderID', N'int') AS OrderID,
			x.value(N'@ProductID', N'int') AS ProductID,
			x.value(N'@UnitPrice', N'money') AS UnitPrice,
			x.value(N'@Quantity', N'smallint') AS Quantity,
			x.value(N'@Discount', N'real') AS Discount
	FROM @xml.nodes(N'/Order/Product') t(x)
) AS imp 
ON od.OrderId = imp.OrderID AND od.ProductID = imp.ProductID
WHEN NOT MATCHED BY SOURCE THEN
	DELETE
WHEN NOT MATCHED BY TARGET THEN 
	INSERT (OrderID, ProductID, UnitPrice, Quantity, Discount)
	VALUES (imp.OrderID, imp.ProductID, imp.UnitPrice, imp.Quantity, imp.Discount)
WHEN MATCHED THEN 
	UPDATE SET UnitPrice = imp.UnitPrice, Quantity = imp.Quantity, Discount = imp.Discount;
GO

------------------------
-- Проверка результатов
------------------------
SELECT *
FROM dbo.Orders
WHERE OrderID = 10248

SELECT *
FROM dbo.[Order Details]
WHERE OrderID = 10248


------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 10.2 Дано:
-- 1) таблица с активами: Assets(AssetID, AssetName, Nominal, ClientPrice)
-- 2) таблица с ценами активов на каждый день: Prices (AssetID, PriceDate, Price, ClientPrice).
-- Необходимо разработать хранимую процедуру, которая на вход принимает дату. 
-- В хранимой процедуцре должно обновлятся поле ClientPrice таблицы Assets по данным из таблицы Prices. Если на указанную дату в тблице Prices поле ClientPrice = 0
-- или NULL, то нужно взять заполненное значение поля ClientPrice (ClientPrice > 0) на ближайшую дату, предшествующую указанной на входе процедуры.
-- Необходимо использовать outer apply или cross apply.
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('[dbo].[CorrectPricesOnDate]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[CorrectPricesOnDate]
GO

CREATE PROCEDURE [dbo].[CorrectPricesOnDate] @d  datetime = '20190108'
AS
	UPDATE dbo.Assets
	SET ClientPrice = t.ClientPrice
	FROM dbo.Assets AS a
	CROSS APPLY
	(
		SELECT top(1) * 
		FROM dbo.Prices AS p
		WHERE a.AssetID = p.AssetID and p.PriceDate <= @d
		ORDER BY p.PriceDate DESC
	) as t
GO

IF OBJECT_ID('[dbo].[Prices]', 'U') IS NOT NULL DROP TABLE [dbo].[Prices]
GO
CREATE TABLE [dbo].[Prices](
	[AssetID] [int] NOT NULL,
	[PriceDate] [datetime] NOT NULL,
	[Price] [decimal](10, 2) NOT NULL,
	[ClientPrice] [decimal](10, 2) NOT NULL
) ON [PRIMARY]
GO

IF OBJECT_ID('[dbo].[Assets]', 'U') IS NOT NULL DROP TABLE [dbo].[Assets]
GO
CREATE TABLE [dbo].[Assets](
	[AssetID] [int] IDENTITY(1,1) NOT NULL,
	[AssetName] [nvarchar](20) NULL,
	[Nominal] [nvarchar](20) NULL,
	[ClientPrice] [decimal](10, 2) NULL
) ON [PRIMARY]
GO

--------------------
--Заполнение таблиц
--------------------
DECLARE @i int = 1

WHILE @i < 11
BEGIN
	INSERT INTO Assets(AssetName, Nominal, ClientPrice) VALUES (@i, @i, @i+5)
	INSERT INTO Prices(AssetID, PriceDate, Price, ClientPrice) VALUES (@i%3+1, DATEADD(DAY, @i, '20190101'), @i, @i)
	SET @i = @i + 1
END


