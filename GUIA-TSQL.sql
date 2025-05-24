--1. Hacer una función que dado un artículo y un deposito devuelva un string que
--indique el estado del depósito según el artículo. Si la cantidad almacenada es 
--menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el 
--% de ocupación. Si la cantidad almacenada es mayor o igual al límite retornar
--“DEPOSITO COMPLETO”.
CREATE FUNCTION ejercicio1(@articulo char(8), @deposito char(2))
RETURNS char(80)
AS
BEGIN 
	DECLARE @stock_cant decimal(12,2), @stock_max decimal(12,2)
	DECLARE @return char(40)

	SELECT 
	@stock_cant = ISNULL(stoc_cantidad, 0),
	@stock_max = stoc_stock_maximo
	FROM STOCK
	WHERE stoc_producto = @articulo AND stoc_deposito = @deposito

	IF @stock_cant >= @stock_max
		SET @return = 'DEPOSITO COMPLETO'
	ELSE
		SET @return = 'OCUPACION DEL DEPOSITO ' +str(ISNULL((@stock_cant*100/(@stock_max)), 0), 12, 2) + '%'
	
	RETURN @return
END
GO
SELECT dbo.ejercicio1(stoc_producto, stoc_deposito) from STOCK
GO
DROP FUNCTION dbo.ejercicio1
GO
--2. Realizar una función que dado un artículo y una fecha, retorne el stock que 
--se vendio desde la fecha que se pasa por parametro en adelante
CREATE FUNCTION ejercicio2 (@articulo char(8), @fecha smalldatetime)
RETURNS decimal(12, 2)
AS
BEGIN
	DECLARE @stock_vendido decimal(12, 2)
	SET @stock_vendido =
	(SELECT SUM(item_cantidad)
	FROM Item_Factura
	JOIN Factura ON item_numero + item_sucursal + item_tipo = 
	fact_numero + fact_sucursal + fact_tipo
	WHERE item_producto = @articulo AND fact_fecha >= @fecha
	)
	RETURN @stock_vendido
END
GO

SELECT dbo.ejercicio2('00000102', '2012-06-17')
DROP FUNCTION dbo.ejercicio2
GO
--3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado 
--en caso que sea necesario. Se sabe que debería existir un único gerente general 
--(debería ser el único empleado sin jefe). Si detecta que hay más de un empleado 
--sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por 
--mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la 
--empresa. Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla 
--de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad 
--de empleados que había sin jefe antes de la ejecución
CREATE PROCEDURE ejercicio3
AS
BEGIN
	DECLARE @gerente numeric(6)
	DECLARE @cant_empleados_sin_jefe int

	SET @cant_empleados_sin_jefe =
	(SELECT
	 COUNT(*)
	 FROM Empleado
	 WHERE empl_jefe IS NULL)

	 PRINT 'La cantidad de empleados sin jefe es: ' + str(@cant_empleados_sin_jefe)

	 SET @gerente = 
	 (SELECT
	  TOP 1 empl_codigo
	  FROM Empleado
	  WHERE empl_jefe IS NULL
	  ORDER BY empl_salario DESC, empl_ingreso ASC)

	UPDATE Empleado
	SET empl_jefe = @gerente
	WHERE empl_jefe IS NULL AND empl_codigo <> @gerente

	UPDATE Empleado
	SET empl_tareas = 'GERENTE GENERAL',
	empl_jefe = NULL
	WHERE empl_codigo = @gerente

END
GO

--4. Cree el/los objetos de base de datos necesarios para actualizar la columna de
--empleado empl_comision con la sumatoria del total de lo vendido por ese
--empleado a lo largo del último año. Se deberá retornar el código del vendedor 
--que más vendió (en monto) a lo largo del último año.

CREATE PROCEDURE ejercicio4 (@vendedor numeric(6, 0) OUTPUT)
AS
BEGIN
	DECLARE @ultimo_anio INT

	SET @ultimo_anio = (SELECT YEAR((SELECT MAX(fact_fecha) FROM Factura)))

	UPDATE Empleado SET empl_comision =
	(SELECT
	SUM(fact_total)
	FROM Factura
	WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = @ultimo_anio
	)

	SET @vendedor = 
	(SELECT TOP 1 fact_vendedor
	FROM Factura
	WHERE YEAR(fact_fecha) = @ultimo_anio
	GROUP BY fact_vendedor
	ORDER BY SUM(fact_total) DESC)
END
GO

/*
EJERCICIO N°5
Realizar un procedimiento que complete con los datos existentes en el 
modelo provisto la tabla de hechos denominada Fact_table que tiene las siguiente definición:
Create table Fact_table
( anio char(4),
mes char(2),
familia char(3),
rubro char(4),
zona char(3),
cliente char(6),
producto char(8),
cantidad decimal(12,2),
monto decimal(12,2)
)
Alter table Fact_table
Add constraint primary key(anio,mes,familia,rubro,zona,cliente,producto)
*/

IF OBJECT_ID('Fact_table', 'U') IS NOT NULL
DROP TABLE Fact_table
GO

Create table Fact_table
( anio char(4), --YEAR(fact_fecha)
mes char(2),	--
familia char(3), --prod_familia
rubro char(4),	-- prod_rubro
zona char(3),	--zona_codigo
cliente char(6),	--fact_cliente
producto char(8),	--item_producto
cantidad decimal(12,2),	--item_cantidad
monto decimal(12,2)	
)
GO 

ALTER TABLE Fact_table
ADD CONSTRAINT PK_Fact_Table_ID PRIMARY KEY(anio,mes,familia,rubro,zona,cliente,producto)
GO

CREATE PROCEDURE ejercicio5
AS
BEGIN
	INSERT INTO Fact_table
	SELECT
	YEAR(fact_fecha),
	MONTH(fact_fecha),
	prod_familia,
	prod_rubro,
	depa_zona,
	fact_cliente,
	prod_codigo,
	SUM(item_cantidad),
	SUM(item_precio)
	FROM Factura F
	JOIN Item_factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
	JOIN Producto ON item_producto = prod_codigo
	JOIN Empleado ON fact_vendedor = empl_codigo
	JOIN Departamento ON depa_codigo = empl_departamento
	GROUP BY 
	YEAR(fact_fecha),
	MONTH(fact_fecha),
	prod_familia,
	prod_rubro,
	depa_zona,
	fact_cliente,
	prod_codigo
END
GO

/* 6 - Realizar un procedimiento que si en alguna factura se facturaron componentes
que conforman un combo determinado (o sea que juntos componen otro
producto de mayor nivel), en cuyo caso deberá reemplazar las filas
correspondientes a dichos productos por una sola fila con el producto que
componen con la cantidad de dicho producto que corresponda.*/
IF OBJECT_ID('ejercicio6','U') IS NOT NULL
	DROP PROCEDURE ejercicio6
GO

