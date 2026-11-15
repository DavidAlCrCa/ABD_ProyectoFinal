
USE master;
GO

-- 1. Ruta de los archivos MDF y LDF de GimnasioDB.
SELECT
    DB_NAME(database_id) AS BaseDatos,
    name AS NombreLogico,
    type_desc AS TipoArchivo,
    physical_name AS RutaFisica,
    size * 8.0 / 1024 AS TamanoMB
FROM sys.master_files
WHERE database_id = DB_ID(N'GimnasioDB');
GO

-- 2. Rutas de respaldos registradas en msdb.
SELECT
    bs.database_name AS BaseDatos,
    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFFERENTIAL'
        WHEN 'L' THEN 'LOG'
        ELSE bs.type
    END AS TipoRespaldo,
    bs.backup_finish_date AS FechaFinalizacion,
    mf.physical_device_name AS RutaRespaldo
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = N'GimnasioDB'
ORDER BY bs.backup_finish_date DESC;
GO
