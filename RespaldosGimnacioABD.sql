--Ejecutar en powershell

-- docker inspect sqlserver-2025 --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
-- docker exec -u 0 sqlserver-2025 bash -lc "mkdir -p /var/opt/mssql/backup/Gimnasio/FULL /var/opt/mssql/backup/Gimnasio/DIFF /var/opt/mssql/backup/Gimnasio/LOG && chown -R mssql:mssql /var/opt/mssql/backup/Gimnasio && chmod -R 770 /var/opt/mssql/backup/Gimnasio"


--Habilitar sql server agent
SELECT
    servicename,
    status_desc
FROM sys.dm_server_services
WHERE servicename LIKE '%Agent%';
GO


--Para habilitar la funcionalidad en caso de que no lo este 
--Ejecutar en powershell
-- docker exec -u 0 sqlserver-2025 /opt/mssql/bin/mssql-conf set sqlagent.enabled true
-- docker restart sqlserver-2025



--Creacion respaldo full

USE master;
GO

-- Comprobar que la base de datos exista.
IF DB_ID(N'Gimnasio') IS NULL
BEGIN
    THROW 50001, 'La base de datos Gimnasio aun no existe.', 1;
END;
GO

-- Configurar el modelo de recuperación FULL.
ALTER DATABASE [Gimnasio]
SET RECOVERY FULL;
GO

-- Generar un nombre con fecha y hora.
DECLARE @MarcaTiempo CHAR(15);
DECLARE @Archivo NVARCHAR(4000);

SET @MarcaTiempo =
    CONVERT(CHAR(8), GETDATE(), 112)
    + '_'
    + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '');

SET @Archivo =
    N'/var/opt/mssql/backup/Gimnasio/FULL/Gimnasio_FULL_INICIAL_'
    + @MarcaTiempo
    + N'.bak';

-- Crear el primer respaldo completo.
BACKUP DATABASE [Gimnasio]
TO DISK = @Archivo
WITH
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

-- Comprobar que el archivo se pueda leer.
RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
GO


--Job de respaldo full

USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Gimnasio - Respaldo FULL',
    @enabled = 1,
    @description = N'Respaldo completo semanal de la base Gimnasio.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'Gimnasio - Respaldo FULL',
    @step_name = N'Crear y verificar FULL',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
IF DB_ID(N''Gimnasio'') IS NULL
BEGIN
    THROW 50001, N''No existe la base de datos Gimnasio.'', 1;
END;

DECLARE @MarcaTiempo CHAR(15);
DECLARE @Archivo NVARCHAR(4000);

SET @MarcaTiempo =
    CONVERT(CHAR(8), GETDATE(), 112)
    + ''_''
    + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

SET @Archivo =
    N''/var/opt/mssql/backup/Gimnasio/FULL/Gimnasio_FULL_''
    + @MarcaTiempo
    + N''.bak'';

BACKUP DATABASE [Gimnasio]
TO DISK = @Archivo
WITH COMPRESSION, CHECKSUM, STATS = 10;

RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Horario FULL - Domingo',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 000500;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'Gimnasio - Respaldo FULL',
    @schedule_name = N'Horario FULL - Domingo';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'Gimnasio - Respaldo FULL',
    @server_name = N'(LOCAL)';
GO





--Crear job respaldo differential
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Gimnasio - Respaldo DIFFERENTIAL',
    @enabled = 1,
    @description = N'Respaldo diferencial diario de la base Gimnasio.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'Gimnasio - Respaldo DIFFERENTIAL',
    @step_name = N'Crear y verificar DIFFERENTIAL',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
IF DB_ID(N''Gimnasio'') IS NULL
BEGIN
    THROW 50002, N''No existe la base de datos Gimnasio.'', 1;
END;

DECLARE @MarcaTiempo CHAR(15);
DECLARE @Archivo NVARCHAR(4000);

SET @MarcaTiempo =
    CONVERT(CHAR(8), GETDATE(), 112)
    + ''_''
    + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

SET @Archivo =
    N''/var/opt/mssql/backup/Gimnasio/DIFF/Gimnasio_DIFF_''
    + @MarcaTiempo
    + N''.bak'';

BACKUP DATABASE [Gimnasio]
TO DISK = @Archivo
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, STATS = 10;

RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Horario DIFFERENTIAL - Diario',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'Gimnasio - Respaldo DIFFERENTIAL',
    @schedule_name = N'Horario DIFFERENTIAL - Diario';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'Gimnasio - Respaldo DIFFERENTIAL',
    @server_name = N'(LOCAL)';
GO



--Crear job respaldo LOG

USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Gimnasio - Respaldo LOG',
    @enabled = 1,
    @description = N'Respaldo del registro de transacciones cada hora.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'Gimnasio - Respaldo LOG',
    @step_name = N'Crear y verificar LOG',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
IF DB_ID(N''Gimnasio'') IS NULL
BEGIN
    THROW 50003, N''No existe la base de datos Gimnasio.'', 1;
END;

DECLARE @MarcaTiempo CHAR(15);
DECLARE @Archivo NVARCHAR(4000);

SET @MarcaTiempo =
    CONVERT(CHAR(8), GETDATE(), 112)
    + ''_''
    + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

SET @Archivo =
    N''/var/opt/mssql/backup/Gimnasio/LOG/Gimnasio_LOG_''
    + @MarcaTiempo
    + N''.trn'';

BACKUP LOG [Gimnasio]
TO DISK = @Archivo
WITH COMPRESSION, CHECKSUM, STATS = 10;

RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Horario LOG - Cada Hora',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 1,
    @active_start_time = 003000,
    @active_end_time = 233000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'Gimnasio - Respaldo LOG',
    @schedule_name = N'Horario LOG - Cada Hora';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'Gimnasio - Respaldo LOG',
    @server_name = N'(LOCAL)';
GO




--Procedimiento de limpieza automatico

USE [Gimnasio];
GO