CREATE PROCEDURE ejercicio6
AS
BEGIN
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @COMPONENTE CHAR(8)
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)
	DECLARE @CANTIDAD_VENDIDA DECIMAL(12,2)
	DECLARE @PRECIO_PRODUCTO DECIMAL(12,2)
	DECLARE @CANTIDAD_COMPONENTE DECIMAL(12,2)

	DECLARE @COMPONENTE2 CHAR(8)
	DECLARE @CANTIDAD DECIMAL(12,2)

	DECLARE C_COMPONENTE CURSOR FOR --Cursor para recorrer todas las facturas
	SELECT
	item_tipo,
	item_sucursal,
	item_numero,
	item_producto,
	item_cantidad,
	comp_cantidad,
	comp_producto,
	prod_precio
	FROM Item_Factura
	JOIN Composicion ON comp_componente = item_producto
	JOIN Producto ON comp_producto = prod_codigo
	AND item_cantidad % comp_cantidad = 0

	OPEN C_COMPONENTE
	FETCH NEXT FROM C_COMPONENTE INTO @TIPO, @SUCURSAL, @NUMERO,
	@COMPONENTE, @CANTIDAD_VENDIDA, @CANTIDAD_COMPONENTE, @PRODUCTO, @PRECIO_PRODUCTO

	WHILE @@FETCH_STATUS = 0
	BEGIN


	SET @CANTIDAD = @CANTIDAD_VENDIDA / @CANTIDAD_COMPONENTE

	SET @COMPONENTE2 =
	(SELECT
	 item_producto
	 FROM Item_Factura
	 JOIN Composicion ON item_producto = comp_componente
	 WHERE item_tipo = @TIPO
	 AND item_sucursal = @SUCURSAL
	 AND item_numero = @NUMERO
	 AND item_producto != @COMPONENTE
	 AND (item_cantidad / comp_cantidad) = @CANTIDAD)

	 IF(@COMPONENTE IS NOT NULL AND @COMPONENTE2 IS NOT NULL)
	 BEGIN
		DELETE FROM Item_Factura
		WHERE item_tipo = @TIPO
		AND item_sucursal = @SUCURSAL
		AND item_numero = @NUMERO
		AND item_producto = @COMPONENTE

		DELETE FROM Item_Factura 
		WHERE item_tipo = @TIPO
		AND item_sucursal = @SUCURSAL
		AND item_numero = @NUMERO
		AND item_producto = @COMPONENTE2

		INSERT INTO Item_Factura
		VALUES (@TIPO, @SUCURSAL, @NUMERO,
		@PRODUCTO, @CANTIDAD, @PRECIO_PRODUCTO)
	 END

END
GO

/* 7 - Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe
insertar una línea por cada artículo con los movimientos de stock generados por
las ventas entre esas fechas. La tabla se encuentra creada y vacía.*/ 

CREATE TABLE VENTAS (
	venta_codigo char(8),
	venta_detalle char(50),
	venta_movimientos INT,
	venta_precio DECIMAL(12, 2),
	venta_renglon NUMERIC(6, 0),
	venta_ganancia DECIMAL(12, 2)
)
GO

CREATE PROCEDURE ejercicio7 (@FECHA1 SMALLDATETIME, @FECHA2 SMALLDATETIME)
AS
BEGIN
	INSERT INTO VENTAS
	SELECT
	prod_codigo,
	prod_detalle,
	SUM(item_cantidad),
	AVG(item_precio),
	SUM(item_precio * item_cantidad) - SUM(item_cantidad * prod_precio)
	FROM Producto
	JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
	WHERE fact_fecha BETWEEN @FECHA1 AND @FECHA2
	GROUP BY prod_codigo, prod_detalle
END
GO
--con cursor:
CREATE PROCEDURE PR_COMPLETAR_VENTAS(@FECHA1 SMALLDATETIME, @FECHA2 SMALLDATETIME)
AS
BEGIN
	DECLARE @CODIGO CHAR(8)
	DECLARE @PRODUCTO CHAR(50)
	DECLARE @MOVIMIENTOS INT
	DECLARE @PRECIO DECIMAL(12,2)
	DECLARE @RENGLON INT
	DECLARE @GANANCIA DECIMAL(12,2)
	DECLARE C_VENTA CURSOR FOR

	SELECT 
	prod_codigo, 
	prod_detalle, 
	COUNT(item_producto), 
	AVG(item_precio),
	SUM(item_cantidad * item_precio) - SUM(item_cantidad * prod_precio)
	FROM Producto
	JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON item_numero + item_sucursal + item_tipo = fact_numero + fact_sucursal + fact_tipo
	WHERE fact_fecha BETWEEN @FECHA1 AND @FECHA2
	GROUP BY prod_codigo, prod_detalle

	OPEN C_VENTA
	FETCH NEXT FROM C_VENTA INTO @CODIGO, @PRODUCTO, @MOVIMIENTOS, @PRECIO, @GANANCIA

	IF OBJECT_ID('VENTAS') IS NOT NULL
		SET @RENGLON = (SELECT MAX(@RENGLON) FROM VENTAS) + 1
	ELSE
		SET @RENGLON = 0

	WHILE @@FETCH_STATUS = 0

BEGIN
	INSERT INTO VENTAS VALUES
	(@CODIGO, @PRODUCTO, @MOVIMIENTOS,
	@PRECIO, @RENGLON, @GANANCIA)

	SET @RENGLON = @RENGLON + 1

	FETCH NEXT FROM C_VENTA INTO @CODIGO, @PRODUCTO, 
	@MOVIMIENTOS, 
	@PRECIO, @GANANCIA

END
	CLOSE C_VENTA
	DEALLOCATE C_VENTA
END
GO

/* 8 - Realizar un procedimiento que complete la tabla Diferencias de precios, para los
productos facturados que tengan composición y en los cuales el precio de
facturación sea diferente al precio del cálculo de los precios unitarios por
cantidad de sus componentes, se aclara que un producto que compone a otro,
también puede estar compuesto por otros y así sucesivamente, la tabla se debe
crear y está formada por las siguientes columnas:*/

/*
EJERCICIO N°9
Hacer un trigger que ante alguna modificación de un ítem de factura de un 
artículo
con composición realice el movimiento de sus correspondientes 
componentes.*/


CREATE PROCEDURE PR_ACTUALIZAR_COMPONENTES_ITEM_FACTURA (@NUMERO CHAR(8), 
@TIPO CHAR(1), @SUCURSAL CHAR(4), 
@PRODUCTO CHAR(8), @DIFERENCIA DECIMAL(12,2), @RESULTADO INT OUTPUT)
AS
BEGIN
		IF EXISTS (SELECT * FROM Composicion WHERE comp_producto = @PRODUCTO)
		BEGIN
			DECLARE @COMPONENTE CHAR(8)
			DECLARE @CANTIDAD DECIMAL(12,2)

			SET @RESULTADO = 1

			DECLARE C_ITEM_FACTURA_PR CURSOR FOR SELECT
												 comp_componente,
												 comp_cantidad 
												 FROM Composicion 
												 WHERE comp_producto = @PRODUCTO 

		OPEN C_ITEM_FACTURA_PR
		FETCH NEXT FROM C_ITEM_FACTURA_PR INTO @COMPONENTE, @CANTIDAD
		BEGIN TRANSACTION
		WHILE @@FETCH_STATUS = 0
		BEGIN

		DECLARE @LIMITE DECIMAL(12,2)
		DECLARE @DEPOSITO CHAR(2)
		DECLARE @STOCK_ACTUAL DECIMAL(12,2)
		DECLARE @STOCK_RESULTANTE DECIMAL(12,2)

		SELECT TOP 1
		@STOCK_ACTUAL = stoc_cantidad,
		@LIMITE = ISNULL(stoc_stock_maximo, 0),
		@DEPOSITO = stoc_deposito
		FROM STOCK
		WHERE stoc_producto = @COMPONENTE
		ORDER BY stoc_cantidad ASC

		SET @STOCK_RESULTANTE = @STOCK_ACTUAL + @DIFERENCIA * @CANTIDAD

		IF @STOCK_RESULTANTE <= @LIMITE
		BEGIN
			UPDATE STOCK SET stoc_cantidad = @STOCK_RESULTANTE
			WHERE stoc_producto = @COMPONENTE
			AND stoc_deposito = @DEPOSITO
		END
		ELSE
		BEGIN
			SET @RESULTADO = 0
			RAISERROR('EL ITEM FACTURA CON NUMERO: %s, TIPO: 
			%s, SUCURSAL: %s, PRODUCTO: %s NO CUMPLE CON LOS LIMITES DE STOCK', 16, 
			1, @NUMERO, @TIPO, @SUCURSAL, @PRODUCTO)
		BREAK
		END
				FETCH NEXT FROM C_ITEM_FACTURA_PR INTO @COMPONENTE, @CANTIDAD
		END
				IF @RESULTADO = 1
				COMMIT TRANSACTION
		ELSE
				ROLLBACK TRANSACTION
				CLOSE C_ITEM_FACTURA_PR
				DEALLOCATE C_ITEM_FACTURA_PR
		END
		ELSE
				RAISERROR('EL PRODUCTO %s NO ES COMPUESTO', 16, 1, @PRODUCTO)
		END
		GO

