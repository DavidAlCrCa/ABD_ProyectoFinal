USE master;
GO


--1. ESTADO Y MODELO DE RECUPERACION


SELECT
    name AS BaseDatos,
    state_desc AS Estado,
    recovery_model_desc AS ModeloRecuperacion
FROM sys.databases
WHERE name = N'GimnasioDB';
GO


--2. HISTORIAL COMPLETO DE RESPALDOS


SELECT
    bs.backup_start_date AS Inicio,
    bs.backup_finish_date AS Finalizacion,

    CASE bs.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFFERENTIAL'
        WHEN 'L' THEN 'LOG'
        ELSE bs.type
    END AS TipoRespaldo,

    CAST(
        bs.backup_size / 1024.0 / 1024.0
        AS DECIMAL(12,2)
    ) AS TamanoMB,

    bs.is_copy_only AS CopyOnly,
    mf.physical_device_name AS RutaArchivo

FROM msdb.dbo.backupset AS bs

INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id

WHERE bs.database_name = N'GimnasioDB'

ORDER BY bs.backup_finish_date DESC;
GO


--3. ULTIMO RESPALDO DE CADA TIPO


SELECT
    'FULL' AS TipoRespaldo,
    MAX(backup_finish_date) AS UltimoRespaldo,
    CASE
        WHEN MAX(backup_finish_date) IS NULL
            THEN 'SIN RESPALDOS'
        WHEN MAX(backup_finish_date) < DATEADD(DAY, -7, GETDATE())
            THEN 'ATRASADO'
        ELSE 'ACTUALIZADO'
    END AS Estado

FROM msdb.dbo.backupset
WHERE database_name = N'GimnasioDB'
  AND type = 'D'

UNION ALL

SELECT
    'DIFF',
    MAX(backup_finish_date),
    CASE
        WHEN MAX(backup_finish_date) IS NULL
            THEN 'SIN RESPALDOS'
        WHEN MAX(backup_finish_date) < DATEADD(HOUR, -24, GETDATE())
            THEN 'ATRASADO'
        ELSE 'ACTUALIZADO'
    END

FROM msdb.dbo.backupset
WHERE database_name = N'GimnasioDB'
  AND type = 'I'

UNION ALL

SELECT
    'LOG',
    MAX(backup_finish_date),
    CASE
        WHEN MAX(backup_finish_date) IS NULL
            THEN 'SIN RESPALDOS'
        WHEN MAX(backup_finish_date) < DATEADD(MINUTE, -75, GETDATE())
            THEN 'ATRASADO'
        ELSE 'ACTUALIZADO'
    END

FROM msdb.dbo.backupset
WHERE database_name = N'GimnasioDB'
  AND type = 'L';
GO


--4. JOBS Y PROGRAMACIONES


SELECT
    j.name AS Job,
    j.enabled AS Habilitado,
    s.name AS Programacion

FROM msdb.dbo.sysjobs AS j

LEFT JOIN msdb.dbo.sysjobschedules AS js
    ON j.job_id = js.job_id

LEFT JOIN msdb.dbo.sysschedules AS s
    ON js.schedule_id = s.schedule_id

WHERE j.name LIKE N'GimnasioDB%'

ORDER BY j.name;
GO

  
--5. ULTIMA EJECUCION DE CADA JOB


SELECT
    j.name AS Job,

    CASE
        WHEN h.instance_id IS NULL THEN 'SIN HISTORIAL'
        ELSE CONVERT(VARCHAR(10),
            CONVERT(DATE,
                CONVERT(CHAR(8), h.run_date)
            ), 103)
    END AS Fecha,

    STUFF(
        STUFF(
            RIGHT('000000' + CAST(h.run_time AS VARCHAR(6)), 6),
            3, 0, ':'
        ),
        6, 0, ':'
    ) AS Hora,

    CASE h.run_status
        WHEN 0 THEN 'FALLO'
        WHEN 1 THEN 'CORRECTO'
        WHEN 2 THEN 'REINTENTO'
        WHEN 3 THEN 'CANCELADO'
        WHEN 4 THEN 'EN PROGRESO'
        ELSE 'SIN HISTORIAL'
    END AS Resultado,

    h.message AS Mensaje

