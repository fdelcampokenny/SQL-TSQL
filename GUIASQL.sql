USE GD2015C1
--GUIA EJERCICIOS:

-----------------
--1) -- Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea mayor o 
	--igual a $ 1000 ordenado por código de cliente

SELECT
	clie_codigo,
	clie_razon_social
FROM Cliente
WHERE (clie_limite_credito >= 1000)
ORDER BY clie_codigo

-----------------
--2) --2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por 
	--  cantidad vendida

SELECT prod_codigo, prod_detalle, SUM(item_cantidad)
FROM Producto 
JOIN Item_Factura ON item_producto = prod_codigo
JOIN Factura ON fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND fact_numero = item_numero

WHERE YEAR (fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
ORDER BY SUM(item_cantidad)

-----------------
--3)	--Realizar una consulta que muestre código de producto, nombre de producto y el stock
	--total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
	--nombre del artículo de menor a mayor.

SELECT
	prod_codigo,
	prod_detalle,
	SUM(stoc_cantidad) AS StockTotal
FROM Producto 
JOIN STOCK ON stoc_producto = prod_codigo
GROUP BY prod_codigo, prod_detalle
ORDER BY prod_detalle ASC

-----------------
--4) --Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de
	--artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock
	--promedio por depósito sea mayor a 100.

SELECT 
	prod_codigo,
	prod_detalle,
	COUNT(ISNULL(comp_componente, 0)) AS ArticulosQueLoComponen
FROM Producto 
LEFT JOIN Composicion ON comp_producto = prod_codigo
JOIN STOCK ON stoc_producto = prod_codigo
GROUP BY prod_codigo, prod_detalle
HAVING AVG(stoc_cantidad) > 100


-----------------
--5) 
--Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos de 
--stock que se realizaron para ese artículo en el año 2012 (egresan los productos que 
--fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011.

SELECT P.prod_codigo, P.prod_detalle, SUM(IFACT.item_cantidad)
FROM Producto P
	JOIN Item_factura IFACT
		ON IFACT.item_producto = P.prod_codigo
	JOIN Factura F 
		ON F.fact_tipo = IFACT.item_tipo AND F.fact_sucursal = IFACT.item_sucursal AND F.fact_numero = IFACT.item_numero
WHERE YEAR(F.fact_fecha) = 2012
GROUP BY P.prod_codigo, P.prod_detalle
HAVING SUM(IFACT.item_cantidad) > (
			SELECT SUM(IFACT2.item_cantidad)
			FROM item_Factura IFACT2
			JOIN Factura F2
				ON F2.fact_tipo = IFACT2.item_tipo AND F2.fact_sucursal = IFACT2.item_sucursal AND F2.fact_numero = IFACT2.item_numero
			WHERE YEAR(F2.fact_fecha) = 2011 AND IFACT2.item_producto = P.prod_codigo)
ORDER BY P.prod_codigo


-----------------
--6)
--Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese 
--rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos artículos que 
--tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’.

SELECT
	rubr_id AS IDrubro,
	rubr_detalle AS nombreRubro,
	COUNT(DISTINCT prod_codigo) AS cantidadArticulosDelRubro,
	SUM(stoc_cantidad) AS StockTotal
FROM Rubro
LEFT JOIN Producto ON prod_rubro = rubr_id
JOIN STOCK ON stoc_producto = prod_codigo
GROUP BY rubr_id, rubr_detalle
HAVING SUM(stoc_cantidad) > 
	(SELECT stoc_cantidad FROM STOCK WHERE stoc_producto = '00000000' AND stoc_deposito = '00')
ORDER BY rubr_id


-----------------
--7. Generar una consulta que muestre para cada artículo código, detalle, mayor precio 
--menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio = 
--10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean 
--stock.

SELECT
	prod_codigo,
	prod_detalle,
	MAX(item_precio) AS precioMax,
	MIN(item_precio) AS precioMin,
	(((MAX(item_precio) - MIN(item_precio)) * 100)/MIN(item_precio))
FROM Producto
JOIN Item_Factura ON item_producto = prod_codigo
JOIN STOCK ON stoc_producto = prod_codigo
WHERE stoc_cantidad > 0
GROUP BY prod_codigo, prod_detalle


-----------------
--8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del
--artículo, stock del depósito que más stock tiene

SELECT 
	prod_detalle,
	(SELECT TOP 1 stoc_cantidad
	FROM STOCK
	WHERE prod_codigo = stoc_producto
	ORDER BY stoc_cantidad DESC)
FROM Producto
JOIN STOCK ON stoc_producto = prod_codigo
JOIN DEPOSITO ON depo_codigo = stoc_deposito


