USE master;
GO

-- Prueba de restauracion completa de GimnasioDB en GimnasioDB_RestauracionPrueba:
--   FULL mas reciente -> DIFFERENTIAL basado en ese FULL -> LOG posteriores -> RECOVERY.
-- Las rutas y los nombres logicos se toman del historial de msdb: no hay que pegar nada.
-- Si la base de prueba ya existe (de una ejecucion anterior), se elimina y se vuelve a crear.

SET NOCOUNT ON;

IF DB_ID(N'GimnasioDB') IS NULL
    THROW 53001, 'No existe GimnasioDB.', 1;
GO

DECLARE @BaseOrigen   SYSNAME = N'GimnasioDB';
DECLARE @BaseDestino  SYSNAME = N'GimnasioDB_RestauracionPrueba';

DECLARE @IdFull        INT;
DECLARE @GuidFull      UNIQUEIDENTIFIER;
DECLARE @ArchivoFull   NVARCHAR(4000);
DECLARE @FechaFull     DATETIME;
DECLARE @LsnBase       NUMERIC(25,0);   -- ultimo LSN ya restaurado (FULL o DIFF)

DECLARE @ArchivoDiff   NVARCHAR(4000);
DECLARE @FechaDiff     DATETIME;

DECLARE @RutaDatos     NVARCHAR(260) =
    ISNULL(CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(260)), N'/var/opt/mssql/data/');
DECLARE @RutaLog       NVARCHAR(260) =
    ISNULL(CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS NVARCHAR(260)), N'/var/opt/mssql/data/');

DECLARE @Moves         NVARCHAR(MAX);
DECLARE @SQL           NVARCHAR(MAX);
DECLARE @ArchivoLog    NVARCHAR(4000);
DECLARE @TotalLogs     INT = 0;

IF @BaseDestino = @BaseOrigen
    THROW 53002, 'La base de destino no puede ser la misma que la de origen.', 1;

-------------------------------------------------
-- 1. Encontrar el FULL mas reciente.
-------------------------------------------------
SELECT TOP (1)
    @IdFull      = bs.backup_set_id,
    @GuidFull    = bs.backup_set_uuid,
    @LsnBase     = bs.last_lsn,
    @FechaFull   = bs.backup_finish_date,
    @ArchivoFull = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = @BaseOrigen
  AND bs.type = 'D'
  AND bs.is_copy_only = 0
ORDER BY bs.backup_finish_date DESC;

IF @IdFull IS NULL
    THROW 53003, 'No se encontro un respaldo FULL para restaurar.', 1;

-------------------------------------------------
-- 2. Encontrar el diferencial basado en ese FULL.
-------------------------------------------------
SELECT TOP (1)
    @FechaDiff   = bs.backup_finish_date,
    @ArchivoDiff = mf.physical_device_name,
    @LsnBase     = bs.last_lsn
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = @BaseOrigen
  AND bs.type = 'I'
  AND bs.differential_base_guid = @GuidFull
ORDER BY bs.backup_finish_date DESC;

SELECT
    @ArchivoFull AS ArchivoFULL,
    @FechaFull   AS FechaFull,
    @ArchivoDiff AS ArchivoDIFFERENTIAL,
    @FechaDiff   AS FechaDiferencial;

-------------------------------------------------
-- 3. Eliminar la base de prueba si ya existe.
-------------------------------------------------
IF DB_ID(@BaseDestino) IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM sys.databases
               WHERE name = @BaseDestino AND state_desc = N'ONLINE')
    BEGIN
        SET @SQL = N'ALTER DATABASE ' + QUOTENAME(@BaseDestino)
                 + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
        EXEC (@SQL);
    END;

    SET @SQL = N'DROP DATABASE ' + QUOTENAME(@BaseDestino) + N';';
    EXEC (@SQL);
END;