CREATE TRIGGER TR_MOVER_COMPONENTES ON Item_Factura INSTEAD OF UPDATE
AS
BEGIN
		IF UPDATE(item_cantidad)
		BEGIN

		DECLARE @NUMERO CHAR(8)
		DECLARE @TIPO CHAR(1)
		DECLARE @SUCURSAL CHAR(4)
		DECLARE @PRODUCTO CHAR(8)
		DECLARE @DIFERENCIA DECIMAL(12,2)
		DECLARE @RESULTADO INT
		DECLARE C_ITEM_FACTURA CURSOR FOR

		SELECT
		inserted.item_numero, 
		inserted.item_tipo,
		inserted.item_sucursal,
		inserted.item_producto,
		deleted.item_cantidad - inserted.item_cantidad 
		FROM inserted 
		JOIN deleted ON 
		inserted.item_tipo + inserted.item_sucursal + inserted.item_numero + inserted.item_producto = 
		deleted.item_tipo + deleted.item_sucursal + deleted.item_numero + deleted.item_producto

		OPEN C_ITEM_FACTURA
		FETCH NEXT FROM C_ITEM_FACTURA INTO @NUMERO, @TIPO, @SUCURSAL, @PRODUCTO, @DIFERENCIA
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC PR_ACTUALIZAR_COMPONENTES_ITEM_FACTURA @NUMERO, @TIPO, @SUCURSAL, @PRODUCTO, @DIFERENCIA, @RESULTADO OUTPUT
		IF @RESULTADO = 1
		BEGIN
			UPDATE Item_Factura
			SET item_cantidad = item_cantidad - @DIFERENCIA
			WHERE item_numero = @NUMERO
			AND item_sucursal = @SUCURSAL
			AND item_tipo = @TIPO
			AND item_producto = @PRODUCTO
		END
			FETCH NEXT FROM C_ITEM_FACTURA INTO @NUMERO, @TIPO, @SUCURSAL, @PRODUCTO, @DIFERENCIA
		END
		CLOSE C_ITEM_FACTURA
		DEALLOCATE C_ITEM_FACTURA
	END
END
GO

/*
EJERCICIO N°10
Hacer un trigger que ante el intento de borrar un artículo verifique que 
no exista
stock y si es así lo borre en caso contrario que emita un mensaje de 
error.
*/

CREATE TRIGGER ejercicio10 ON Producto INSTEAD OF DELETE
AS
BEGIN
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @STOCK DECIMAL(12, 2)

	DECLARE C_PRODUCTO CURSOR FOR
	SELECT prod_codigo FROM DELETED

	OPEN C_PRODUCTO
	FETCH NEXT FROM C_PRODUCTO INTO @PRODUCTO

	WHILE @@FETCH_STATUS = 0

	BEGIN
	SET @STOCK =
	(SELECT SUM(stoc_cantidad)
	 FROM STOCK
	 WHERE stoc_producto = @PRODUCTO
	 GROUP BY stoc_producto)

	 IF @STOCK <= 0
		DELETE FROM Producto WHERE prod_codigo = @PRODUCTO
	ELSE
	PRINT 'No se pudo borrar el producto ya que tiene stock'

	FETCH NEXT FROM C_PRODUCTO INTO @PRODUCTO
	END
	CLOSE C_PRODUCTO
	DEALLOCATE C_PRODUCTO
END
GO

/* 11 - Cree el/los objetos de base de datos necesarios para que dado un código de
empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
indirectamente). Solo contar aquellos empleados (directos o indirectos) que
tengan un código mayor que su jefe directo.*/

CREATE FUNCTION ejercicio11(@JEFE numeric(6))
RETURNS INT
AS
BEGIN
	DECLARE @CANTIDAD INT
	DECLARE @EMPLEADO NUMERIC(6)

	SET @CANTIDAD = 
	(SELECT
	 COUNT(*)
	 FROM Empleado
	 WHERE empl_jefe = @JEFE
	 AND empl_codigo > @JEFE)

	 DECLARE C_INDIRECTOS CURSOR FOR
	 SELECT
	 empl_codigo
	 FROM Empleado
	 WHERE empl_jefe = @JEFE

	 OPEN C_INDIRECTOS

	 FETCH NEXT FROM C_INDIRECTOS INTO @EMPLEADO
	 WHILE @@FETCH_STATUS = 0
	 BEGIN
		SET @CANTIDAD = @CANTIDAD + dbo.ejercicio11(@EMPLEADO) -->indirectos
	 FETCH NEXT FROM C_INDIRECTOS INTO @EMPLEADO
	 END
	 CLOSE C_INDIRECTOS
	 DEALLOCATE C_INDIRECTOS
	 RETURN @CANTIDAD
END
GO

/* 12 - Cree el/los objetos de base de datos necesarios para que nunca un producto
pueda ser compuesto por sí mismo. Se sabe que en la actualidad dicha regla se
cumple y que la base de datos es accedida por n aplicaciones de diferentes tipos
y tecnologías. No se conoce la cantidad de niveles de composición existentes.*/

CREATE FUNCTION CompuestoPor(@PRODUCTO CHAR(8), @COMPONENTE CHAR(8))
RETURNS INT
AS
BEGIN
	DECLARE @CAMPO CHAR(8)

	IF(@PRODUCTO = @COMPONENTE) RETURN 1

	DECLARE C_COMPONENTES CURSOR FOR
	(SELECT
	 comp_componente
	 FROM Composicion
	 WHERE comp_producto = @PRODUCTO)

	 OPEN C_COMPONENTES
	 FETCH NEXT FROM C_COMPONENTES INTO @CAMPO
	 WHILE @@FETCH_STATUS = 0
	 BEGIN
		IF(dbo.CompuestoPor(@PRODUCTO, @CAMPO) = 1)
		RETURN 1
		FETCH NEXT FROM C_COMPONENTES INTO @CAMPO
	 END
	 CLOSE C_COMPONENTES
	 DEALLOCATE C_COMPONENTES
	 RETURN 0
END
GO

CREATE TRIGGER ejercicio12 ON COMPOSICION AFTER INSERT, UPDATE
AS
BEGIN
	IF((SELECT
	   COUNT(*)
	   FROM inserted
	   WHERE dbo.CompuestoPor(comp_producto, comp_componente) = 1) > 0)
	   ROLLBACK
END
GO

/* 13 - Cree el/los objetos de base de datos necesarios para implantar la siguiente regla:
“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de
sus empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha
regla se cumple y que la base de datos es accedida por n aplicaciones de
diferentes tipos y tecnologías*/

CREATE FUNCTION ejercicio13Func(@JEFE NUMERIC(6, 0))
RETURNS DECIMAL(12, 2)
AS
BEGIN
	DECLARE @SueldoEmpl DECIMAL(12, 2)
	DECLARE @JEFE_AUX NUMERIC(6,0)
	
	IF NOT EXISTS
		(SELECT
		 *
		 FROM Empleado
		where empl_jefe = @JEFE)
	 BEGIN
		 SET @SueldoEmpl = 0
		 RETURN @SueldoEmpl
	 END

	 SET @SueldoEmpl = 
		(SELECT
		 SUM(empl_salario)
		 FROM Empleado
		 WHERE empl_jefe = @JEFE
		 ) --> Sueldo de empleados directos

	--Indirectos:
	DECLARE C_INDIRECTOS CURSOR FOR
	SELECT
	E.empl_codigo
	FROM Empleado E
	WHERE empl_jefe = @JEFE

	OPEN C_INDIRECTOS
	FETCH NEXT FROM C_INDIRECTOS INTO @JEFE_AUX
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @SueldoEmpl = @SueldoEmpl + dbo.ejercicio13Func(@JEFE_AUX)

		FETCH NEXT FROM C_INDIRECTOS INTO @JEFE_AUX
	END

	CLOSE C_INDIRECTOS
	DEALLOCATE C_INDIRECTOS
	RETURN @SueldoEmpl