-----------------
--9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del
--mismo y la cantidad de depósitos que ambos tienen asignados.
SELECT
	J.empl_codigo AS codigoJefe,
	E.empl_codigo AS codigoEmpleado,
	E.empl_nombre AS nombreEmpleado,
	E.empl_apellido AS apellidoEmpleado,
	COUNT(D.depo_encargado) AS DepositosEmpleado,
	(SELECT COUNT(depo_encargado)
	FROM DEPOSITO
	WHERE J.empl_codigo = depo_encargado) AS DepositosJefe
FROM Empleado E
LEFT JOIN Empleado J ON J.empl_codigo = E.empl_jefe
LEFT JOIN DEPOSITO D ON D.depo_encargado = E.empl_codigo
GROUP BY J.empl_codigo, E.empl_codigo, E.empl_nombre, E.empl_apellido





 

-----------------
--10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos 
--vendidos en la historia. Además mostrar de esos productos, quien fue el cliente que 
--mayor compra realizo.

SELECT TOP 10
	P.prod_codigo,
	P.prod_detalle,
	(SELECT TOP 1 F1.fact_cliente
	FROM Factura F1
	JOIN Item_Factura IFACT1
	ON IFACT1.item_tipo = F1.fact_tipo AND IFACT1.item_sucursal = F1.fact_sucursal AND IFACT1.item_numero = F1.fact_numero
	WHERE P.prod_codigo = IFACT1.item_producto
	GROUP BY F1.fact_cliente
	ORDER BY SUM(IFACT1.item_cantidad) DESC) AS ClienteMayorCompra
	FROM Producto P
	JOIN Item_Factura IFACT
	ON IFACT.item_producto = P.prod_codigo
	GROUP BY P.prod_codigo, P.prod_detalle
	ORDER BY SUM(IFACT.item_cantidad) DESC

SELECT TOP 10 
	P.prod_codigo AS [Codigo MENOR vendido]
	,P.prod_detalle [Detalle MENOR vendido]
	,(
		SELECT TOP 1 F1.fact_cliente
		FROM Factura F1
			INNER JOIN Item_Factura IFACT1
				ON F1.fact_sucursal = IFACT1.item_sucursal AND F1.fact_numero = IFACT1.item_numero AND F1.fact_tipo = IFACT1.item_tipo
		WHERE P.prod_codigo=IFACT1.item_producto
		GROUP BY F1.fact_cliente
		ORDER BY SUM(IFACT1.item_cantidad) DESC
	) AS [Cliente con MENOR cantidad de compras realizadas]
	
FROM Producto P
	INNER JOIN Item_Factura IFACT
		ON IFACT.item_producto = P.prod_codigo
GROUP BY P.prod_codigo,P.prod_detalle
ORDER BY SUM(IFACT.item_cantidad) ASC


-----------------
--11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
--productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán 
--ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga, 
--solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para 
--el año 2012.

SELECT
	FAM.fami_id,
	FAM.fami_detalle,
	COUNT(DISTINCT P.prod_detalle) AS CantProductosVendidosPorFlia, --count diferentes tipos por producto de la flia
	SUM(F.fact_total) AS MontoTotalSinImpuestos
FROM Familia FAM
JOIN Producto P ON P.prod_familia = FAM.fami_id
JOIN Item_Factura IFACT ON IFACT.item_producto = P.prod_codigo
JOIN Factura F ON F.fact_tipo = IFACT.item_tipo AND F.fact_sucursal = IFACT.item_sucursal AND F.fact_numero = IFACT.item_numero
GROUP BY FAM.fami_id, FAM.fami_detalle
HAVING EXISTS(
	SELECT TOP 1 fact_numero, fact_tipo, fact_sucursal
	FROM Factura
	JOIN Item_Factura ON fact_sucursal = item_sucursal AND fact_tipo = item_tipo AND fact_numero = item_numero
	JOIN Producto ON prod_codigo = item_producto
	WHERE YEAR(fact_fecha) = 2012 AND prod_familia = FAM.fami_id
	GROUP BY fact_numero, fact_tipo, fact_sucursal
	HAVING SUM(item_precio * item_cantidad) > 200000)
ORDER BY 3 DESC


-----------------
--12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron importe 
--promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del 
--producto y stock actual del producto en todos los depósitos. Se deberán mostrar 
--aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán 
--ordenarse de mayor a menor por monto vendido del producto.

SELECT
	prod_detalle,
	COUNT(DISTINCT fact_cliente) AS Clientes,
	AVG(item_precio) AS PrecioPromedio,
	(SELECT COUNT(DISTINCT stoc_deposito)
	FROM STOCK
	WHERE stoc_producto = prod_codigo AND stoc_cantidad > 0
	GROUP BY stoc_producto) AS cantDepositosConStock,	
	(SELECT SUM(stoc_cantidad)
	FROM STOCK
	WHERE stoc_producto = prod_codigo
	GROUP BY stoc_producto) AS StockTotalActual