CREATE OR ALTER PROCEDURE dbo.usp_LimpiarRespaldos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BaseDatos SYSNAME = N'Gimnasio';
    DECLARE @Ahora DATETIME = GETDATE();

    DECLARE @IdFullAncla INT;
    DECLARE @FechaFullAncla DATETIME;
    DECLARE @UltimoFull DATETIME;
    DECLARE @PrimerLog DATETIME;
    DECLARE @UltimoLog DATETIME;

    DECLARE @Archivo NVARCHAR(4000);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ArchivosVerificados INT = 0;

    -- Umbrales de conservacion:
    -- FULL: 30 dias.
    -- DIFFERENTIAL: 7 dias.
    -- LOG: 22 dias.

    DECLARE @CorteFull DATETIME =
        DATEADD(DAY, -30, @Ahora);

    DECLARE @CorteDiff DATETIME =
        DATEADD(DAY, -7, @Ahora);

    DECLARE @CorteLog DATETIME =
        DATEADD(DAY, -22, @Ahora);

    -------------------------------------------------
    -- 1. Buscar el FULL que sirve de base
    -- para recuperar los ultimos 14 dias.
    -------------------------------------------------

    SELECT TOP (1)
        @IdFullAncla = backup_set_id,
        @FechaFullAncla = backup_finish_date
    FROM msdb.dbo.backupset
    WHERE database_name = @BaseDatos
      AND type = 'D'
      AND is_copy_only = 0
      AND backup_finish_date <= DATEADD(DAY, -14, @Ahora)
    ORDER BY backup_finish_date DESC;

    -- Si todavia no hay 14 dias de historial,
    -- no hay nada que limpiar por esta politica.
    IF @IdFullAncla IS NULL
    BEGIN
        PRINT 'Limpieza omitida: aun no existe un FULL anterior al periodo de 14 dias.';
        RETURN;
    END;

    -------------------------------------------------
    -- 2. Comprobar que el FULL ancla no sea
    -- demasiado antiguo.
    -------------------------------------------------

    IF @FechaFullAncla < DATEADD(DAY, -22, @Ahora)
    BEGIN
        THROW 51001,
            'Limpieza cancelada: el FULL necesario para la recuperacion es demasiado antiguo.',
            1;
    END;

    -------------------------------------------------
    -- 3. Comprobar que exista un FULL reciente.
    -------------------------------------------------

    SELECT
        @UltimoFull = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = @BaseDatos
      AND type = 'D'
      AND is_copy_only = 0;

    IF @UltimoFull IS NULL
       OR @UltimoFull < DATEADD(DAY, -8, @Ahora)
    BEGIN
        THROW 51002,
            'Limpieza cancelada: no existe un respaldo FULL reciente.',
            1;
    END;

    -------------------------------------------------
    -- 4. Comprobar los respaldos LOG.
    -------------------------------------------------

    SELECT
        @PrimerLog = MIN(backup_start_date),
        @UltimoLog = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = @BaseDatos
      AND type = 'L'
      AND backup_finish_date > @FechaFullAncla;

    IF @PrimerLog IS NULL OR @UltimoLog IS NULL
    BEGIN
        THROW 51003,
            'Limpieza cancelada: no se encontro una cadena LOG posterior al FULL ancla.',
            1;
    END;

    IF @PrimerLog > DATEADD(HOUR, 2, @FechaFullAncla)
    BEGIN
        THROW 51004,
            'Limpieza cancelada: no se encontro oportunamente el primer respaldo LOG.',
            1;
    END;

    IF @UltimoLog < DATEADD(HOUR, -2, @Ahora)
    BEGIN
        THROW 51005,
            'Limpieza cancelada: el ultimo respaldo LOG es demasiado antiguo.',
            1;
    END;

    -------------------------------------------------
    -- 5. Revisar continuidad de los LSN y horarios.
    -------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                backup_start_date,
                first_lsn,
                LAG(last_lsn) OVER
                (
                    ORDER BY backup_start_date, backup_set_id
                ) AS LSNAnterior,

                LAG(backup_finish_date) OVER
                (
                    ORDER BY backup_start_date, backup_set_id
                ) AS FinalAnterior

            FROM msdb.dbo.backupset
            WHERE database_name = @BaseDatos
              AND type = 'L'
              AND backup_finish_date > @FechaFullAncla
        ) AS Secuencia

        WHERE
            (LSNAnterior IS NOT NULL
             AND first_lsn > LSNAnterior)

            OR

            (FinalAnterior IS NOT NULL
             AND backup_start_date > DATEADD(HOUR, 2, FinalAnterior))
    )
    BEGIN
        THROW 51006,
            'Limpieza cancelada: se detecto una posible interrupcion en la cadena LOG.',
            1;
    END;

    -------------------------------------------------
    -- 6. Verificar fisicamente el FULL ancla
    -- y todos los LOG posteriores a ese FULL.
    -------------------------------------------------

    DECLARE CursorRespaldos CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT DISTINCT
            f.physical_device_name

        FROM msdb.dbo.backupset AS b

        INNER JOIN msdb.dbo.backupmediafamily AS f
            ON b.media_set_id = f.media_set_id

        WHERE
            b.backup_set_id = @IdFullAncla

            OR

            (
                b.database_name = @BaseDatos
                AND b.type = 'L'
                AND b.backup_finish_date > @FechaFullAncla
            );

    OPEN CursorRespaldos;

    FETCH NEXT FROM CursorRespaldos
    INTO @Archivo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL =
            N'RESTORE VERIFYONLY FROM DISK = N'''
            + REPLACE(@Archivo, '''', '''''')
            + N''' WITH CHECKSUM;';

        -- Si una verificacion falla, el procedimiento
        -- se detiene antes de eliminar archivos.
        EXEC sys.sp_executesql @SQL;

        SET @ArchivosVerificados = @ArchivosVerificados + 1;

        FETCH NEXT FROM CursorRespaldos
        INTO @Archivo;
    END;

    CLOSE CursorRespaldos;
    DEALLOCATE CursorRespaldos;

    IF @ArchivosVerificados = 0
    BEGIN
        THROW 51007,
            'Limpieza cancelada: no se verificaron archivos de respaldo.',
            1;
    END;

    -------------------------------------------------
    -- 7. Eliminar diferenciales de mas de 7 dias.
    -------------------------------------------------

    EXEC master.dbo.xp_delete_file
        0,
        N'/var/opt/mssql/backup/Gimnasio/DIFF',
        N'bak',
        @CorteDiff,
        0;

    -------------------------------------------------
    -- 8. Eliminar FULL de mas de 30 dias.
    -------------------------------------------------

    EXEC master.dbo.xp_delete_file
        0,
        N'/var/opt/mssql/backup/Gimnasio/FULL',
        N'bak',
        @CorteFull,
        0;

    -------------------------------------------------
    -- 9. Eliminar LOG de mas de 22 dias.
    -- Se realiza al final porque son necesarios
    -- para la recuperacion a un punto en el tiempo.
    -------------------------------------------------

    EXEC master.dbo.xp_delete_file
        0,
        N'/var/opt/mssql/backup/Gimnasio/LOG',
        N'trn',
        @CorteLog,
        0;

    PRINT 'Limpieza terminada correctamente.';
    PRINT 'FULL: conservacion de 30 dias.';
    PRINT 'DIFFERENTIAL: conservacion de 7 dias.';
    PRINT 'LOG: conservacion de 22 dias.';
END;
GO




--Job de limpieza automatica

USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Gimnasio - Limpieza de respaldos',
    @enabled = 1,
    @description = N'Elimina respaldos antiguos despues de verificar las dependencias de recuperacion.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'Gimnasio - Limpieza de respaldos',
    @step_name = N'Verificar y limpiar archivos antiguos',
    @subsystem = N'TSQL',
    @database_name = N'Gimnasio',
    @command = N'EXEC dbo.usp_LimpiarRespaldos;',
    @retry_attempts = 1,
    @retry_interval = 10;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Horario LIMPIEZA - Diario',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 040000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'Gimnasio - Limpieza de respaldos',
    @schedule_name = N'Horario LIMPIEZA - Diario';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'Gimnasio - Limpieza de respaldos',
    @server_name = N'(LOCAL)';
GO



--Comprobacion de respaldos creados correctamente
USE msdb;
GO

SELECT
    name AS NombreJob,
    enabled AS Habilitado,
    date_created AS FechaCreacion
FROM dbo.sysjobs
WHERE name LIKE 'Gimnasio -%'
ORDER BY name;
GO

SELECT
    b.database_name AS BaseDatos,

    CASE b.type
        WHEN 'D' THEN 'FULL'
        WHEN 'I' THEN 'DIFFERENTIAL'
        WHEN 'L' THEN 'LOG'
        ELSE b.type
    END AS TipoRespaldo,

    b.backup_start_date AS Inicio,
    b.backup_finish_date AS Finalizacion,

    CAST(b.compressed_backup_size / 1048576.0 AS DECIMAL(10,2))
        AS TamanoMB,

    b.has_backup_checksums AS TieneChecksum,

    f.physical_device_name AS Archivo

FROM msdb.dbo.backupset AS b

INNER JOIN msdb.dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id

WHERE b.database_name = N'Gimnasio'

ORDER BY b.backup_finish_date DESC;
GO

DECLARE @Full NVARCHAR(4000);
DECLARE @Diff NVARCHAR(4000);
DECLARE @Log NVARCHAR(4000);
DECLARE @SQL NVARCHAR(MAX);

-- Localizar el ultimo FULL.
SELECT TOP (1)
    @Full = f.physical_device_name
FROM msdb.dbo.backupset AS b
INNER JOIN msdb.dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id
WHERE b.database_name = N'Gimnasio'
  AND b.type = 'D'
ORDER BY b.backup_finish_date DESC;

-- Localizar el ultimo diferencial.
SELECT TOP (1)
    @Diff = f.physical_device_name
FROM msdb.dbo.backupset AS b
INNER JOIN msdb.dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id
WHERE b.database_name = N'Gimnasio'
  AND b.type = 'I'
ORDER BY b.backup_finish_date DESC;

-- Localizar el ultimo LOG.
SELECT TOP (1)
    @Log = f.physical_device_name
FROM msdb.dbo.backupset AS b
INNER JOIN msdb.dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id
WHERE b.database_name = N'Gimnasio'
  AND b.type = 'L'
ORDER BY b.backup_finish_date DESC;

-- Verificar FULL.
IF @Full IS NOT NULL
BEGIN
    SET @SQL =
        N'RESTORE VERIFYONLY FROM DISK = N'''
        + REPLACE(@Full, '''', '''''')
        + N''' WITH CHECKSUM;';

    EXEC sys.sp_executesql @SQL;
END
ELSE
    PRINT 'Todavia no existe un respaldo FULL.';

-- Verificar diferencial.
IF @Diff IS NOT NULL
BEGIN
    SET @SQL =
        N'RESTORE VERIFYONLY FROM DISK = N'''
        + REPLACE(@Diff, '''', '''''')
        + N''' WITH CHECKSUM;';

    EXEC sys.sp_executesql @SQL;
END
ELSE
    PRINT 'Todavia no existe un respaldo diferencial.';

-- Verificar LOG.
IF @Log IS NOT NULL
BEGIN
    SET @SQL =
        N'RESTORE VERIFYONLY FROM DISK = N'''
        + REPLACE(@Log, '''', '''''')
        + N''' WITH CHECKSUM;';

    EXEC sys.sp_executesql @SQL;
END
ELSE
    PRINT 'Todavia no existe un respaldo LOG.';
GO


--Pruebas de restauracion
USE msdb;
GO

DECLARE @IdFull INT;
DECLARE @GuidFull UNIQUEIDENTIFIER;
DECLARE @FechaDiff DATETIME;
DECLARE @ArchivoFull NVARCHAR(4000);
DECLARE @ArchivoDiff NVARCHAR(4000);

-- Encontrar el FULL mas reciente.
SELECT TOP (1)
    @IdFull = b.backup_set_id,
    @GuidFull = b.backup_set_uuid,
    @ArchivoFull = f.physical_device_name
FROM dbo.backupset AS b
INNER JOIN dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id
WHERE b.database_name = N'Gimnasio'
  AND b.type = 'D'
  AND b.is_copy_only = 0
ORDER BY b.backup_finish_date DESC;

-- Encontrar el diferencial basado en ese FULL.
SELECT TOP (1)
    @FechaDiff = d.backup_finish_date,
    @ArchivoDiff = f.physical_device_name
FROM dbo.backupset AS d
INNER JOIN dbo.backupmediafamily AS f
    ON d.media_set_id = f.media_set_id
WHERE d.database_name = N'Gimnasio'
  AND d.type = 'I'
  AND d.differential_base_guid = @GuidFull
ORDER BY d.backup_finish_date DESC;

SELECT
    @ArchivoFull AS ArchivoFULL,
    @ArchivoDiff AS ArchivoDIFFERENTIAL,
    @FechaDiff AS FechaDiferencial;
GO

RESTORE FILELISTONLY
FROM DISK = N'-- PEGA AQUI LA RUTA DEL ARCHIVO FULL';
GO

--Restaurar full

RESTORE DATABASE [Gimnasio_Validacion]
FROM DISK =
    N'-- PEGA AQUI LA RUTA DEL ARCHIVO FULL'

WITH
    MOVE N'-- NOMBRE LOGICO DEL ARCHIVO DE DATOS'
        TO N'-- RUTA FISICA NUEVA PARA EL MDF',

    MOVE N'-- NOMBRE LOGICO DEL ARCHIVO LOG'
        TO N'-- RUTA FISICA NUEVA PARA EL LDF',

    NORECOVERY,
    STATS = 10;
GO

--Restaurar differential
RESTORE DATABASE [Gimnasio_Validacion]
FROM DISK =
    N'-- PEGA AQUI LA RUTA DEL ARCHIVO DIFFERENTIAL'
WITH NORECOVERY, STATS = 10;
GO

--Restaurar LOG
USE msdb;
GO

DECLARE @GuidFull UNIQUEIDENTIFIER;
DECLARE @FechaDiff DATETIME;

-- Obtener el ultimo FULL.
SELECT TOP (1)
    @GuidFull = backup_set_uuid
FROM dbo.backupset
WHERE database_name = N'Gimnasio'
  AND type = 'D'
  AND is_copy_only = 0
ORDER BY backup_finish_date DESC;

-- Obtener fecha del diferencial basado en ese FULL.
SELECT TOP (1)
    @FechaDiff = backup_finish_date
FROM dbo.backupset
WHERE database_name = N'Gimnasio'
  AND type = 'I'
  AND differential_base_guid = @GuidFull
ORDER BY backup_finish_date DESC;

-- Generar los comandos RESTORE LOG en orden.
SELECT
    b.backup_finish_date AS FechaRespaldo,

    N'RESTORE LOG [Gimnasio_Validacion] FROM DISK = N'''
    + REPLACE(f.physical_device_name, '''', '''''')
    + N''' WITH NORECOVERY;' AS ComandoRestauracion

FROM dbo.backupset AS b
INNER JOIN dbo.backupmediafamily AS f
    ON b.media_set_id = f.media_set_id

WHERE b.database_name = N'Gimnasio'
  AND b.type = 'L'
  AND b.backup_finish_date > @FechaDiff

ORDER BY b.backup_start_date, b.backup_set_id;
GO

--Finalizar restauracion
RESTORE DATABASE [Gimnasio_Validacion]
WITH RECOVERY;
GO

--Probar base restaurada
SELECT
    name,
    state_desc
FROM sys.databases
WHERE name = N'Gimnasio_Validacion';
GO

DBCC CHECKDB (N'Gimnasio_Validacion')
WITH NO_INFOMSGS;
GO

USE Gimnasio_Validacion;
GO

SELECT 'Socios' AS Tabla, COUNT_BIG(*) AS Registros
FROM dbo.Socios

UNION ALL

SELECT 'Entrenadores', COUNT_BIG(*)
FROM dbo.Entrenadores

UNION ALL

SELECT 'TiposMembresia', COUNT_BIG(*)
FROM dbo.TiposMembresia

UNION ALL

SELECT 'Membresias', COUNT_BIG(*)
FROM dbo.Membresias

UNION ALL

SELECT 'Clases', COUNT_BIG(*)
FROM dbo.Clases

UNION ALL

SELECT 'Reservaciones', COUNT_BIG(*)
FROM dbo.Reservaciones

UNION ALL

SELECT 'Pagos', COUNT_BIG(*)
FROM dbo.Pagos

UNION ALL

SELECT 'Asistencias', COUNT_BIG(*)
FROM dbo.Asistencias;
GO