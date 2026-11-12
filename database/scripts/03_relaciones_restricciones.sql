
USE GimnasioDB;
GO

-- 1. CAMPOS OBLIGATORIOS

ALTER TABLE dbo.Socios ALTER COLUMN Nombres NVARCHAR(80) NOT NULL;
ALTER TABLE dbo.Socios ALTER COLUMN Apellidos NVARCHAR(80) NOT NULL;
ALTER TABLE dbo.Socios ALTER COLUMN Correo VARCHAR(150) NOT NULL;
ALTER TABLE dbo.Socios ALTER COLUMN FechaRegistro DATE NOT NULL;
ALTER TABLE dbo.Socios ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Entrenadores ALTER COLUMN Nombres NVARCHAR(80) NOT NULL;
ALTER TABLE dbo.Entrenadores ALTER COLUMN Apellidos NVARCHAR(80) NOT NULL;
ALTER TABLE dbo.Entrenadores ALTER COLUMN Correo VARCHAR(150) NOT NULL;
ALTER TABLE dbo.Entrenadores ALTER COLUMN Especialidad NVARCHAR(100) NOT NULL;
ALTER TABLE dbo.Entrenadores ALTER COLUMN FechaContratacion DATE NOT NULL;
ALTER TABLE dbo.Entrenadores ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.TiposMembresia ALTER COLUMN Nombre NVARCHAR(50) NOT NULL;
ALTER TABLE dbo.TiposMembresia ALTER COLUMN DuracionDias INT NOT NULL;
ALTER TABLE dbo.TiposMembresia ALTER COLUMN PrecioBase DECIMAL(10,2) NOT NULL;
ALTER TABLE dbo.TiposMembresia ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Membresias ALTER COLUMN SocioID INT NOT NULL;
ALTER TABLE dbo.Membresias ALTER COLUMN TipoMembresiaID INT NOT NULL;
ALTER TABLE dbo.Membresias ALTER COLUMN FechaInicio DATE NOT NULL;
ALTER TABLE dbo.Membresias ALTER COLUMN FechaFin DATE NOT NULL;
ALTER TABLE dbo.Membresias ALTER COLUMN PrecioAplicado DECIMAL(10,2) NOT NULL;
ALTER TABLE dbo.Membresias ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Clases ALTER COLUMN Nombre NVARCHAR(80) NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN EntrenadorID INT NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN FechaHoraInicio DATETIME2 NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN FechaHoraFin DATETIME2 NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN Capacidad INT NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN Sala NVARCHAR(50) NOT NULL;
ALTER TABLE dbo.Clases ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Reservaciones ALTER COLUMN SocioID INT NOT NULL;
ALTER TABLE dbo.Reservaciones ALTER COLUMN ClaseID INT NOT NULL;
ALTER TABLE dbo.Reservaciones ALTER COLUMN FechaReservacion DATETIME2 NOT NULL;
ALTER TABLE dbo.Reservaciones ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Pagos ALTER COLUMN MembresiaID INT NOT NULL;
ALTER TABLE dbo.Pagos ALTER COLUMN FechaPago DATETIME2 NOT NULL;
ALTER TABLE dbo.Pagos ALTER COLUMN Monto DECIMAL(10,2) NOT NULL;
ALTER TABLE dbo.Pagos ALTER COLUMN MetodoPago VARCHAR(30) NOT NULL;
ALTER TABLE dbo.Pagos ALTER COLUMN Estado VARCHAR(15) NOT NULL;

ALTER TABLE dbo.Asistencias ALTER COLUMN ReservacionID INT NOT NULL;
ALTER TABLE dbo.Asistencias ALTER COLUMN FechaRegistro DATETIME2 NOT NULL;
ALTER TABLE dbo.Asistencias ALTER COLUMN EstadoAsistencia VARCHAR(15) NOT NULL;
GO

-- 2. CLAVES FORANEAS

ALTER TABLE dbo.Membresias
ADD CONSTRAINT FK_Membresias_Socios
FOREIGN KEY (SocioID) REFERENCES dbo.Socios(SocioID);

ALTER TABLE dbo.Membresias
ADD CONSTRAINT FK_Membresias_Tipos
FOREIGN KEY (TipoMembresiaID)
REFERENCES dbo.TiposMembresia(TipoMembresiaID);