FROM Producto
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
WHERE EXISTS(SELECT item_producto
			 FROM Item_Factura
			 JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
			 WHERE YEAR(fact_fecha) = 2012 AND item_producto = prod_codigo)
GROUP BY prod_codigo, prod_detalle
ORDER BY SUM(item_cantidad * item_precio) DESC

-----------------

--13. Realizar una consulta que retorne para cada producto que posea composición nombre 
--del producto, precio del producto, precio de la sumatoria de los precios por la cantidad 
--de los productos que lo componen. Solo se deberán mostrar los productos que estén 
--compuestos por más de 2 productos y deben ser ordenados de mayor a menor por 
--cantidad de productos que lo componen

SELECT
	P1.prod_detalle,
	P1.prod_precio,
	SUM(comp_cantidad * P2.prod_precio)
FROM Producto P1
JOIN Composicion ON P1.prod_codigo = comp_producto
JOIN Producto P2 ON comp_componente = P2.prod_codigo
GROUP BY P1.prod_detalle, P1.prod_precio
HAVING COUNT(DISTINCT comp_componente) > 2
ORDER BY COUNT(DISTINCT comp_componente) DESC 

-----------------


--14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que 
--debe retornar son:
----Código del cliente
----Cantidad de veces que compro en el último año
----Promedio por compra en el último año
----Cantidad de productos diferentes que compro en el último año
----Monto de la mayor compra que realizo en el último año
----Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en 
----el último año.
----No se deberán visualizar NULLs en ninguna columna


SELECT 
	fact_cliente AS Cliente,
	COUNT(DISTINCT fact_tipo + fact_sucursal + fact_numero) AS cantComprasUltimoAño,
	AVG(fact_total) AS promedioCompras,
	COUNT(DISTINCT item_producto) AS cantProductosDiferentes,
	MAX(fact_total) AS compraTotal
FROM Factura
JOIN Item_Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
WHERE YEAR(fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)
GROUP BY fact_cliente
ORDER BY cantComprasUltimoAño DESC

-----------------
--15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos 
--(en la misma factura) más de 500 veces. El resultado debe mostrar el código y 
--descripción de cada uno de los productos y la cantidad de veces que fueron vendidos 
--juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron 
--juntos dichos productos. Los distintos pares no deben retornarse más de una vez.
----Ejemplo de lo que retornaría la consulta:
----PROD1 DETALLE1 PROD2 DETALLE2 VECES
----1731 MARLBOROKS 1718 PHILIPSMORRISKS 507
----1718 PHILIPSMORRISS 1705 PHILIPSMORRISBOX10 562

SELECT
	P1.prod_codigo AS producto1,
	P1.prod_detalle AS detalleProducto1,
	P2.prod_codigo AS producto2,
	P2.prod_detalle AS detalleProducto2,
	COUNT(*) AS cantVecesVendidosJuntos
FROM Factura
JOIN Item_Factura i1 ON i1.item_tipo + i1.item_sucursal + i1.item_numero = fact_tipo + fact_sucursal + fact_numero
JOIN Item_Factura i2 ON i2.item_tipo + i2.item_sucursal + i2.item_numero = fact_tipo + fact_sucursal + fact_numero
JOIN Producto P1 ON P1.prod_codigo = i1.item_producto
JOIN Producto P2 ON P2.prod_codigo = i2.item_producto
WHERE P1.prod_codigo <> P2.prod_codigo
GROUP BY P1.prod_codigo, P1.prod_detalle, P2.prod_codigo, P2.prod_detalle
HAVING COUNT(*) > 500
ORDER BY 5 DESC