END
GO

CREATE TRIGGER ejercicio13 ON Empleado AFTER INSERT, UPDATE
AS
BEGIN
	IF EXISTS
	(SELECT J.empl_codigo
	FROM inserted J
	WHERE J.empl_salario > (dbo.ejercicio13Func(J.empl_codigo) * 0.2)
	)
	BEGIN
	PRINT 'UN JEFE NO PUEDE SUPERAR EL 20% DE LA SUMA DEL SUELDO TOTAL DE SUS EMPELADOS'
	ROLLBACK
	END
END
GO

/* 14 - Agregar el/los objetos necesarios para que si un cliente compra un producto
compuesto a un precio menor que la suma de los precios de sus componentes
que imprima la fecha, que cliente, que productos y a qué precio se realizó la
compra. No se deberá permitir que dicho precio sea menor a la mitad de la suma
de los componentes.*/
CREATE FUNCTION EsProductoCompuesto(@PRODUCTO CHAR(8))
RETURNS BIT
AS
BEGIN
	DECLARE @esCompuesto BIT = 0

	IF EXISTS
	(SELECT *
	 FROM Composicion
	 WHERE comp_producto = @PRODUCTO)
	 BEGIN
	 SET @esCompuesto = 1
	 END
	 RETURN @esCompuesto
END
GO

CREATE FUNCTION precioCompuesto(@PRODUCTO CHAR(8))
RETURNS DECIMAL(12, 2)
AS
BEGIN
	DECLARE @PRECIO DECIMAL(12, 2) = 0
	DECLARE @COMPONENTE CHAR(8)
	DECLARE @CANTIDAD DECIMAL(12, 2)

	IF dbo.EsProductoCompuesto(@PRODUCTO) = 1

	DECLARE C_COMPONENTES CURSOR FOR
	SELECT
	comp_componente,
	comp_cantidad
	FROM Composicion
	WHERE comp_producto = @PRODUCTO

	OPEN C_COMPONENTES
	FETCH NEXT FROM C_COMPONENTES INTO @COMPONENTE, @CANTIDAD
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @PRECIO = @PRECIO + @CANTIDAD * (SELECT prod_precio
											 FROM Producto
											 WHERE prod_codigo = @COMPONENTE)

	FETCH NEXT FROM C_COMPONENTES INTO @COMPONENTE, @CANTIDAD
	END
	CLOSE C_COMPONENTES
	DEALLOCATE C_COMPONENTES
	RETURN @PRECIO
END
GO


CREATE TRIGGER ejercicio14 ON Item_factura INSTEAD OF INSERT
AS
BEGIN
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)
	DECLARE @PRODUCTO_a_insertar CHAR(8)
	DECLARE @PRECIO DECIMAL(12, 2)
	DECLARE @FECHA SMALLDATETIME
	DECLARE @CLIENTE CHAR(6)

	DECLARE C_COMPRA CURSOR FOR
	SELECT
	item_tipo,
	item_sucursal,
	item_numero,
	item_producto,
	item_precio
	FROM inserted

	OPEN C_COMPRA
	FETCH NEXT FROM C_COMPRA INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO_a_insertar, @PRECIO
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @CLIENTE = 
		(SELECT fact_cliente
		 FROM Factura
		 WHERE fact_tipo + fact_sucursal + fact_numero = @TIPO + @SUCURSAL + @NUMERO)

		SET @FECHA =
		(SELECT fact_fecha
		 FROM Factura
		 WHERE fact_tipo + fact_sucursal + fact_numero = @TIPO + @SUCURSAL + @NUMERO)

		IF dbo.EsProductoCompuesto(@PRODUCTO_a_insertar) = 1
		BEGIN
			IF @PRECIO > dbo.precioCompuesto(@PRODUCTO_a_insertar)/2
			BEGIN
				INSERT INTO Item_Factura
				SELECT * 
				FROM inserted
				WHERE item_producto = @PRODUCTO_a_insertar
			END
			ELSE
			PRINT 'EL PRECIO PRODUCTO NO PUEDE SER MENOR A LA MITAD DE LA SUMA DE SUS PRODUCTOS-COMPONENTES'
		END
		FETCH NEXT FROM C_COMPRA INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO_a_insertar, @PRECIO
	END
END
GO

	/* 15 - Cree el/los objetos de base de datos necesarios para que el objeto principal
reciba un producto como parametro y retorne el precio del mismo.

Se debe prever que el precio de los productos compuestos sera la sumatoria de
los componentes del mismo multiplicado por sus respectivas cantidades.

No se conocen los nivles de anidamiento posibles de los productos. Se asegura que
nunca un producto esta compuesto por si mismo a ningun nivel. 

El objeto principal debe poder ser utilizado como filtro en el where de una sentencia
select.*/

CREATE FUNCTION ejercicio15(@PRODUCTO CHAR(8))
RETURNS DECIMAL(12, 2)
AS
BEGIN
	DECLARE @PRECIOPROD DECIMAL(12, 2)
	DECLARE @COMPONENTE CHAR(8)
	DECLARE @CANTIDAD INT

	IF NOT EXISTS(SELECT * FROM Composicion WHERE comp_producto = @PRODUCTO)
		BEGIN
			SET @PRECIOPROD = (SELECT prod_precio
								FROM Producto
								WHERE prod_codigo = @PRODUCTO)
		END
	ELSE
	BEGIN
		DECLARE C_COMPONENTES CURSOR FOR SELECT comp_componente, comp_cantidad
										  FROM Composicion
										  WHERE comp_producto = @PRODUCTO
	OPEN C_COMPONENTES
	FETCH NEXT FROM C_COMPONENTES INTO @COMPONENTE, @CANTIDAD
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @PRECIOPROD = @PRECIOPROD + @CANTIDAD * (SELECT prod_precio
													  FROM Producto
												     WHERE prod_codigo = @COMPONENTE)
		FETCH NEXT FROM C_COMPONENTES INTO @COMPONENTE, @CANTIDAD
	END
	CLOSE C_COMPONENTES
	DEALLOCATE C_COMPONENTES
	END
	RETURN @PRECIOPROD
END
GO

/* 16 - Desarrolle el/los elementos de base de datos necesarios para que ante una venta
automaticamante 

se descuenten del stock los articulos vendidos. 

Se descontaran del deposito que mas producto poseea 

y se supone que el stock se almacena tanto de productos simples como compuestos (si se acaba el stock de los
compuestos no se arman combos)

En caso que no alcance el stock de un deposito se descontara del siguiente y asi hasta agotar los depositos posibles. }

En ultima instancia se dejara stock negativo en el ultimo deposito que se desconto.*/

CREATE PROCEDURE SP_EJ16(@PRODUCTO CHAR(8), @CANTIDAD DECIMAL(12, 2))
AS
BEGIN
	DECLARE @DEPOSITO CHAR(2)
	DECLARE @CANTIDAD_DEPOSITO DECIMAL(12, 2)
	WHILE @CANTIDAD > 0
	BEGIN
		SELECT
		TOP 1 @DEPOSITO = stoc_deposito,
		@CANTIDAD_DEPOSITO = stoc_cantidad
		FROM STOCK
		WHERE stoc_producto = @PRODUCTO
		ORDER BY stoc_cantidad DESC

	IF(@CANTIDAD_DEPOSITO >= @CANTIDAD) OR (@CANTIDAD_DEPOSITO <= 0)
	BEGIN
		UPDATE STOCK
		SET stoc_cantidad = stoc_cantidad - @CANTIDAD
		WHERE stoc_producto = @PRODUCTO AND stoc_deposito = @DEPOSITO

		SET @CANTIDAD = 0
	END
	ELSE
	BEGIN
		UPDATE STOCK
		SET stoc_cantidad = 0
		WHERE stoc_producto = @PRODUCTO AND stoc_deposito = @DEPOSITO

		SET @CANTIDAD = @CANTIDAD - @CANTIDAD_DEPOSITO
	END
	END
