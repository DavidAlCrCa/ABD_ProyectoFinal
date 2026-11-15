USE master;
GO

SELECT
    name AS BaseDatos,
    recovery_model_desc AS ModeloRecuperacion,
    state_desc AS Estado
FROM sys.databases
WHERE name = N'GimnasioDB';
GO

-- SQL Server Agent debe estar en ejecucion para que corran los jobs.
SELECT
    servicename AS Servicio,
    status_desc AS Estado
FROM sys.dm_server_services
WHERE servicename LIKE N'%Agent%';
GO

/*
-------------------------------------------------
Comandos para ejecutar en PowerShell / terminal del host
(solo si las carpetas no se crean desde el repositorio)
-------------------------------------------------

-- Carpetas de respaldo dentro del contenedor:
docker exec -u 0 sqlserver-2025 bash -lc "mkdir -p /backup/GimnasioDB/FULL /backup/GimnasioDB/DIFF /backup/GimnasioDB/LOG && chown -R mssql:mssql /backup/GimnasioDB && chmod -R 770 /backup/GimnasioDB"

-- Comprobar que /backup este montado como volumen (persistente):
docker inspect sqlserver-2025 --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'

-- Si SQL Server Agent no esta en ejecucion:
docker exec -u 0 sqlserver-2025 /opt/mssql/bin/mssql-conf set sqlagent.enabled true
docker restart sqlserver-2025
*/
