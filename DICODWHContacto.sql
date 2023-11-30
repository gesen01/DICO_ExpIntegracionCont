CREATE TABLE DICODWHContacto(
    Estacion	 INT,
    Contacto	 VARCHAR(10),
    Nombre	 VARCHAR(150),
    Tipo		 VARCHAR(30),
    Movimiento	 VARCHAR(30),
    Saldo		 FLOAT,
    Debe		 FLOAT,
    Haber		 FLOAT,
    Proyecto	 VARCHAR(30),
    UEN		 INT,
    FechaEmision	DATETIME,
    CentroCostos	VARCHAR(30),
    CuentaDinero	VARCHAR(30),
    Descripcion	VARCHAR(255)	
)