ALTER TABLE dbo.Clases
ADD CONSTRAINT FK_Clases_Entrenadores
FOREIGN KEY (EntrenadorID)
REFERENCES dbo.Entrenadores(EntrenadorID);

ALTER TABLE dbo.Reservaciones
ADD CONSTRAINT FK_Reservaciones_Socios
FOREIGN KEY (SocioID) REFERENCES dbo.Socios(SocioID);

ALTER TABLE dbo.Reservaciones
ADD CONSTRAINT FK_Reservaciones_Clases
FOREIGN KEY (ClaseID) REFERENCES dbo.Clases(ClaseID);

ALTER TABLE dbo.Pagos
ADD CONSTRAINT FK_Pagos_Membresias
FOREIGN KEY (MembresiaID)
REFERENCES dbo.Membresias(MembresiaID);

ALTER TABLE dbo.Asistencias
ADD CONSTRAINT FK_Asistencias_Reservaciones
FOREIGN KEY (ReservacionID)
REFERENCES dbo.Reservaciones(ReservacionID);
GO

-- 3. RESTRICCIONES UNIQUE


ALTER TABLE dbo.Socios
ADD CONSTRAINT UQ_Socios_Correo UNIQUE (Correo);

ALTER TABLE dbo.Entrenadores
ADD CONSTRAINT UQ_Entrenadores_Correo UNIQUE (Correo);

ALTER TABLE dbo.TiposMembresia
ADD CONSTRAINT UQ_TiposMembresia_Nombre UNIQUE (Nombre);

ALTER TABLE dbo.Asistencias
ADD CONSTRAINT UQ_Asistencias_Reservacion UNIQUE (ReservacionID);
GO

-- 4. RESTRICCIONES CHECK

ALTER TABLE dbo.Socios
ADD CONSTRAINT CK_Socios_Estado
CHECK (Estado IN ('Activo', 'Inactivo'));

ALTER TABLE dbo.Entrenadores
ADD CONSTRAINT CK_Entrenadores_Estado
CHECK (Estado IN ('Activo', 'Inactivo'));

ALTER TABLE dbo.TiposMembresia
ADD CONSTRAINT CK_Tipos_Duracion
CHECK (DuracionDias > 0);

ALTER TABLE dbo.TiposMembresia
ADD CONSTRAINT CK_Tipos_Precio
CHECK (PrecioBase >= 0);

ALTER TABLE dbo.TiposMembresia
ADD CONSTRAINT CK_Tipos_Estado
CHECK (Estado IN ('Activo', 'Inactivo'));

ALTER TABLE dbo.Membresias
ADD CONSTRAINT CK_Membresias_Fechas
CHECK (FechaFin > FechaInicio);

ALTER TABLE dbo.Membresias
ADD CONSTRAINT CK_Membresias_Precio
CHECK (PrecioAplicado >= 0);

ALTER TABLE dbo.Membresias
ADD CONSTRAINT CK_Membresias_Estado
CHECK (Estado IN ('Activa', 'Vencida', 'Cancelada'));

ALTER TABLE dbo.Clases
ADD CONSTRAINT CK_Clases_Fechas
CHECK (FechaHoraFin > FechaHoraInicio);

ALTER TABLE dbo.Clases
ADD CONSTRAINT CK_Clases_Capacidad
CHECK (Capacidad > 0);

ALTER TABLE dbo.Clases
ADD CONSTRAINT CK_Clases_Estado
CHECK (Estado IN ('Programada', 'Finalizada', 'Cancelada'));

ALTER TABLE dbo.Reservaciones
ADD CONSTRAINT CK_Reservaciones_Estado
CHECK (Estado IN ('Confirmada', 'Cancelada', 'Lista de espera'));

ALTER TABLE dbo.Pagos
ADD CONSTRAINT CK_Pagos_Monto
CHECK (Monto > 0);

ALTER TABLE dbo.Pagos
ADD CONSTRAINT CK_Pagos_Metodo
CHECK (MetodoPago IN ('Efectivo', 'Tarjeta', 'Transferencia'));

ALTER TABLE dbo.Pagos
ADD CONSTRAINT CK_Pagos_Estado
CHECK (Estado IN ('Pagado', 'Pendiente', 'Rechazado'));

ALTER TABLE dbo.Asistencias
ADD CONSTRAINT CK_Asistencias_Estado
CHECK (EstadoAsistencia IN ('Asistió', 'Ausente', 'Justificada'));
GO
