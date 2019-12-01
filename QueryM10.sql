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

IF OBJECT_ID('[dbo].[UpdateOrders]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[UpdateOrders]
GO
CREATE PROCEDURE [dbo].[UpdateOrders]
AS
declare @res nvarchar(255)
declare @xml xml

EXEC dbo.GetOrderXML 10248, @xml OUT

SET IDENTITY_INSERT dbo.Orders ON
MERGE INTO dbo.Orders AS ord
USING (
	select x.value(N'@OrderID', N'int') As OrderID,
			x.value(N'@CustomerID', N'nchar(5)') As CustomerID,
			x.value(N'@EmployeeID', N'int') As EmployeeID,
			x.value(N'@OrderDate', N'datetime') As OrderDate,
			x.value(N'@RequiredDate', N'datetime') As RequiredDate,
			x.value(N'@ShippedDate', N'datetime') As ShippedDate,
			x.value(N'@ShipVia', N'int') As ShipVia,
			x.value(N'@Freight', N'money') As Freight,
			x.value(N'@ShipName', N'nvarchar(40)') As ShipName,
			x.value(N'@ShipAddress', N'nvarchar(60)') As ShipAddress,
			x.value(N'@ShipCity', N'nvarchar(15)') As ShipCity,
			x.value(N'@ShipPostalCode', N'nvarchar(10)') As ShipPostalCode,
			x.value(N'@ShipCountry', N'nvarchar(15)') As ShipCountry
	from @xml.nodes(N'/Order') t(x)
) AS imp 
ON ord.OrderId = imp.OrderID
WHEN NOT MATCHED THEN 
	INSERT (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, Freight, ShipName, ShipAddress, ShipCity, ShipPostalCode, ShipCountry)
	VALUES (imp.OrderID, imp.CustomerID, imp.EmployeeID, imp.OrderDate, imp.RequiredDate, imp.ShippedDate, imp.Freight, imp.ShipName, imp.ShipAddress, imp.ShipCity,
			imp.ShipPostalCode, imp.ShipCountry)
WHEN MATCHED THEN 
	UPDATE SET RequiredDate = imp.RequiredDate, ShippedDate = imp.ShippedDate, Freight = imp.Freight, ShipName = imp.ShipName,
				ShipAddress = imp.ShipAddress, ShipCity = imp.ShipCity, ShipPostalCode = imp.ShipPostalCode, ShipCountry = imp.ShipCountry;

SET IDENTITY_INSERT dbo.Orders OFF

MERGE INTO dbo.[Order Details] AS od
USING (
	select x.value(N'@OrderID', N'int') As OrderID,
			x.value(N'@ProductID', N'int') As ProductID,
			x.value(N'@UnitPrice', N'money') As UnitPrice,
			x.value(N'@Quantity', N'smallint') As Quantity,
			x.value(N'@Discount', N'real') As Discount
	from @xml.nodes(N'/Order/Product') t(x)
) AS imp 
ON od.OrderId = imp.OrderID AND od.ProductID = imp.ProductID
WHEN NOT MATCHED THEN 
	INSERT (OrderID, ProductID, UnitPrice, Quantity, Discount)
	VALUES (imp.OrderID, imp.ProductID, imp.UnitPrice, imp.Quantity, imp.Discount)
WHEN MATCHED THEN 
	UPDATE SET UnitPrice = imp.UnitPrice, Quantity = imp.Quantity, Discount = imp.Discount;
GO




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

declare @i int = 1

while @i < 11
begin
	insert into Assets(AssetName, Nominal, ClientPrice) Values (@i, @i, @i+5)
	insert into Prices(AssetID, PriceDate, Price, ClientPrice) Values (@i%3+1, DATEADD(DAY,@i,'20190101'), @i, @i)
	set @i = @i + 1
end


