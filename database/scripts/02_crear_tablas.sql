USE GimnasioDB;
GO
-- TABLA 1: SOCIOS

CREATE TABLE Socios (
    SocioID INT IDENTITY(1,1) PRIMARY KEY,
    Nombres NVARCHAR(80),
    Apellidos NVARCHAR(80),
    Correo VARCHAR(150),
    Telefono VARCHAR(20),
    FechaNacimiento DATE,
    FechaRegistro DATE,
    Estado VARCHAR(15)
);
GO

-- TABLA 2: ENTRENADORES

CREATE TABLE Entrenadores (
    EntrenadorID INT IDENTITY(1,1) PRIMARY KEY,
    Nombres NVARCHAR(80),
    Apellidos NVARCHAR(80),
    Correo VARCHAR(150),
    Telefono VARCHAR(20),
    Especialidad NVARCHAR(100),
    FechaContratacion DATE,
    Estado VARCHAR(15)
);
GO

-- TABLA 3: TIPOS DE MEMBRESIA

CREATE TABLE TiposMembresia (
    TipoMembresiaID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(50),
    Descripcion NVARCHAR(200),
    DuracionDias INT,
    PrecioBase DECIMAL(10,2),
    Estado VARCHAR(15)
);
GO

-- TABLA 4: MEMBRESIAS

CREATE TABLE Membresias (
    MembresiaID INT IDENTITY(1,1) PRIMARY KEY,
    SocioID INT,
    TipoMembresiaID INT,
    FechaInicio DATE,
    FechaFin DATE,
    PrecioAplicado DECIMAL(10,2),
    Estado VARCHAR(15)
);
GO

-- TABLA 5: CLASES

CREATE TABLE Clases (
    ClaseID INT IDENTITY(1,1) PRIMARY KEY,
    Nombre NVARCHAR(80),
    Descripcion NVARCHAR(200),
    EntrenadorID INT,
    FechaHoraInicio DATETIME2,
    FechaHoraFin DATETIME2,
    Capacidad INT,
    Sala NVARCHAR(50),
    Estado VARCHAR(15)
);
GO

-- TABLA 6: RESERVACIONES

CREATE TABLE Reservaciones (
    ReservacionID INT IDENTITY(1,1) PRIMARY KEY,
    SocioID INT,
    ClaseID INT,
    FechaReservacion DATETIME2,
    Estado VARCHAR(15)
);
GO

-- TABLA 7: PAGOS

CREATE TABLE Pagos (
    PagoID INT IDENTITY(1,1) PRIMARY KEY,
    MembresiaID INT,
    FechaPago DATETIME2,
    Monto DECIMAL(10,2),
    MetodoPago VARCHAR(30),
    Referencia VARCHAR(100),
    Estado VARCHAR(15)
);
GO

-- TABLA 8: ASISTENCIAS

CREATE TABLE Asistencias (
    AsistenciaID INT IDENTITY(1,1) PRIMARY KEY,
    ReservacionID INT,
    FechaRegistro DATETIME2,
    EstadoAsistencia VARCHAR(15)
);
GO