END
GO


CREATE TRIGGER ej16 ON Item_Factura FOR INSERT, UPDATE
AS
BEGIN
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @CANTIDAD DECIMAL(12, 2)

	DECLARE C_ITEMS CURSOR FOR SELECT
							   I.item_producto,
							   (I.item_cantidad - ISNULL(D.item_cantidad, 0))
							   FROM inserted I
							   LEFT JOIN deleted D ON I.item_tipo + I.item_sucursal + I.item_numero = D.item_tipo + D.item_sucursal + D.item_numero
							   AND I.item_producto = D.item_producto
							   WHERE (I.item_cantidad - ISNULL(D.item_cantidad, 0)) > 0

	IF EXISTS (SELECT * FROM inserted I WHERE NOT EXISTS (SELECT * FROM STOCK S WHERE S.stoc_producto = I.item_producto))
	BEGIN
		ROLLBACK
		RETURN
	END

	OPEN C_ITEMS
	FETCH NEXT FROM C_ITEMS INTO @PRODUCTO, @CANTIDAD
	WHILE @@FETCH_STATUS = 0
	BEGIN

	EXEC SP_EJ16(@PRODUCTO, @CANTIDAD)

	FETCH NEXT FROM C_ITEMS INTO @PRODUCTO, @CANTIDAD
	END
	CLOSE C_ITEMS
	DEALLOCATE C_ITEMS
END
GO

/* 17 - Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto
que se debe almacenar en el deposito

y que el stock maximo es la maxima
cantidad de ese producto en ese deposito,

cree el/los objetos de base de datos
necesarios para que dicha regla de negocio se cumpla automaticamente.

No se conoce la forma de acceso a los datos ni el procedimiento por el cual se
incrementa o descuenta stock*/

CREATE TRIGGER ejercicio17 ON STOCK FOR INSERT,UPDATE
AS
BEGIN
	DECLARE @CANTIDAD DECIMAL(12, 2)
	DECLARE @MINIMO DECIMAL(12, 2)
	DECLARE @MAXIMO DECIMAL(12, 2)
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @DEPOSITO CHAR(2)

	DECLARE C_INSERTED CURSOR FOR SELECT
								  stoc_cantidad,
								  stoc_punto_reposicion,
								  stoc_stock_maximo,
								  stoc_producto, stoc_deposito
								  FROM inserted
	
	OPEN C_INSERTED
	FETCH NEXT FROM C_INSERTED INTO @CANTIDAD, @MINIMO, @MAXIMO, @PRODUCTO, @DEPOSITO
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF @CANTIDAD > @MAXIMO
		BEGIN
			PRINT 'Se esta excediendo la cantidad maxima del producto ' + @PRODUCTO + ' en el deposito ' + @DEPOSITO + ' por ' + STR(@CANTIDAD - @MAXIMO) + ' unidades. No se puede realizar la operacion'
			ROLLBACK
		END
	ELSE IF @CANTIDAD < @MINIMO
	BEGIN
		PRINT 'El Producto ' + @PRODUCTO + ' en el deposito ' + @DEPOSITO + ' se encuentra por debajo el minimo. Reponer!'
	END
	FETCH NEXT FROM C_INSERTED INTO @CANTIDAD, @MINIMO, @MAXIMO, @PRODUCTO, @DEPOSITO
	END
	CLOSE C_INSERTED
	DEALLOCATE C_INSERTED
END
GO

/* 18 - Sabiendo que el limite de credito de un cliente es el monto maximo que se le
puede facturar mensualmente, cree el/los objetos de base de datos necesarios
para que dicha regla de negocio se cumpla automaticamente. No se conoce la
forma de acceso a los datos ni el procedimiento por el cual se emiten las facturas*/

CREATE TRIGGER ejercicio18 ON Factura FOR INSERT
AS
BEGIN
	DECLARE @CLIENTE CHAR(6)
	DECLARE @CREDITO DECIMAL(12, 2)
	DECLARE @TOTALCOMPRA DECIMAL(12, 2)
	
	DECLARE C_FACTURACION CURSOR FOR SELECT
									 fact_cliente,
									 clie_limite_credito,
									 SUM(fact_total)
									 FROM Factura
									 JOIN Cliente ON fact_cliente = clie_codigo
									 GROUP BY fact_cliente, clie_limite_credito
	OPEN C_FACTURACION
	FETCH NEXT FROM C_FACTURACION INTO @CLIENTE, @CREDITO, @TOTALCOMPRA
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @MontoAcumuladoMes DECIMAL(12, 2)
		SET @MontoAcumuladoMes =(SELECT SUM(fact_total) FROM Factura WHERE fact_cliente = @CLIENTE AND MONTH(fact_fecha) = (SELECT
																													 TOP 1 MONTH(fact_fecha)
																													 FROM Factura
																													 ORDER BY fact_fecha DESC))

	IF (@MontoAcumuladoMes + @TOTALCOMPRA > @CREDITO)
	BEGIN
		PRINT 'No se puede realizar la compra'
		ROLLBACK
	END
	FETCH NEXT FROM C_FACTURACION INTO @CLIENTE, @CREDITO, @TOTALCOMPRA
	END
	CLOSE C_FACTURACION
	DEALLOCATE C_FACTURACION
END
GO

/* 19 - Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente
regla de negocio automáticamente “Ningún jefe puede tener menos de 5 años de
antigüedad y tampoco puede tener más del 50% del personal a su cargo
(contando directos e indirectos) a excepción del gerente general”. Se sabe que en
la actualidad la regla se cumple y existe un único gerente general.*/

CREATE TRIGGER ej_19 ON Empleado FOR INSERT, UPDATE
AS
BEGIN
	DECLARE @JEFE NUMERIC(6)
	DECLARE @INGRESO SMALLDATETIME

	DECLARE C_JEFES CURSOR FOR SELECT
							   empl_codigo
							   FROM inserted

	OPEN C_JEFES
	FETCH NEXT FROM C_JEFES INTO @JEFE, @INGRESO
	WHILE @@FETCH_STATUS = 0
	BEGIN
	IF(dbo.CalculoAntiguedad(@JEFE) < 5)
	BEGIN
	PRINT 'NO PUEDE TENER MENOS DE 5 AÑOS DE ANTIGUEDAD'
	ROLLBACK
	END
	IF(dbo.CantidadDePersonal(@JEFE) > (SELECT
										COUNT(*) * 0.5
										FROM Empleado))
	BEGIN
	PRINT 'NO PUEDE TENER MAS DE LA MITAD DE LA EMPRESA DE EMPLEADOS'
	ROLLBACK
	END
	FETCH NEXT FROM C_JEFES INTO @JEFE, @INGRESO
	END
	CLOSE C_JEFES
	DEALLOCATE C_JEFES
END
GO

CREATE FUNCTION dbo.CalculoAntiguedad(@EMPLEADO NUMERIC(6))
RETURNS INT
AS
BEGIN
	DECLARE @ANIOS_ANTIGUEDAD INT
	DECLARE @ANIO_ACTUAL INT
	SET @ANIO_ACTUAL = (SELECT TOP 1 YEAR(fact_fecha) FROM Factura ORDER BY fact_fecha DESC)
	SET @ANIOS_ANTIGUEDAD = @ANIO_ACTUAL -(SELECT	
											 YEAR(empl_ingreso)
											 FROM Empleado
											 WHERE empl_codigo = @EMPLEADO)
	RETURN @ANIOS_ANTIGUEDAD
END
GO