-----------------
--16. Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran 
--en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas ventas son 
--inferiores a 1/3 del promedio de ventas del producto que más se vendió en el 2012.
--Además mostrar
----1. Nombre del Cliente
----2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
----3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1, 
----mostrar solamente el de menor código) para ese cliente.
--Aclaraciones:
--La composición es de 2 niveles, es decir, un producto compuesto solo se compone de 
--productos no compuestos.
--Los clientes deben ser ordenados por código de provincia ascendente.SELECT	clie_razon_social AS 'Razón Social',	clie_domicilio AS 'Domicilio',	SUM(item_cantidad) AS 'Unidades totales compradas', 	(SELECT TOP 1 item_producto	 FROM Item_Factura	 JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero	 WHERE YEAR(fact_fecha) = 2012 AND fact_cliente = clie_codigo	 GROUP BY item_producto	 ORDER BY SUM(item_cantidad) DESC, item_producto ASC)FROM ClienteJOIN Factura ON fact_cliente = clie_codigoJOIN Item_Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numeroWHERE YEAR(fact_fecha) = 2012GROUP BY clie_codigo, clie_razon_social, clie_domicilioHAVING SUM(item_cantidad) < 1.00/3 * (SELECT TOP 1 SUM(item_cantidad) 									FROM Item_Factura									JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero									WHERE YEAR(fact_fecha) = 2012									GROUP BY item_producto									ORDER BY SUM(item_cantidad) DESC 									)ORDER BY clie_domicilio ASC-------------------17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
--producto.
--La consulta debe retornar:
--PERIODO: Año y mes de la estadística con el formato YYYYMM
--PROD: Código de producto
--DETALLE: Detalle del producto
--CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
--VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo 
--pero del año anterior
--CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el 
--periodo
--La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada 
--por periodo y código de producto.SELECT	CONCAT(YEAR(fact_fecha), '-',MONTH(fact_fecha)) AS Periodo,	prod_codigo AS CodigoProducto,	ISNULL(prod_detalle, 'SIN DESCRIPCION') AS Detalle,	ISNULL(SUM(item_cantidad), 0) AS 'Cantidad vendida',	ISNULL((SELECT SUM(item_cantidad) 	 FROM Item_Factura	 JOIN Factura F2 ON item_tipo + item_sucursal + item_numero = F2.fact_tipo + F2.fact_sucursal + F2.fact_numero	 WHERE MONTH(F2.fact_fecha) = MONTH(fact_fecha) AND YEAR(F2.fact_fecha) = YEAR(fact_fecha)-1 AND item_producto = prod_codigo	 ), 0) AS 'Cantidad vendida anterior',	 ISNULL(COUNT(*), 0) AS 'cantidad facturas con producto'FROM FacturaJOIN Item_Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numeroJOIN Producto ON item_producto = prod_codigoGROUP BY prod_codigo, prod_detalle, YEAR(fact_fecha), MONTH(fact_fecha)ORDER BY 1, 2-------------------18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
--La consulta debe retornar:
--DETALLE_RUBRO: Detalle del rubro
--VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
--PROD1: Código del producto más vendido de dicho rubro
--PROD2: Código del segundo producto más vendido de dicho rubro
--CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30 
--días
--La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada 
--por cantidad de productos diferentes vendidos del rubro.SELECT	rubr_detalle,	SUM(item_cantidad * item_precio) AS 'Total Ventas',	ISNULL((SELECT TOP 1 prod_codigo	 FROM Producto	 JOIN Item_Factura ON item_producto = prod_codigo	 WHERE prod_rubro = rubr_id	 GROUP BY prod_codigo	 ORDER BY SUM(item_cantidad) DESC), '-') AS 'Producto mas vendido',	 ISNULL((SELECT TOP 1 prod_codigo	 FROM Producto	 JOIN Item_Factura ON item_producto = prod_codigo	 WHERE prod_rubro = rubr_id AND prod_codigo NOT IN				(SELECT TOP 1 prod_codigo				FROM Producto				JOIN Item_Factura ON item_producto = prod_codigo				WHERE prod_rubro = rubr_id				GROUP BY prod_codigo				ORDER BY SUM(item_cantidad) DESC)	 GROUP BY prod_codigo	 ORDER BY SUM(item_cantidad) DESC), '-') AS 'Segundo producto mas vendido',	 ISNULL((SELECT TOP 1 clie_codigo	 FROM Cliente	 JOIN Factura ON clie_codigo = fact_cliente	 JOIN Item_Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero	 JOIN Producto ON prod_codigo = item_producto	 WHERE prod_rubro = rubr_id AND fact_fecha >	 DATEADD(DAY, -30, (SELECT MAX(fact_fecha) FROM Factura))	 GROUP BY clie_codigo	 ORDER BY SUM(item_cantidad) DESC), '-') AS 'Cliente mas compras 30 dias'FROM RubroJOIN Producto ON prod_rubro = rubr_idJOIN Item_Factura ON prod_codigo = item_productoGROUP BY rubr_id, rubr_detalleORDER BY COUNT(DISTINCT prod_codigo) DESC-------------------19. En virtud de una recategorizacion de productos referida a la familia de los mismos se 
--solicita que desarrolle una consulta sql que retorne para todos los productos:
-- Codigo de producto
-- Detalle del producto
-- Codigo de la familia del producto
-- Detalle de la familia actual del producto
-- Codigo de la familia sugerido para el producto
-- Detalla de la familia sugerido para el producto
--La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo 
--detalle coinciden en los primeros 5 caracteres.
--En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor 
--codigo. Solo se deben mostrar los productos para los cuales la familia actual sea 
--diferente a la sugerida
--Los resultados deben ser ordenados por detalle de producto de manera ascendente