FROM msdb.dbo.sysjobs AS j

OUTER APPLY
(
    SELECT TOP (1) *
    FROM msdb.dbo.sysjobhistory AS x
    WHERE x.job_id = j.job_id
      AND x.step_id = 0
    ORDER BY x.instance_id DESC
) AS h

WHERE j.name LIKE N'GimnasioDB%'

ORDER BY j.name;
GO


--6. BITACORA DE INCIDENCIAS DE RESPALDOS


IF OBJECT_ID(N'GimnasioDB.dbo.BitacoraRespaldos', N'U') IS NOT NULL
BEGIN
    SELECT
        BitacoraID,
        TipoRespaldo,
        Estado,
        FechaDeteccion,
        FechaResolucion,
        Descripcion
    FROM GimnasioDB.dbo.BitacoraRespaldos
    ORDER BY BitacoraID DESC;
END
ELSE
BEGIN
    PRINT N'La tabla BitacoraRespaldos todavia no existe.';
END;
GO


--7. INCIDENCIAS QUE SIGUEN PENDIENTES


IF OBJECT_ID(N'GimnasioDB.dbo.BitacoraRespaldos', N'U') IS NOT NULL
BEGIN
    SELECT
        TipoRespaldo,
        FechaDeteccion,
        Descripcion
    FROM GimnasioDB.dbo.BitacoraRespaldos
    WHERE Estado = 'PENDIENTE'
    ORDER BY FechaDeteccion DESC;
END;
GO


--8. ARCHIVOS FISICOS DE GIMNASIODB


SELECT
    name AS NombreLogico,
    type_desc AS TipoArchivo,
    physical_name AS RutaFisica,
    size * 8.0 / 1024 AS TamanoMB

FROM GimnasioDB.sys.database_files;
GO

--9. VERIFICACION FISICA DE LOS ULTIMOS RESPALDOS (RESTORE VERIFYONLY)


DECLARE @Full NVARCHAR(4000);
DECLARE @Diff NVARCHAR(4000);
DECLARE @Log  NVARCHAR(4000);
DECLARE @SQL  NVARCHAR(MAX);

SELECT TOP (1)
    @Full = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type = 'D'
ORDER BY bs.backup_finish_date DESC;

SELECT TOP (1)
    @Diff = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type = 'I'
ORDER BY bs.backup_finish_date DESC;

SELECT TOP (1)
    @Log = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type = 'L'
ORDER BY bs.backup_finish_date DESC;

IF @Full IS NOT NULL
BEGIN
    SET @SQL = N'RESTORE VERIFYONLY FROM DISK = N''' + REPLACE(@Full, '''', '''''') + N''' WITH CHECKSUM;';
    EXEC sys.sp_executesql @SQL;
    PRINT N'FULL verificado: ' + @Full;
END
ELSE
    PRINT N'Todavia no existe un respaldo FULL.';

IF @Diff IS NOT NULL
BEGIN
    SET @SQL = N'RESTORE VERIFYONLY FROM DISK = N''' + REPLACE(@Diff, '''', '''''') + N''' WITH CHECKSUM;';
    EXEC sys.sp_executesql @SQL;
    PRINT N'DIFFERENTIAL verificado: ' + @Diff;
END
ELSE
    PRINT N'Todavia no existe un respaldo diferencial.';

IF @Log IS NOT NULL
BEGIN
    SET @SQL = N'RESTORE VERIFYONLY FROM DISK = N''' + REPLACE(@Log, '''', '''''') + N''' WITH CHECKSUM;';
    EXEC sys.sp_executesql @SQL;
    PRINT N'LOG verificado: ' + @Log;
END
ELSE
    PRINT N'Todavia no existe un respaldo LOG.';
GO

PRINT N'Verificacion de respaldos finalizada.';
GO