CREATE FUNCTION CantidadDePersonal(@JEFE NUMERIC(6))
RETURNS INT
AS
BEGIN
	DECLARE @CANTIDAD_EMPLEADOS INT
	DECLARE @EMPLEADO_DIRECTO NUMERIC(6)

	SET @CANTIDAD_EMPLEADOS = (SELECT ISNULL(COUNT(*), 0) FROM Empleado WHERE empl_jefe = @JEFE)

	DECLARE C_EMPLEADOS CURSOR FOR SELECT
								   empl_codigo
								   FROM Empleado
								   WHERE empl_jefe = @JEFE
	
	OPEN C_EMPLEADOS
	FETCH NEXT FROM C_EMPLEADOS INTO @EMPLEADO_DIRECTO
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @CANTIDAD_EMPLEADOS = @CANTIDAD_EMPLEADOS + dbo.CantidadDePersonal(@EMPLEADO_DIRECTO)
	FETCH NEXT FROM C_EMPLEADOS INTO @EMPLEADO_DIRECTO
	END
	CLOSE C_EMPLEADOS
	DEALLOCATE C_EMPLEADOS
	RETURN @CANTIDAD_EMPLEADOS
END
GO

/* 20 - Crear el/los objeto/s necesarios para mantener actualizadas las comisiones del
vendedor.
El cálculo de la comisión está dado por el 5% de la venta total efectuada por ese
vendedor en ese mes, más un 3% adicional en caso de que ese vendedor haya
vendido por lo menos 50 productos distintos en el mes.*/

CREATE TRIGGER ejercicio20 ON Empleado FOR INSERT
AS
BEGIN
	DECLARE @COMISION DECIMAL(12, 2)
	DECLARE @VENDEDOR NUMERIC(6)
	DECLARE @FECHA SMALLDATETIME

	DECLARE C_FACTURAS CURSOR FOR SELECT
								  fact_vendedor,
								  fact_fecha
								  FROM inserted
	OPEN C_FACTURAS 
	FETCH NEXT FROM C_FACTURAS INTO @VENDEDOR, @FECHA
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @COMISION = (SELECT
					 SUM(item_cantidad * item_precio) * (0.05 + CASE WHEN COUNT(DISTINCT item_producto) > 50 THEN 0.03
														 	ELSE 0
															END)
					FROM Item_Factura
					JOIN Factura ON item_tipo = fact_tipo AND item_sucursal = fact_sucursal AND item_numero = fact_numero
					WHERE fact_vendedor = @VENDEDOR
					AND YEAR(fact_fecha) = YEAR(@FECHA)
					AND MONTH(fact_fecha) = MONTH(@FECHA))
	UPDATE Empleado 
	SET empl_comision = @COMISION
	WHERE empl_codigo = @VENDEDOR
	FETCH NEXT FROM C_FACTURAS INTO @VENDEDOR, @FECHA
	END
	CLOSE C_FACTURAS
	DEALLOCATE C_FACTURAS
END
GO

/* 21 - Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que en una factura no puede contener productos de
diferentes familias. En caso de que esto ocurra no debe grabarse esa factura y
debe emitirse un error en pantalla.*/

CREATE TRIGGER ejercicio_21 ON Factura FOR INSERT
AS
BEGIN
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)

	IF EXISTS(SELECT
			  fact_tipo+fact_sucursal+fact_numero
			  FROM inserted
			  JOIN Item_Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
			  JOIN Producto ON prod_codigo = item_producto
			  WHERE COUNT(DISTINCT prod_familia) <> 1)
	BEGIN
		DECLARE C_FACTURAS CURSOR FOR SELECT
									  fact_tipo, fact_sucursal, fact_numero
									  FROM inserted
		OPEN C_FACTURAS
		FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO
		WHILE @@FETCH_STATUS = 0
		BEGIN
			DELETE FROM Item_Factura WHERE item_tipo + item_sucursal + item_numero = @TIPO + @SUCURSAL + @NUMERO
			DELETE FROM Factura WHERE fact_tipo + fact_sucursal + fact_numero = @TIPO + @SUCURSAL + @NUMERO
		FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO				
		END
		CLOSE C_FACTURAS
		DEALLOCATE C_FACTURAS
		PRINT 'NO PUEDE FACTURAR PRODUCTOS DE LA MISMA FAMILIA'
		ROLLBACK
	END
END
GO

/* 22 - Se requiere recategorizar los rubros de productos, de forma tal que nigun rubro
tenga más de 20 productos asignados, si un rubro tiene más de 20 productos
asignados se deberan distribuir en otros rubros que no tengan mas de 20
productos y si no entran se debra crear un nuevo rubro en la misma familia con
la descirpción “RUBRO REASIGNADO”, cree el/los objetos de base de datos
necesarios para que dicha regla de negocio quede implementada.*/

CREATE PROCEDURE ej22
AS
BEGIN
	DECLARE @RUBRO CHAR(4)
	DECLARE @cantProductosRubro INT
	DECLARE C_RUBROS CURSOR FOR SELECT
								rubr_id,
								COUNT(*)
								FROM Rubro
								JOIN Producto ON prod_rubro = rubr_id
								GROUP BY rubr_id
								HAVING COUNT(*) > 20
	OPEN C_RUBROS
	FETCH NEXT FROM C_RUBROS INTO @RUBRO, @cantProductosRubro
	WHILE @@FETCH_STATUS = 0
	BEGIN

	DECLARE @PRODUCTO CHAR(8)
	DECLARE @NUEVO_RUBRO CHAR(4)
	DECLARE C_PRODUCTOS CURSOR FOR SELECT
								   prod_codigo
								   FROM Producto
								   WHERE prod_rubro = @RUBRO
	OPEN C_PRODUCTOS
	FETCH NEXT FROM C_PRODUCTOS INTO @PRODUCTO
	WHILE @@FETCH_STATUS = 0 OR @CantProductosRubro < 21
	BEGIN
		SET @NUEVO_RUBRO = (SELECT TOP 1 rubr_id
							FROM Rubro
							JOIN Producto ON rubr_id = prod_rubro
							GROUP BY rubr_id
							HAVING COUNT(*) < 20
							ORDER BY COUNT(*) ASC)

		IF(@NUEVO_RUBRO IS NOT NULL)
		BEGIN

		UPDATE Producto
		SET prod_rubro = @NUEVO_RUBRO
		where prod_codigo = @PRODUCTO

		END
		ELSE
		BEGIN
		IF NOT EXISTS(SELECT rubr_id FROM Rubro WHERE rubr_detalle = 'RUBRO REASIGNADO')
		INSERT INTO Rubro (rubr_id, rubr_detalle) VALUES ('xx', 'RUBRO REASIGNADO')

		UPDATE Producto
		SET prod_rubro = (SELECT rubr_id FROM Rubro WHERE rubr_detalle = 'Rubro reasignado')
		END
	SET @cantProductosRubro -= 1
	FETCH NEXT FROM C_PRODUCTOS INTO @PRODUCTO
	END
	CLOSE C_PRODUCTOS
	DEALLOCATE C_PRODUCTOS


	FETCH NEXT FROM C_RUBROS INTO @RUBRO, @cantProductosRubro
	END
	CLOSE C_RUBROS
	DEALLOCATE C_RUBROS
END
GO

/* 23 - Desarrolle el/los elementos de base de datos necesarios para que ante una venta
automaticamante se controle que en una misma factura no puedan venderse más
de dos productos con composición. Si esto ocurre debera rechazarse la factura.*/

CREATE TRIGGER ejercicio23 ON Factura FOR INSERT
AS
BEGIN
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)

	DECLARE C_FACTURAS CURSOR FOR SELECT
								  fact_tipo,
								  fact_sucursal,
								  fact_numero
								  From inserted
	OPEN C_FACTURAS
	FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO
	WHILE @@FETCH_STATUS = 0
	BEGIN
	IF((SELECT COUNT(*)
		FROM Item_Factura
		WHERE item_tipo + item_sucursal + item_numero = @TIPO + @SUCURSAL + @NUMERO
		AND dbo.esCompuestoo(item_producto)) > 2)
	BEGIN
		DELETE FROM Item_Factura WHERE item_tipo + item_sucursal + item_numero = @TIPO + @SUCURSAL + @NUMERO
		DELETE FROM Factura WHERE fact_tipo + fact_sucursal + fact_numero = @TIPO + @SUCURSAL + @NUMERO
		PRINT 'FACTURA RECHAZADA'
		ROLLBACK
	END
	FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO
	END
	CLOSE C_FACTURAS
	DEALLOCATE C_FACTURAS