SELECT
	prod_codigo,
	prod_detalle,
	fami_id,
	fami_detalle,
	(SELECT TOP 1 prod_familia
	FROM Producto P
	WHERE SUBSTRING(P.prod_detalle, 1, 5) = SUBSTRING(prod_detalle, 1, 5)
	GROUP BY prod_familia
	ORDER BY COUNT(*) DESC, prod_familia) AS 'Fam sugerida',
	(SELECT fami_detalle
	FROM Familia
	WHERE fami_id = (SELECT TOP 1 prod_familia
					FROM Producto P
					WHERE SUBSTRING(P.prod_detalle, 1, 5) = SUBSTRING(prod_detalle, 1, 5)
					GROUP BY prod_familia
					ORDER BY COUNT(*) DESC, prod_familia)) AS 'Detalle familia sugerida'
FROM Producto
JOIN Familia ON prod_codigo = fami_id
WHERE (SELECT TOP 1 prod_familia
		FROM Producto P
		WHERE SUBSTRING(prod_detalle, 1, 5) = SUBSTRING(P.prod_detalle, 1, 5)
		GROUP BY prod_familia
		ORDER BY COUNT(*) DESC, prod_familia) != fami_id
-----------------
--20. Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012
--Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje 
--2012. El puntaje de cada empleado se calculara de la siguiente manera: para los que 
--hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas 
--que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50
--facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas 
--por sus subordinados directos en dicho año

'LO HIZO LACQUANTINI EL 4/10/23'

-----------------
--21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al 
--menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta 
--al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se 
--considera que una factura es incorrecta cuando la diferencia entre el total de la factura 
--menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de 
--los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar 
--son:
-- Año
-- Clientes a los que se les facturo mal en ese año
-- Facturas mal realizadas en ese año

SELECT
	YEAR(fact_fecha) AS 'Año',
	COUNT(DISTINCT fact_cliente) AS 'Clientes mal facturados',
	COUNT(DISTINCT fact_numero + fact_tipo + fact_sucursal) AS 'Facturas mal realizadas'
FROM Factura
WHERE fact_tipo + fact_sucursal + fact_numero IN 
		(SELECT fact_tipo + fact_sucursal + fact_numero
		FROM Factura
		JOIN Item_Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
		GROUP BY fact_tipo, fact_sucursal, fact_numero, fact_total, fact_total_impuestos
		HAVING fact_total - fact_total_impuestos - (SUM(item_cantidad * item_precio)) > 1
		)										  
GROUP BY YEAR(fact_fecha)


--22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por 
--trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1 
--por cada trimestre).
--Se deben mostrar 4 columnas:
-- Detalle del rubro
-- Numero de trimestre del año (1 a 4)
-- Cantidad de facturas emitidas en el trimestre en las que se haya vendido al 
--menos un producto del rubro
-- Cantidad de productos diferentes del rubro vendidos en el trimestre 
--El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada 
--rubro primero el trimestre en el que mas facturas se emitieron.
--No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas 
--no superen las 100.
--En ningun momento se tendran en cuenta los productos compuestos para esta 
--estadistica.

SELECT
	rubr_detalle,
	DATEPART(QUARTER, fact_fecha) AS Trimestre,
	COUNT(DISTINCT fact_numero),
	COUNT(DISTINCT prod_codigo) AS 'Productos diferentes'
FROM Rubro
JOIN Producto ON prod_rubro = rubr_id
JOIN Item_Factura ON item_producto = prod_codigo
JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
WHERE prod_codigo NOT IN (SELECT comp_producto FROM Composicion)
GROUP BY rubr_detalle, DATEPART(QUARTER, fact_fecha)
HAVING COUNT(DISTINCT fact_numero) > 100
ORDER BY rubr_detalle, COUNT(DISTINCT fact_numero) DESC	

--23. Realizar una consulta SQL que para cada año muestre :
-- Año
-- El producto con composición más vendido para ese año.
-- Cantidad de productos que componen directamente al producto más vendido
-- La cantidad de facturas en las cuales aparece ese producto.
-- El código de cliente que más compro ese producto.
-- El porcentaje que representa la venta de ese producto respecto al total de venta 
--del año.
--El resultado deberá ser ordenado por el total vendido por año en forma descendente

SELECT
	YEAR(fact_fecha) AS Año,
	item_producto AS 'Prod. mas vendido',
	COUNT(DISTINCT comp_componente) AS 'Cant componentes',
	COUNT(DISTINCT fact_numero) AS 'Cantidad facturas',
	(SELECT TOP 1 fact_cliente FROM Factura F
	JOIN Item_Factura ON item_tipo + item_sucursal + item_numero = F.fact_tipo + F.fact_sucursal + F.fact_numero
	WHERE YEAR(F.fact_fecha) = YEAR(fact_fecha) AND item_producto = prod_codigo
	GROUP BY fact_cliente
	ORDER BY SUM(item_cantidad) DESC) as 'Cliente mas compras',
	SUM(item_precio * item_cantidad) * 100 / (SELECT SUM(i2.item_precio * i2.item_producto)
												FROM Item_Factura i2
												JOIN Factura f2 ON f2.fact_tipo + f2.fact_sucursal + f2.fact_numero = i2.tipo + i2.item_sucursal + i2.item_numero
												WHERE YEAR(f2.fact_fecha) = YEAR(fact_fecha))