-------------------------------------------------
-- 4. Archivos que contiene el FULL (RESTORE FILELISTONLY).
-------------------------------------------------
SET @SQL = N'RESTORE FILELISTONLY FROM DISK = N'''
         + REPLACE(@ArchivoFull, '''', '''''') + N''';';
EXEC (@SQL);

-------------------------------------------------
-- 5. Armar los MOVE con los nombres logicos reales
--    y rutas nuevas para la base de prueba.
-------------------------------------------------
SELECT @Moves = STRING_AGG(CAST(
        N'MOVE N''' + REPLACE(x.logical_name, '''', '''''')
        + N''' TO N''' + REPLACE(x.destino, '''', '''''') + N'''' AS NVARCHAR(MAX)), N', ')
FROM
(
    SELECT
        logical_name,
        CASE file_type
            WHEN 'D' THEN @RutaDatos + @BaseDestino + N'_data'
                          + CAST(ROW_NUMBER() OVER (PARTITION BY file_type ORDER BY file_number) AS NVARCHAR(5))
                          + N'.mdf'
            ELSE          @RutaLog + @BaseDestino + N'_log'
                          + CAST(ROW_NUMBER() OVER (PARTITION BY file_type ORDER BY file_number) AS NVARCHAR(5))
                          + N'.ldf'
        END AS destino
    FROM msdb.dbo.backupfile
    WHERE backup_set_id = @IdFull
      AND file_type IN ('D', 'L')
) AS x;

IF @Moves IS NULL
    THROW 53004, 'No se encontraron los archivos del FULL en msdb.dbo.backupfile.', 1;

-------------------------------------------------
-- 6. Restaurar FULL (NORECOVERY).
-------------------------------------------------
PRINT N'Respaldo FULL seleccionado: ' + @ArchivoFull;

SET @SQL = N'RESTORE DATABASE ' + QUOTENAME(@BaseDestino)
         + N' FROM DISK = N''' + REPLACE(@ArchivoFull, '''', '''''') + N''''
         + N' WITH ' + @Moves + N', NORECOVERY, CHECKSUM, STATS = 10;';
EXEC (@SQL);

-------------------------------------------------
-- 7. Restaurar diferencial (NORECOVERY), si existe.
-------------------------------------------------
IF @ArchivoDiff IS NOT NULL
BEGIN
    PRINT N'Respaldo DIFFERENTIAL seleccionado: ' + @ArchivoDiff;

    SET @SQL = N'RESTORE DATABASE ' + QUOTENAME(@BaseDestino)
             + N' FROM DISK = N''' + REPLACE(@ArchivoDiff, '''', '''''') + N''''
             + N' WITH NORECOVERY, CHECKSUM, STATS = 10;';
    EXEC (@SQL);
END
ELSE
    PRINT N'No hay diferencial basado en este FULL: se continua con los LOG.';

-------------------------------------------------
-- 8. Restaurar los LOG posteriores, en orden (NORECOVERY).
--    Se toman los LOG cuyo ultimo LSN es mayor al ultimo LSN
--    ya restaurado (FULL o diferencial).
-------------------------------------------------
DECLARE CursorLogs CURSOR LOCAL FAST_FORWARD
FOR
    SELECT mf.physical_device_name
    FROM msdb.dbo.backupset AS bs
    INNER JOIN msdb.dbo.backupmediafamily AS mf
        ON bs.media_set_id = mf.media_set_id
    WHERE bs.database_name = @BaseOrigen
      AND bs.type = 'L'
      AND bs.last_lsn > @LsnBase
    ORDER BY bs.first_lsn, bs.backup_set_id;

OPEN CursorLogs;
FETCH NEXT FROM CursorLogs INTO @ArchivoLog;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @TotalLogs += 1;
    PRINT CONCAT(N'Restaurando LOG ', @TotalLogs, N': ', @ArchivoLog);

    SET @SQL = N'RESTORE LOG ' + QUOTENAME(@BaseDestino)
             + N' FROM DISK = N''' + REPLACE(@ArchivoLog, '''', '''''') + N''''
             + N' WITH NORECOVERY, CHECKSUM;';
    EXEC (@SQL);

    FETCH NEXT FROM CursorLogs INTO @ArchivoLog;
END;

CLOSE CursorLogs;
DEALLOCATE CursorLogs;

PRINT CONCAT(N'LOG restaurados: ', @TotalLogs);

-------------------------------------------------
-- 9. Finalizar restauracion.
-------------------------------------------------
SET @SQL = N'RESTORE DATABASE ' + QUOTENAME(@BaseDestino) + N' WITH RECOVERY;';
EXEC (@SQL);

PRINT N'Restauracion finalizada.';
GO

-- Comprobar estado de la base restaurada.
SELECT
    name,
    state_desc,
    recovery_model_desc
FROM sys.databases
WHERE name = N'GimnasioDB_RestauracionPrueba';
GO

-- Comprobar integridad de la base restaurada.
DBCC CHECKDB (N'GimnasioDB_RestauracionPrueba')
WITH NO_INFOMSGS;
GO

-- Comprobar los datos restaurados.
USE GimnasioDB_RestauracionPrueba;
GO

WITH Conteo AS
(
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
    FROM dbo.Asistencias
)
SELECT Tabla, Registros FROM Conteo
UNION ALL
SELECT 'TOTAL (esperado 9623)', SUM(Registros) FROM Conteo;
GO
