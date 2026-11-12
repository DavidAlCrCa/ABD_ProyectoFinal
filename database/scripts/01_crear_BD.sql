
USE master;
GO

-- Crear la base de datos del gimnasio
IF DB_ID(N'GimnasioDB') IS NULL
BEGIN
    CREATE DATABASE GimnasioDB;
END;
GO