FROM Factura
JOIN Item_Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
JOIN Producto ON item_producto = prod_codigo
JOIN Composicion ON comp_producto = prod_codigo
WHERE item_producto in (SELECT TOP 1 comp_producto FROM Composicion
						JOIN Item_Factura ON comp_producto = item_producto
						JOIN Factura f3 ON f3.fact_tipo + f3.fact_sucursal + f3.fact_numero = item_tipo+item_sucursal+item_numero
						WHERE YEAR(fact_fecha) = YEAR(f3.fact_fecha)
						GROUP BY comp_producto
						ORDER BY SUM(item_cantidad))
GROUP BY YEAR(fact_fecha), item_producto
ORDER BY SUM(item_cantidad * item_precio) DESC

--24. Escriba una consulta que considerando solamente las facturas correspondientes a los 
--dos vendedores con mayores comisiones, retorne los productos con composición 
--facturados al menos en cinco facturas,
--La consulta debe retornar las siguientes columnas:
-- Código de Producto
-- Nombre del Producto
-- Unidades facturadas
--El resultado deberá ser ordenado por las unidades facturadas descendente.SELECT 	prod_codigo,	prod_detalle,	SUM(item_cantidad) AS 'Unidades Facturadas'FROM ProductoJOIN Item_Factura ON prod_codigo = item_productoJOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numeroWHERE fact_vendedor IN (SELECT TOP 2 empl_codigo							FROM Empleado						ORDER BY empl_comision DESC) AND prod_codigo IN (SELECT comp_producto FROM Composicion)GROUP BY prod_codigo, prod_detalleHAVING COUNT(DISTINCT fact_numero) > 5ORDER BY 3 DESC--25. Realizar una consulta SQL que para cada año y familia muestre :
--a. Año
--b. El código de la familia más vendida en ese año.
--c. Cantidad de Rubros que componen esa familia.
--d. Cantidad de productos que componen directamente al producto más vendido de 
--esa familia.
--e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa 
--familia.
--f. El código de cliente que más compro productos de esa familia.
--g. El porcentaje que representa la venta de esa familia respecto al total de venta 
--del año.
--El resultado deberá ser ordenado por el total vendido por año y familia en forma 
--descendente.	--26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las 
--siguientes columnas:
-- Empleado
-- Depósitos que tiene a cargo
-- Monto total facturado en el año corriente
-- Codigo de Cliente al que mas le vendió
-- Producto más vendido
-- Porcentaje de la venta de ese empleado sobre el total vendido ese año.
--Los datos deberan ser ordenados por venta del empleado de mayor a menor.

SELECT
	empl_codigo,
	(SELECT COUNT(DISTINCT depo_codigo)
	FROM DEPOSITO
	WHERE depo_encargado = empl_codigo),
	SUM(fact_total),
	(SELECT TOP 1 fact_cliente
	FROM Factura
	WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = (SELECT TOP 1 YEAR(fact_fecha) FROM Factura ORDER BY 1 DESC)
	GROUP BY fact_cliente
	ORDER BY COUNT(DISTINCT fact_numero) DESC),
	(SELECT TOP 1 item_producto
	FROM Item_Factura
	JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
	WHERE fact_vendedor = empl_codigo AND YEAR(fact_fecha) = (SELECT TOP 1 YEAR(fact_fecha) FROM Factura ORDER BY 1 DESC)
	GROUP BY item_producto
	ORDER BY SUM(item_cantidad) DESC),
	SUM(fact_total) * 100 /  (SELECT SUM(fact_total) FROM Factura WHERE YEAR(fact_fecha) = (SELECT TOP 1 YEAR(fact_fecha) FROM Factura ORDER BY 1 DESC))
FROM Empleado
JOIN Factura ON fact_vendedor = empl_codigo
WHERE YEAR(fact_fecha) = (SELECT TOP 1 YEAR(fact_fecha) FROM Factura ORDER BY 1 DESC)
GROUP BY empl_codigo
ORDER BY SUM(fact_total) DESC 


--27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y 
--envase devolviendo las siguientes columnas:
-- Año
-- Codigo de envase
-- Detalle del envase
-- Cantidad de productos que tienen ese envase
-- Cantidad de productos facturados de ese envase
-- Producto mas vendido de ese envase
-- Monto total de venta de ese envase en ese año
-- Porcentaje de la venta de ese envase respecto al total vendido de ese año
--Los datos deberan ser ordenados por año y dentro del año por el envase con más 
--facturación de mayor a menor

