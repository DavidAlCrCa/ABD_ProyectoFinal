USE GimnasioDB;
GO
-- 1. Esquemas organizativos, sin transferir objetos existentes
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'administracion') EXEC(N'CREATE SCHEMA administracion AUTHORIZATION dbo');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'recepcion') EXEC(N'CREATE SCHEMA recepcion AUTHORIZATION dbo');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'operaciones') EXEC(N'CREATE SCHEMA operaciones AUTHORIZATION dbo');
GO
-- 2. Roles
IF DATABASE_PRINCIPAL_ID(N'rol_administrador') IS NULL CREATE ROLE rol_administrador AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_recepcionista') IS NULL CREATE ROLE rol_recepcionista AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_entrenador') IS NULL CREATE ROLE rol_entrenador AUTHORIZATION dbo;
GO
-- 3. Permisos explicitos por tabla. Evitar db_owner/db_datareader/db_datawriter.
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Socios TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Membresias TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.TiposMembresia TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Pagos TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Asistencias TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Clases TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Entrenadores TO rol_administrador;
GRANT SELECT, INSERT, UPDATE, DELETE ON OBJECT::dbo.Reservaciones TO rol_administrador;
GO
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Socios TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Membresias TO rol_recepcionista;
GRANT SELECT ON OBJECT::dbo.TiposMembresia TO rol_recepcionista;
GRANT SELECT, INSERT ON OBJECT::dbo.Pagos TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Asistencias TO rol_recepcionista;
GRANT SELECT ON OBJECT::dbo.Clases TO rol_recepcionista;
GRANT SELECT ON OBJECT::dbo.Entrenadores TO rol_recepcionista;
GRANT SELECT, INSERT, UPDATE ON OBJECT::dbo.Reservaciones TO rol_recepcionista;
GO
GRANT SELECT ON OBJECT::dbo.Socios TO rol_entrenador;
GRANT SELECT, INSERT ON OBJECT::dbo.Asistencias TO rol_entrenador;
GRANT SELECT ON OBJECT::dbo.Clases TO rol_entrenador;
GRANT SELECT ON OBJECT::dbo.Entrenadores TO rol_entrenador;
GRANT SELECT ON OBJECT::dbo.Reservaciones TO rol_entrenador;
GO
-- 4. Usuarios de prueba SIN LOGIN
IF DATABASE_PRINCIPAL_ID(N'usuario_admin_demo') IS NULL CREATE USER usuario_admin_demo WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID(N'usuario_recepcion_demo') IS NULL CREATE USER usuario_recepcion_demo WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID(N'usuario_entrenador_demo') IS NULL CREATE USER usuario_entrenador_demo WITHOUT LOGIN;
GO
IF IS_ROLEMEMBER(N'rol_administrador', N'usuario_admin_demo') <> 1 ALTER ROLE rol_administrador ADD MEMBER usuario_admin_demo;
IF IS_ROLEMEMBER(N'rol_recepcionista', N'usuario_recepcion_demo') <> 1 ALTER ROLE rol_recepcionista ADD MEMBER usuario_recepcion_demo;
IF IS_ROLEMEMBER(N'rol_entrenador', N'usuario_entrenador_demo') <> 1 ALTER ROLE rol_entrenador ADD MEMBER usuario_entrenador_demo;
GO
/*
USE master;
GO
CREATE SERVER AUDIT AuditoriaGimnasio
TO FILE (FILEPATH = '/var/opt/mssql/audit/', MAXSIZE = 50 MB, MAX_ROLLOVER_FILES = 10)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO
ALTER SERVER AUDIT AuditoriaGimnasio WITH (STATE = ON);
GO
USE GimnasioDB;
GO
CREATE DATABASE AUDIT SPECIFICATION AuditoriaOperacionesGimnasio
FOR SERVER AUDIT AuditoriaGimnasio
    ADD (INSERT, UPDATE, DELETE ON OBJECT::dbo.Pagos BY PUBLIC),
    ADD (INSERT, UPDATE, DELETE ON OBJECT::dbo.Membresias BY PUBLIC),
    ADD (DELETE ON OBJECT::dbo.Socios BY PUBLIC),
    ADD (INSERT, UPDATE, DELETE ON OBJECT::dbo.Reservaciones BY PUBLIC),
    ADD (DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
    ADD (DATABASE_PRINCIPAL_CHANGE_GROUP),
    ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO
-- Consulta de eventos (adaptar ruta)
SELECT event_time, action_id, succeeded, server_principal_name,
       database_principal_name, schema_name, object_name, statement
FROM sys.fn_get_audit_file('/var/opt/mssql/audit/*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO
*/
-- 6. Pruebas de acceso no destructivas
EXECUTE AS USER = 'usuario_recepcion_demo';
SELECT USER_NAME() AS usuario_actual,
       HAS_PERMS_BY_NAME('dbo.Pagos','OBJECT','INSERT') AS puede_insertar_pagos,
       HAS_PERMS_BY_NAME('dbo.Pagos','OBJECT','DELETE') AS puede_eliminar_pagos;
REVERT;
GO
EXECUTE AS USER = 'usuario_entrenador_demo';
SELECT USER_NAME() AS usuario_actual,
       HAS_PERMS_BY_NAME('dbo.Clases','OBJECT','SELECT') AS puede_ver_clases,
       HAS_PERMS_BY_NAME('dbo.Pagos','OBJECT','SELECT') AS puede_ver_pagos;
REVERT;
GO
-- Revisar concesiones
SELECT pr.name AS rol, ob.name AS objeto, pe.permission_name, pe.state_desc
FROM sys.database_permissions AS pe
JOIN sys.database_principals AS pr ON pr.principal_id = pe.grantee_principal_id
JOIN sys.objects AS ob ON ob.object_id = pe.major_id
WHERE pr.name IN ('rol_administrador','rol_recepcionista','rol_entrenador')
ORDER BY pr.name, ob.name, pe.permission_name;
GO

