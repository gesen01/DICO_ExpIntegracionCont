SET DATEFIRST 7
SET ANSI_NULLS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET LOCK_TIMEOUT -1
SET QUOTED_IDENTIFIER OFF
GO

IF EXISTS(SELECT * FROM sysobjects WHERE TYPE='p' AND NAME='xpDICOVerDesgloseCuenta')
DROP PROCEDURE xpDICOVerDesgloseCuenta
GO

CREATE PROCEDURE xpDICOVerDesgloseCuenta
@Estacion		INT,
@Cuenta		VARCHAR(15),
@Empresa		VARCHAR(5),
@Sucursal		INT,
@Ejercicio		INT,
@PeriodoD		INT,
@PeriodoA		INT,
@Moneda			VARCHAR(20),
@FechaSaldoInicial	datetime
AS
BEGIN
IF @Moneda	 IN ('','NULL','(Todas)','(Todos)', NULL) select @Moneda =  NULL

DELETE FROM DICODWHContacto WHERE Estacion=@Estacion

CREATE TABLE #Contacto(
Contacto	char(10)	NULL,
CtoTipo		varchar(20)	NULL)

CREATE TABLE #DWHSI(
Contacto		CHAR(10)	NULL,
Movimiento		char(20)	NULL,
CtoTipo		varchar(20)	NULL,
Proyecto		varchar(50)	NULL,
UEN			int		NULL,
FechaEmision	datetime	NULL,
CentroCostos	char(20)	NULL,
CuentaDinero	char(10)	NULL,
Saldo		float		NULL)

CREATE TABLE #DWH(
Contacto		CHAR(10)	NULL,
Movimiento		char(20)	NULL,
CtoTipo		VARCHAR(20)	NULL,
Debe		float		NULL,
Haber		float	NULL,
Proyecto		VARCHAR(50)	NULL,
UEN			INT		NULL,
FechaEmision	DATETIME	NULL,
CentroCostos	VARCHAR(20) 	NULL,
CuentaDinero	char(10)	NULL)

INSERT INTO #DWHSI(Contacto, CtoTipo, Proyecto, UEN, FechaEmision, CentroCostos, CuentaDinero, Saldo)
SELECT
ISNULL(ISNULL(r.ContactoEspecifico, m.Contacto),''),
ISNULL(m.CtoTipo, ''),
'',
'',
'',
'',
'',
SUM(ISNULL(r.Debe,0) - ISNULL(r.Haber,0))
FROM ContReg r
JOIN MovReg m ON r.Modulo = m.Modulo AND r.ModuloID = m.ID AND r.Empresa = m.Empresa
JOIN Cont c ON c.ID = r.ID AND ISNULL(c.OrigenTipo, 'CONT') = r.Modulo  -- Armando
WHERE r.Cuenta = @Cuenta AND r.empresa = @Empresa
AND ISNULL(m.Sucursal, '') = ISNULL(ISNULL(@Sucursal, m.Sucursal), '')
AND c.FechaContable < @FechaSaldoInicial -- Armando
GROUP BY ISNULL(ISNULL(r.ContactoEspecifico, m.Contacto),''), m.CtoTipo
HAVING SUM(ISNULL(r.Debe,0) - ISNULL(r.Haber,0)) <> 0

INSERT INTO #DWH (Contacto, CtoTipo, Debe, Haber, Proyecto, UEN, FechaEmision, CentroCostos, CuentaDinero)
SELECT
ISNULL(ISNULL(r.ContactoEspecifico, m.Contacto),''),
ISNULL(m.CtoTipo, ''),
Debe = SUM(ISNULL(r.Debe,0)),
Haber = SUM(ISNULL(r.Haber,0)),
NULL,
NULL,
NULL,
NULL,
NULL
FROM
Cont c
LEFT OUTER JOIN ContReg r ON c.ID = r.ID  AND ISNULL(c.OrigenTipo, 'CONT') = r.modulo AND r.Empresa = c.Empresa
LEFT OUTER JOIN MovReg m ON r.Modulo = m.Modulo AND r.ModuloID = m.ID AND r.Empresa = m.Empresa
LEFT OUTER JOIN MovTipo mt ON     mt.mov = c.mov
WHERE  mt.modulo = 'CONT' AND
mt.clave = 'CONT.P' AND
c.Estatus = 'CONCLUIDO' AND
isnull(c.Moneda,'') = isnull(isnull(@Moneda, c.Moneda),'') AND
r.cuenta = @Cuenta AND r.empresa = @Empresa AND c.Ejercicio = @Ejercicio AND c.Periodo BETWEEN @PeriodoD AND @PeriodoA AND
ISNULL(m.Sucursal, 0) = ISNULL(ISNULL(@Sucursal, m.Sucursal), 0)
GROUP BY ISNULL(ISNULL(r.ContactoEspecifico, m.Contacto),''), m.CtoTipo

INSERT INTO #Contacto (Contacto, CtoTipo)
SELECT DISTINCT ISNULL(Contacto,''), ISNULL(CtoTipo,'')
FROM #DWHSI
UNION
SELECT DISTINCT ISNULL(Contacto,''), ISNULL(CtoTipo,'')
FROM #DWH

INSERT INTO DICODWHContacto
SELECT c.Contacto,
'Nombre' = CASE WHEN c.CtoTipo = 'Cliente' THEN
(SELECT Nombre FROM Cte WHERE Cliente = c.Contacto)
ELSE
(SELECT Nombre FROM Prov WHERE Proveedor = c.Contacto)
END,
c.CtoTipo
,d.Movimiento
,'Saldo' = ISNULL(s.Saldo,0)
,'Debe' = ISNULL(d.Debe,0)
,'Haber' = ISNULL(d.Haber,0)
,d.Proyecto
,d.UEN
,d.FechaEmision
,d.CentroCostos
,d.CuentaDinero
,'Descripcion' = Convert(char(100), '')
FROM #Contacto c
LEFT OUTER JOIN #DWHSI s ON c.Contacto = s.Contacto AND c.CtoTipo = s.CtoTipo
LEFT OUTER JOIN #DWH d ON c.Contacto = d.Contacto AND c.CtoTipo = d.CtoTipo
ORDER BY c.Contacto, c.CtoTipo
END
GO