SELECT 
	YEAR(fact_fecha) AS 'Año',
	enva_codigo AS 'Cod. Envase',
	enva_detalle AS 'Envase',
	COUNT(DISTINCT prod_codigo) 'Cant. Productos envase',
	SUM(item_cantidad) 'Prod. facturados envase',
	(SELECT TOP 1 prod_detalle
	FROM Producto
	JOIN Item_Factura ON item_producto = prod_codigo
	JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
	WHERE prod_envase = e1.enva_codigo AND YEAR(fact_fecha) = YEAR(f1.fact_fecha)
	GROUP BY prod_detalle
	ORDER BY SUM(item_cantidad) DESC) AS 'Prod. mas vendido envase',
	SUM(item_cantidad * item_precio) as 'Total Facturado',
	SUM(item_cantidad * item_precio) * 100 / (SELECT SUM(fact_total)
												FROM Factura
												WHERE YEAR(fact_fecha) = YEAR(f1.fact_fecha)) AS 'Porcentaje'
FROM Envases e1
JOIN Producto ON enva_codigo = prod_envase
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura f1 ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero
GROUP BY YEAR(fact_fecha), enva_codigo, enva_detalle
ORDER BY YEAR(fact_fecha), SUM(item_cantidad * item_precio) DESC



--28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las 
--siguientes columnas:
-- Año.
-- Codigo de Vendedor
-- Detalle del Vendedor
-- Cantidad de facturas que realizó en ese año
-- Cantidad de clientes a los cuales les vendió en ese año.
-- Cantidad de productos facturados con composición en ese año
-- Cantidad de productos facturados sin composicion en ese año.
-- Monto total vendido por ese vendedor en ese año
--Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya 
--vendido mas productos diferentes de mayor a menor.

--29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para 
--los productos que pertenezcan a las familias que tengan más de 20 productos asignados 
--a ellas, la cual deberá devolver las siguientes columnas:
--a. Código de producto
--b. Descripción del producto
--c. Cantidad vendida
--d. Cantidad de facturas en la que esta ese producto
--e. Monto total facturado de ese producto
--Solo se deberá mostrar un producto por fila en función a los considerandos establecidos 
--antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.

SELECT
	prod_codigo,
	prod_detalle,
	SUM(item_cantidad) AS 'Cant. Vendida',
	COUNT(DISTINCT fact_numero) AS 'Cant. Facturas',
	SUM(item_cantidad * item_precio) AS 'Total Facturado'
FROM Producto
JOIN Item_Factura ON item_producto = prod_codigo
JOIN Factura ON fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
JOIN Familia ON fami_id = prod_familia
WHERE YEAR(fact_fecha) = 2011 AND prod_familia IN (SELECT fami_id
													FROM Familia
													JOIN Producto ON prod_familia = fami_id
													GROUP BY fami_id
													HAVING COUNT(DISTINCT prod_codigo) > 20)
GROUP BY prod_codigo, prod_detalle
ORDER BY 4 DESC

--30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean 
--jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la 
--consulta que retorne las siguientes columnas:
-- Nombre del Jefe
-- Cantidad de empleados a cargo
-- Monto total vendido de los empleados a cargo
-- Cantidad de facturas realizadas por los empleados a cargo
-- Nombre del empleado con mejor ventas de ese jefe
--Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese 
--necesario.
--Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se 
--deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.

SELECT
	J.empl_nombre,
	COUNT(DISTINCT E.empl_codigo),
	SUM(fact_total) AS 'Monto Total',
	COUNT(DISTINCT fact_numero) AS 'Cant.Facturas',
	(SELECT TOP 1 empl_nombre
	FROM Empleado 
	JOIN Factura ON fact_vendedor = empl_codigo
	WHERE empl_jefe = J.empl_codigo AND YEAR(fact_fecha) = 2012
	GROUP BY empl_codigo, empl_nombre
	ORDER BY SUM(fact_total) DESC) AS 'Mejor Empleado'
FROM Empleado J
JOIN Empleado E ON E.empl_jefe = J.empl_codigo
JOIN Factura ON fact_vendedor = E.empl_codigo
WHERE YEAR(fact_fecha) = 2012
GROUP BY J.empl_codigo, J.empl_nombre
HAVING COUNT(DISTINCT fact_numero) > 10
ORDER BY 3 DESC