END
GO

CREATE FUNCTION dbo.esCompuestoo(@PRODUCTO CHAR(8))
RETURNS BIT
AS
BEGIN
	DECLARE @ESCOMPUESTO BIT = 0
	IF EXISTS(SELECT * FROM Composicion WHERE comp_producto = @PRODUCTO)
	BEGIN
	SET @ESCOMPUESTO = 1
	END
	RETURN @ESCOMPUESTO
END
GO

/* 24 - Se requiere recategorizar los encargados asignados a los depositos. 

Para ello cree el o los objetos de bases de datos necesarios que lo resueva,

teniendo en cuenta que un deposito no puede tener como encargado un empleado que
pertenezca a un departamento que no sea de la misma zona que el deposito,

zona_dep = zona_depo

si esto ocurre a dicho deposito debera asignársele el empleado con menos
depositos asignados que pertenezca a un departamento de esa zona.*/

CREATE PROCEDURE ejercicio24
AS
BEGIN
	DECLARE @DEPOSITO CHAR(2)
	DECLARE @ENCARGADO NUMERIC(6)
	DECLARE @ZONA CHAR(3)

	DECLARE C_DEPOSITO CURSOR FOR (SELECT	
								  depo_codigo,
								  depo_encargado,
								  depo_zona
								  FROM DEPOSITO
								  JOIN Empleado ON depo_encargado = empl_codigo
								  JOIN Departamento ON depa_codigo = empl_departamento
								  WHERE depo_zona <> depa_zona)
	OPEN C_DEPOSITO
	FETCH NEXT FROM C_DEPOSITO INTO @DEPOSITO, @ENCARGADO, @ZONA
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @ENCARGADO = (SELECT TOP 1 empl_codigo
					  FROM Empleado
					  JOIN Departamento ON depa_codigo = empl_departamento
					  JOIN DEPOSITO on depo_encargado = empl_codigo
					  WHERE depa_zona = @ZONA
					  GROUP BY empl_codigo
					  ORDER BY COUNT(*) ASC)
	UPDATE DEPOSITO
	SET depo_encargado = @ENCARGADO
	WHERE depo_codigo = @DEPOSITO

	FETCH NEXT FROM C_DEPOSITO INTO @DEPOSITO, @ENCARGADO, @ZONA
	END
	CLOSE C_DEPOSITO
	DEALLOCATE C_DEPOSITO
END
GO

/* 25 - Desarrolle el/los elementos de base de datos necesarios para que no se permita
que la composición de los productos sea recursiva, o sea, que si el producto A
compone al producto B, dicho producto B no pueda ser compuesto por el
producto A, hoy la regla se cumple.*/

CREATE TRIGGER ejercicio25 ON Composicion FOR INSERT
AS
BEGIN
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @COMPONENTE CHAR(8)

	DECLARE C_COMPUESTO CURSOR FOR SELECT
								   comp_producto,
								   comp_componente
								   FROM inserted

	OPEN C_COMPUESTO 
	FETCH NEXT FROM C_COMPUESTO INTO @PRODUCTO, @COMPONENTE
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT comp_producto FROM Composicion WHERE comp_producto = @COMPONENTE AND comp_componente = @PRODUCTO)
		BEGIN
		PRINT 'ERROR'
		ROLLBACK
		END
	FETCH NEXT FROM C_COMPUESTO INTO @PRODUCTO, @COMPONENTE
	END
	CLOSE C_COMPUESTO
	DEALLOCATE C_COMPUESTO
END
GO

/* 26 - Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que 

una factura no puede contener productos que sean componentes de otros productos. 

En caso de que esto ocurra no debe grabarse esa factura y debe emitirse un error en pantalla.*/

CREATE TRIGGER ejericicio26 ON Item_Factura FOR INSERT
AS
BEGIN
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)

	DECLARE C_ITEMS CURSOR FOR SELECT
							   item_tipo,
							   item_sucursal,
							   item_numero,
							   item_producto
							   FROM inserted
							   JOIN Composicion ON item_producto = comp_producto
							  
	OPEN C_ITEMS
	FETCH NEXT FROM C_ITEMS INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT * FROM Composicion WHERE comp_componente = @PRODUCTO)
		BEGIN
		DELETE FROM Item_Factura WHERE item_tipo+item_sucursal+item_numero = @TIPO+@SUCURSAL+@NUMERO
		DELETE FROM Factura WHERE fact_tipo+fact_sucursal+fact_numero = @TIPO+@SUCURSAL+@NUMERO
		PRINT 'ERROR'
		ROLLBACK
		END
	FETCH NEXT FROM C_ITEMS INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO
	END
	CLOSE C_ITEMS
	DEALLOCATE C_ITEMS
END
GO

/* 27 - Se requiere reasignar los encargados de stock de los diferentes depósitos. 

Para ello se solicita que realice el o los objetos de base de datos necesarios para
asignar a cada uno de los depósitos el encargado que le corresponda,

entendiendo que el encargado que le corresponde es cualquier empleado que no
es jefe		y que no es vendedor, o sea, que no está asignado a ningun cliente, 

se deberán ir asignando tratando de que un empleado solo tenga un deposito
asignado, en caso de no poder se irán aumentando la cantidad de depósitos
progresivamente para cada empleado. */

CREATE FUNCTION reasignar(@depo_encargado CHAR(6))
RETURNS BIT
AS
BEGIN
	DECLARE @RETORNO BIT = 0
	
	IF EXISTS(SELECT depo_encargado
			  FROM DEPOSITO
			  WHERE depo_encargado = @depo_encargado 
			  GROUP BY depo_encargado
			  HAVING depo_encargado IN (SELECT empl_jefe FROM Empleado WHERE empl_jefe IS NOT NULL)
			  AND depo_encargado IN (SELECT clie_vendedor FROM Cliente WHERE clie_vendedor IS NOT NULL))
	BEGIN
	SET @RETORNO = 1
	END
	RETURN @RETORNO			
END
GO


CREATE PROCEDURE ejercicio27
AS
BEGIN
	DECLARE @DEPO CHAR(2)
	
	DECLARE C_DEPOSITO CURSOR FOR (SELECT
								  depo_codigo
								  FROM DEPOSITO
								  where dbo.reasignar(depo_encargado) = 1)
	OPEN C_DEPOSITO
	FETCH NEXT FROM C_DEPOSITO INTO @DEPO
	WHILE @@FETCH_STATUS = 0
	BEGIN
	UPDATE DEPOSITO
	SET depo_encargado = (SELECT TOP 1 empl_codigo FROM Empleado JOIN DEPOSITO ON depo_encargado = empl_codigo
																	WHERE dbo.reasignar(empl_codigo) = 0
																	GROUP BY empl_codigo
																	ORDER BY COUNT(*) ASC)

	FETCH NEXT FROM C_DEPOSITO INTO @DEPO
	END
	CLOSE C_DEPOSITO
	DEALLOCATE C_DEPOSITO
				
END
GO


/* 28 - Se requiere reasignar los vendedores a los clientes. Para ello se solicita que
realice el o los objetos de base de datos necesarios para asignar a cada uno de los
clientes el vendedor que le corresponda, entendiendo que el vendedor que le
corresponde es aquel que le vendió más facturas a ese cliente, si en particular un
cliente no tiene facturas compradas se le deberá asignar el vendedor con más
venta de la empresa, o sea, el que en monto haya vendido más.*/