--31. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las 
--siguientes columnas:
-- Año.
-- Codigo de Vendedor
-- Detalle del Vendedor
-- Cantidad de facturas que realizó en ese año
-- Cantidad de clientes a los cuales les vendió en ese año.
-- Cantidad de productos facturados con composición en ese año
-- Cantidad de productos facturados sin composicion en ese año.
-- Monto total vendido por ese vendedor en ese año
--Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya 
--vendido mas productos diferentes de mayor a menor.SELECT	YEAR(F.fact_fecha) AS 'Año',    V.empl_codigo,	V.empl_nombre,	V.empl_apellido,	COUNT(DISTINCT F.fact_numero) AS 'Cant. facturas',	COUNT(DISTINCT F.fact_cliente) AS 'Cant. clientes',	(	 SELECT SUM(item_cantidad)	 FROM Item_Factura	 JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero	 JOIN Composicion ON item_producto = comp_producto	 WHERE YEAR(fact_fecha) = YEAR(F.fact_fecha)AND fact_vendedor = V.empl_codigo) AS 'Cant. Compuestos',	 (	 SELECT SUM(item_cantidad)	 FROM Item_Factura	 JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero	 WHERE YEAR(fact_fecha) = YEAR(F.fact_fecha) AND fact_vendedor = V.empl_codigo AND	 item_producto NOT IN (SELECT comp_producto FROM Composicion)) AS 'cant no compuestos',	 SUM(fact_total) AS 'Total vendido'	FROM Factura FJOIN Empleado V ON fact_vendedor = V.empl_codigoGROUP BY YEAR(F.fact_fecha), V.empl_codigo, V.empl_nombre, V.empl_apellidoORDER BY YEAR(F.fact_fecha), (SELECT SUM(item_cantidad)							  FROM Item_Factura							  JOIN Factura ON item_tipo + item_sucursal + item_numero = fact_tipo + fact_sucursal + fact_numero							  WHERE fact_vendedor = V.empl_codigo AND YEAR(fact_fecha) = YEAR(F.fact_fecha)							  ) DESC							  							--32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas 
--facturas para ello se solicita que escriba una consulta sql que retorne los pares de 
--familias que tienen productos que se facturaron juntos. Para ellos deberá devolver las 
--siguientes columnas:
-- Código de familia 
-- Detalle de familia
-- Código de familia
-- Detalle de familia 
-- Cantidad de facturas
-- Total vendido
--Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias 
--que se vendieron juntas más de 10 veces.

SELECT
	F1.fami_id AS 'Fam 1 cod',
	F1.fami_detalle AS 'Fam 1 detalle',
	F2.fami_id AS 'Fam 2 cod',
	F2.fami_detalle AS 'Fam 2 detalle',
	COUNT(DISTINCT fact_numero) AS 'cant Facturas',
	SUM(I1.item_cantidad * I1.item_precio) + SUM(I2.item_cantidad * I2.item_precio) AS 'Total Facturado'
FROM Factura
JOIN Item_Factura I1 ON I1.item_tipo + I1.item_sucursal + I1.item_numero = fact_tipo + fact_sucursal + fact_numero
JOIN Item_Factura I2 ON I2.item_tipo + I2.item_sucursal + I2.item_numero = fact_tipo + fact_sucursal + fact_numero
JOIN Producto P1 ON I1.item_producto = P1.prod_codigo
JOIN Producto P2 ON I2.item_producto = P2.prod_codigo
JOIN Familia F1 ON F1.fami_id = P1.prod_codigo
JOIN Familia F2 ON F2.fami_id = P2.prod_codigo
WHERE F1.fami_id <> F2.fami_id
GROUP BY F1.fami_id, F1.fami_detalle, F2.fami_id, F2.fami_detalle
HAVING COUNT(DISTINCT fact_numero) > 10
ORDER BY 6

--
SELECT FAM1.fami_id AS [FAMI Cod 1]
	,FAM1.fami_detalle AS [FAMI Detalle 1]
	,FAM2.fami_id AS [FAMI Cod 2]
	,FAM2.fami_detalle [FAMI Detalle 2]
	,COUNT(DISTINCT IFACT2.item_numero+IFACT2.item_tipo+IFACT2.item_sucursal) AS [Cantidad de facturas]
	,SUM(IFACT1.item_cantidad*IFACT1.item_precio) + SUM(IFACT2.item_cantidad*IFACT2.item_precio) AS [Total Vendido entre items de ambas familias]
FROM Familia FAM1
	INNER JOIN Producto P1
		ON P1.prod_familia = FAM1.fami_id
	INNER JOIN Item_Factura IFACT1
		ON IFACT1.item_producto = P1.prod_codigo
	,Familia FAM2
	INNER JOIN Producto P2
		ON P2.prod_familia = FAM2.fami_id
	INNER JOIN Item_Factura IFACT2
		ON IFACT2.item_producto = P2.prod_codigo
WHERE FAM1.fami_id <> FAM2.fami_id
	AND IFACT1.item_numero+IFACT1.item_tipo+IFACT1.item_sucursal = IFACT2.item_numero+IFACT2.item_tipo+IFACT2.item_sucursal
GROUP BY FAM1.fami_id,FAM1.fami_detalle,FAM2.fami_id,FAM2.fami_detalle
HAVING COUNT(DISTINCT IFACT2.item_numero+IFACT2.item_tipo+IFACT2.item_sucursal) > 10
ORDER BY 6