CREATE PROCEDURE ejercicio28
AS
BEGIN
	DECLARE @CLIENTE CHAR(6)
	DECLARE @VENDEDOR NUMERIC(6)

	DECLARE C_CLIENTES CURSOR FOR SELECT
								  clie_codigo,
								  clie_vendedor
								  FROM Cliente
	OPEN C_CLIENTES
	FETCH NEXT FROM C_CLIENTES INTO @CLIENTE, @VENDEDOR
	WHILE @@FETCH_STATUS = 0
	BEGIN
	IF EXISTS(SELECT * FROM Factura WHERE fact_cliente = @CLIENTE)
	BEGIN
		SET @VENDEDOR = (SELECT TOP 1 fact_vendedor
						 FROM Factura
						 WHERE fact_cliente = @CLIENTE
						 GROUP BY fact_cliente, fact_vendedor
						 ORDER BY COUNT(fact_vendedor))
		UPDATE Cliente
		SET clie_vendedor = @VENDEDOR
		WHERE clie_codigo = @CLIENTE
	END
	ELSE
	BEGIN
		SET @VENDEDOR = (SELECT TOP 1 fact_vendedor
						 FROM Factura
						 GROUP BY fact_vendedor
						 ORDER BY SUM(fact_total) DESC)
	UPDATE Cliente
	SET clie_vendedor = @VENDEDOR
	WHERE clie_codigo = @CLIENTE
	END
	FETCH NEXT FROM C_CLIENTES INTO @CLIENTE, @VENDEDOR
	END
	CLOSE C_CLIENTES
	DEALLOCATE C_CLIENTES
END
GO

/* 29 - Desarrolle el/los elementos de base de datos necesarios para que se cumpla
automaticamente la regla de que una factura no puede contener productos que
sean componentes de diferentes productos. En caso de que esto ocurra no debe
grabarse esa factura y debe emitirse un error en pantalla.*/

CREATE TRIGGER ejercicio29 ON Item_Factura INSTEAD OF INSERT
AS
BEGIN

	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)
	DECLARE @PRODUCTO CHAR(8)
	DECLARE @CANTIDAD DECIMAL(12, 2)
	DECLARE @PRECIO DECIMAL(12, 2)

	DECLARE C_FACTURAS CURSOR FOR SELECT
								  *
								  FROM inserted
	OPEN C_FACTURAS
	FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO, @CANTIDAD, @PRECIO
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF EXISTS(SELECT * FROM Composicion WHERE comp_componente = @PRODUCTO)
		BEGIN
		DELETE FROM Factura WHERE fact_tipo+fact_sucursal+fact_numero = @tipo+@sucursal+@numero
		DELETE FROM Item_Factura WHERE item_tipo+item_sucursal+item_numero = @tipo+@sucursal+@numero
		PRINT 'ERROR NO SE PUEDE ETC'
		ROLLBACK
		END
		ELSE
		BEGIN
			INSERT INTO Item_Factura
			VALUES(@tipo,@sucursal,@numero,@producto,@cantidad,@precio)
		END
	FETCH NEXT FROM C_FACTURAS INTO @TIPO, @SUCURSAL, @NUMERO, @PRODUCTO, @CANTIDAD, @PRECIO
	END
	CLOSE C_FACTURAS
	DEALLOCATE C_FACTURAS
END
GO

/*30. Agregar el/los objetos necesarios para crear una regla por la cual un cliente no
pueda comprar más de 100 unidades en el mes de ningún producto, si esto
ocurre no se deberá ingresar la operación y se deberá emitir un mensaje “Se ha
superado el límite máximo de compra de un producto”. Se sabe que esta regla se
cumple y que las facturas no pueden ser modificadas.*/

CREATE TRIGGER ejercicio30 ON Item_Factura FOR INSERT
AS
BEGIN
	DECLARE @TOTAL_COMPRADO INT
	DECLARE @TIPO CHAR(1)
	DECLARE @SUCURSAL CHAR(4)
	DECLARE @NUMERO CHAR(8)
	DECLARE @CANTIDAD CHAR(8)

	DECLARE C_ITEMS CURSOR FOR SELECT
							   item_tipo,
							   item_sucursal,
							   item_numero,
							   item_cantidad
							   FROM inserted
	OPEN C_ITEMS
	FETCH NEXT FROM C_ITEMS INTO @TIPO, @SUCURSAL, @NUMERO, @CANTIDAD
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @TOTAL_COMPRADO = (SELECT SUM(item_cantidad)
								FROM Item_Factura
								JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = @TIPO + @SUCURSAL + @NUMERO
								WHERE MONTH(fact_fecha) = (SELECT TOP 1 MONTH(fact_fecha) FROM Factura ORDER BY fact_fecha DESC))
		IF(@TOTAL_COMPRADO + @CANTIDAD > 100)
		BEGIN
		DELETE FROM Item_Factura WHERE item_tipo+item_sucursal+item_numero = @tipo+@sucursal+@numero
		DELETE FROM Factura WHERE fact_tipo+fact_sucursal+fact_numero = @tipo+@sucursal+@numero
		PRINT 'SE HA SUPERADO EL LIMITE MAXIMO DE COMPRA DE UN PRODUCTO'
		ROLLBACK
		END
	FETCH NEXT FROM C_ITEMS INTO @TIPO, @SUCURSAL, @NUMERO, @CANTIDAD
	END
	CLOSE C_ITEMS
	DEALLOCATE C_ITEMS


END
GO

/*31. Desarrolle el o los objetos de base de datos necesarios, para que un jefe no pueda
tener más de 20 empleados a cargo, directa o indirectamente, si esto ocurre
debera asignarsele un jefe que cumpla esa condición, si no existe un jefe para
asignarle se le deberá colocar como jefe al gerente general que es aquel que no
tiene jefe.*/

CREATE FUNCTION cantidadEmpleados(@JEFE NUMERIC(6))
RETURNS INT
AS
BEGIN
	DECLARE @CANTIDAD INT = 0
	DECLARE @EMPLEADO_DIRECTO NUMERIC(6)

	IF NOT EXISTS (SELECT * FROM Empleado WHERE empl_jefe = @JEFE)
	BEGIN
	RETURN @CANTIDAD
	END

	DECLARE C_EMPLEADOS_DIRECTOS CURSOR FOR SELECT
											empl_codigo
											FROM Empleado
											WHERE empl_jefe = @JEFE

	SET @CANTIDAD = (SELECT COUNT(*)
					 FROM Empleado
					 WHERE empl_jefe = @JEFE)

	OPEN C_EMPLEADOS_DIRECTOS
	FETCH NEXT FROM C_EMPLEADOS_DIRECTOS INTO  @EMPLEADO_DIRECTO
	WHILE @@FETCH_STATUS = 0
	BEGIN
	SET @CANTIDAD = @CANTIDAD + dbo.cantidadEmpleados(@EMPLEADO_DIRECTO)
	FETCH NEXT FROM C_EMPLEADOS_DIRECTOS INTO  @EMPLEADO_DIRECTO
	END
	CLOSE C_EMPLEADOS_DIRECTOS
	DEALLOCATE C_EMPLEADOS_DIRECTOS
	RETURN @CANTIDAD
END
GO

CREATE PROCEDURE ejercicio31
AS
BEGIN
	DECLARE @JEFE NUMERIC(6)
	DECLARE @NUEVO_JEFE NUMERIC(6)
	DECLARE C_JEFE CURSOR FOR SELECT
							  empl_codigo
							  FROM Empleado
							  WHERE empl_codigo IN (SELECT empl_jefe FROM Empleado WHERE empl_jefe IS NOT NULL)
	OPEN C_JEFE
	FETCH NEXT FROM C_JEFE INTO @JEFE
	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF(dbo.cantidadEmpleados(@JEFE) > 20)
		BEGIN
			SET @NUEVO_JEFE = (SELECT empl_codigo
								FROM Empleado
								WHERE dbo.cantidadEmpleados(empl_codigo) BETWEEN 1 AND 20)
			IF(@NUEVO_JEFE IS NOT NULL)
			BEGIN
				UPDATE Empleado
				SET empl_jefe = @NUEVO_JEFE
				WHERE empl_codigo = @JEFE
			END
			ELSE
			BEGIN
				UPDATE Empleado
				SET empl_jefe = (SELECT empl_codigo FROM Empleado WHERE empl_jefe IS NULL)
				WHERE empl_codigo = @JEFE
			END
		END
	END
	CLOSE C_JEFE
	DEALLOCATE C_JEFE
END
GO