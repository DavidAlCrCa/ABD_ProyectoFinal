
USE master;
GO
 
-- 08 - RECUPERACION DE GimnasioDB (la base real)
--
-- Usar cuando GimnasioDB fue eliminada o quedo inutilizable.
-- Restaura: FULL mas reciente -> DIFFERENTIAL basado en ese FULL -> LOG posteriores -> RECOVERY.
-- Los archivos quedan en sus rutas originales (/var/opt/mssql/data/GimnasioDB.mdf y _log.ldf).
--
-- Dos modos, se elige solo:
--   HISTORIAL : msdb conoce los respaldos. Rutas y orden salen del historial (lo normal).
--   CARPETA   : el historial fue borrado (por ejemplo, al eliminar la base desde SSMS con la casilla
--               "Eliminar historial de copias de seguridad" marcada). Se leen los archivos de
--               /backup/GimnasioDB/FULL, DIFF y LOG y se ordenan por la fecha-hora de su nombre
--               (GimnasioDB_FULL_AAAAMMDD_HHMMSS.bak).
--
-- Si la base YA existe, el script se detiene. Para eliminarla y restaurarla,
-- cambiar @Reemplazar a N'SI'.
--
-- Al terminar toma un FULL nuevo (@NuevoFull = 1) para dejar una base limpia
-- para los diferenciales y logs siguientes. Los jobs siguen funcionando solos.
 
SET NOCOUNT ON;
 
DECLARE @BaseDatos   SYSNAME       = N'GimnasioDB';
DECLARE @RutaBase    NVARCHAR(400) = N'/backup/GimnasioDB';
DECLARE @Reemplazar  NVARCHAR(2)   = N'NO';   -- N'SI' para eliminar la base existente y restaurar
DECLARE @NuevoFull   BIT           = 1;       -- 1 = tomar un FULL al terminar
 
DECLARE @SQL        NVARCHAR(MAX);
DECLARE @Archivo    NVARCHAR(4000);
DECLARE @Tipo       CHAR(4);
DECLARE @Msg        NVARCHAR(2000);
DECLARE @Modo       NVARCHAR(20);
DECLARE @IdFull     INT;
DECLARE @GuidFull   UNIQUEIDENTIFIER;
DECLARE @LsnBase    NUMERIC(25,0);
DECLARE @TsFull     CHAR(15);
DECLARE @TsBase     CHAR(15);
DECLARE @Marca      CHAR(15);
DECLARE @Total      INT = 0;
 
CREATE TABLE #Cadena
(
    Orden   INT IDENTITY(1,1) PRIMARY KEY,
    Tipo    CHAR(4)        NOT NULL,
    Archivo NVARCHAR(4000) NOT NULL
);
 
-------------------------------------------------
-- 1. Si la base ya existe, solo continuar con confirmacion.
-------------------------------------------------
IF DB_ID(@BaseDatos) IS NOT NULL
BEGIN
    IF @Reemplazar <> N'SI'
        THROW 55001, 'La base GimnasioDB ya existe. Para eliminarla y restaurarla ponga @Reemplazar = SI.', 1;
 
    PRINT N'Eliminando la base existente...';
 
    IF EXISTS (SELECT 1 FROM sys.databases
               WHERE name = @BaseDatos AND state_desc = N'ONLINE')
    BEGIN
        SET @SQL = N'ALTER DATABASE ' + QUOTENAME(@BaseDatos)
                 + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
        EXEC (@SQL);
    END;
 
    SET @SQL = N'DROP DATABASE ' + QUOTENAME(@BaseDatos) + N';';
    EXEC (@SQL);
END;
 
-------------------------------------------------
-- 2. Elegir modo: historial de msdb o carpeta.
-------------------------------------------------
IF EXISTS (SELECT 1
           FROM msdb.dbo.backupset
           WHERE database_name = @BaseDatos
             AND type = 'D'
             AND is_copy_only = 0)
    SET @Modo = N'HISTORIAL';
ELSE
    SET @Modo = N'CARPETA';
 
PRINT N'Modo de recuperacion: ' + @Modo;
 
-------------------------------------------------
-- 3A. Modo HISTORIAL: armar la cadena desde msdb.
-------------------------------------------------
IF @Modo = N'HISTORIAL'
BEGIN
    SELECT TOP (1)
        @IdFull   = bs.backup_set_id,
        @GuidFull = bs.backup_set_uuid,
        @LsnBase  = bs.last_lsn,
        @Archivo  = mf.physical_device_name
    FROM msdb.dbo.backupset AS bs
    INNER JOIN msdb.dbo.backupmediafamily AS mf
        ON bs.media_set_id = mf.media_set_id
    WHERE bs.database_name = @BaseDatos
      AND bs.type = 'D'
      AND bs.is_copy_only = 0
    ORDER BY bs.backup_finish_date DESC;
 
    INSERT INTO #Cadena (Tipo, Archivo) VALUES ('FULL', @Archivo);
 
    SET @Archivo = NULL;
 
    SELECT TOP (1)
        @Archivo = mf.physical_device_name,
        @LsnBase = bs.last_lsn
    FROM msdb.dbo.backupset AS bs
    INNER JOIN msdb.dbo.backupmediafamily AS mf
        ON bs.media_set_id = mf.media_set_id
    WHERE bs.database_name = @BaseDatos
      AND bs.type = 'I'
      AND bs.differential_base_guid = @GuidFull
    ORDER BY bs.backup_finish_date DESC;
 
    IF @Archivo IS NOT NULL
        INSERT INTO #Cadena (Tipo, Archivo) VALUES ('DIFF', @Archivo);
 
    -- LOG cuyo ultimo LSN es posterior al ultimo LSN ya restaurado (FULL o DIFF).
    INSERT INTO #Cadena (Tipo, Archivo)
    SELECT 'LOG', mf.physical_device_name
    FROM msdb.dbo.backupset AS bs
    INNER JOIN msdb.dbo.backupmediafamily AS mf
        ON bs.media_set_id = mf.media_set_id
    WHERE bs.database_name = @BaseDatos
      AND bs.type = 'L'
      AND bs.last_lsn > @LsnBase
    ORDER BY bs.first_lsn, bs.backup_set_id;
END
-------------------------------------------------
-- 3B. Modo CARPETA: armar la cadena desde los archivos.
-------------------------------------------------
ELSE
BEGIN
    CREATE TABLE #Tmp   (Nombre NVARCHAR(512), Profundidad INT, EsArchivo BIT);
    CREATE TABLE #Lista (Tipo CHAR(4), Nombre NVARCHAR(512), EsArchivo BIT);
 
    BEGIN TRY
        SET @SQL = N'INSERT INTO #Tmp EXEC master.sys.xp_dirtree N''' + @RutaBase + N'/FULL'', 1, 1;';
        EXEC (@SQL);
        INSERT INTO #Lista SELECT 'FULL', Nombre, EsArchivo FROM #Tmp;
        DELETE FROM #Tmp;
 
        SET @SQL = N'INSERT INTO #Tmp EXEC master.sys.xp_dirtree N''' + @RutaBase + N'/DIFF'', 1, 1;';
        EXEC (@SQL);
        INSERT INTO #Lista SELECT 'DIFF', Nombre, EsArchivo FROM #Tmp;
        DELETE FROM #Tmp;
 
        SET @SQL = N'INSERT INTO #Tmp EXEC master.sys.xp_dirtree N''' + @RutaBase + N'/LOG'', 1, 1;';
        EXEC (@SQL);
        INSERT INTO #Lista SELECT 'LOG', Nombre, EsArchivo FROM #Tmp;
        DELETE FROM #Tmp;
    END TRY
    BEGIN CATCH
        SET @Msg = CONCAT(N'No se pudo leer la carpeta ', @RutaBase,
                          N'. Verifique que exista y que mssql tenga permiso. Detalle: ', ERROR_MESSAGE());
        THROW 55002, @Msg, 1;
    END CATCH;
 
    -- FULL mas reciente (el nombre lleva fecha y hora, asi que ordenar por nombre es ordenar por tiempo).
    SET @Archivo = NULL;
    SELECT TOP (1) @Archivo = Nombre
    FROM #Lista
    WHERE Tipo = 'FULL' AND EsArchivo = 1
      AND Nombre LIKE N'GimnasioDB[_]FULL[_]%.bak'
    ORDER BY Nombre DESC;
 
    IF @Archivo IS NULL
    BEGIN
        SET @Msg = CONCAT(N'No se encontro ningun respaldo FULL en ', @RutaBase, N'/FULL.');
        THROW 55003, @Msg, 1;
    END;
 
    SET @TsFull = SUBSTRING(@Archivo, 17, 15);
    SET @TsBase = @TsFull;
    INSERT INTO #Cadena (Tipo, Archivo) VALUES ('FULL', @RutaBase + N'/FULL/' + @Archivo);
 
    -- DIFF mas reciente posterior a ese FULL.
    SET @Archivo = NULL;
    SELECT TOP (1) @Archivo = Nombre
    FROM #Lista
    WHERE Tipo = 'DIFF' AND EsArchivo = 1
      AND Nombre LIKE N'GimnasioDB[_]DIFF[_]%.bak'
      AND SUBSTRING(Nombre, 17, 15) > @TsFull
    ORDER BY Nombre DESC;
 
    IF @Archivo IS NOT NULL
    BEGIN
        SET @TsBase = SUBSTRING(@Archivo, 17, 15);
        INSERT INTO #Cadena (Tipo, Archivo) VALUES ('DIFF', @RutaBase + N'/DIFF/' + @Archivo);
    END;
 
    -- LOG posteriores al diferencial (o al FULL si no hay diferencial), en orden.
    INSERT INTO #Cadena (Tipo, Archivo)
    SELECT 'LOG', @RutaBase + N'/LOG/' + Nombre
    FROM #Lista
    WHERE Tipo = 'LOG' AND EsArchivo = 1
      AND Nombre LIKE N'GimnasioDB[_]LOG[_]%.trn'
      AND SUBSTRING(Nombre, 16, 15) > @TsBase
    ORDER BY Nombre;
END;
 
-------------------------------------------------
-- 4. Mostrar la cadena que se va a restaurar.
-------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM #Cadena WHERE Tipo = 'FULL')
    THROW 55004, 'No se encontro un respaldo FULL para restaurar.', 1;
 
SELECT Orden, Tipo, Archivo FROM #Cadena ORDER BY Orden;
 
-------------------------------------------------
-- 5. Restaurar la cadena en orden (NORECOVERY).
-------------------------------------------------
DECLARE CursorCadena CURSOR LOCAL FAST_FORWARD
FOR
    SELECT Tipo, Archivo
    FROM #Cadena
    ORDER BY Orden;
 
OPEN CursorCadena;
FETCH NEXT FROM CursorCadena INTO @Tipo, @Archivo;
 
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Total += 1;
    PRINT CONCAT(N'Restaurando ', RTRIM(@Tipo), N' (', @Total, N'): ', @Archivo);
 
    IF @Tipo = 'LOG'
        SET @SQL = N'RESTORE LOG ' + QUOTENAME(@BaseDatos)
                 + N' FROM DISK = N''' + REPLACE(@Archivo, '''', '''''') + N''''
                 + N' WITH NORECOVERY, CHECKSUM;';
    ELSE
        SET @SQL = N'RESTORE DATABASE ' + QUOTENAME(@BaseDatos)
                 + N' FROM DISK = N''' + REPLACE(@Archivo, '''', '''''') + N''''
                 + N' WITH NORECOVERY, CHECKSUM, STATS = 10;';
 
    EXEC (@SQL);
 
    FETCH NEXT FROM CursorCadena INTO @Tipo, @Archivo;
END;
 
CLOSE CursorCadena;
DEALLOCATE CursorCadena;
 
-------------------------------------------------
-- 6. Finalizar la restauracion.
-------------------------------------------------
SET @SQL = N'RESTORE DATABASE ' + QUOTENAME(@BaseDatos) + N' WITH RECOVERY;';
EXEC (@SQL);
 
PRINT CONCAT(N'Recuperacion terminada. Respaldos restaurados: ', @Total);
 
-------------------------------------------------
-- 7. FULL nuevo para dejar una base limpia
--    para los diferenciales y logs siguientes.
-------------------------------------------------
IF @NuevoFull = 1
BEGIN
    SET @Marca = CONVERT(CHAR(8), GETDATE(), 112) + N'_'
               + REPLACE(CONVERT(CHAR(8), GETDATE(), 108), N':', N'');
 
    SET @Archivo = @RutaBase + N'/FULL/GimnasioDB_FULL_' + @Marca + N'.bak';
 
    SET @SQL = N'BACKUP DATABASE ' + QUOTENAME(@BaseDatos)
             + N' TO DISK = N''' + REPLACE(@Archivo, '''', '''''') + N''''
             + N' WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;';
    EXEC (@SQL);
 
    SET @SQL = N'RESTORE VERIFYONLY FROM DISK = N''' + REPLACE(@Archivo, '''', '''''')
             + N''' WITH CHECKSUM;';
    EXEC (@SQL);
 
    PRINT N'FULL posterior a la recuperacion: ' + @Archivo;
END;
GO
 
-------------------------------------------------
-- 8. Comprobaciones
-------------------------------------------------
SELECT
    name,
    state_desc,
    recovery_model_desc,
    create_date
FROM sys.databases
WHERE name = N'GimnasioDB';
GO
 
DBCC CHECKDB (N'GimnasioDB')
WITH NO_INFOMSGS;
GO
 
USE GimnasioDB;
GO
 
-- Datos
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
 
-- Objetos de la base que volvieron con la restauracion
SELECT
    (SELECT COUNT(*) FROM sys.tables)     AS Tablas,
    (SELECT COUNT(*) FROM sys.views)      AS Vistas,
    (SELECT COUNT(*) FROM sys.procedures) AS Procedimientos,
    (SELECT COUNT(*) FROM sys.indexes WHERE name LIKE N'ix[_]%') AS IndicesIX,
    (SELECT COUNT(*) FROM sys.database_principals
     WHERE type = 'R' AND name LIKE N'rol[_]%') AS Roles;
GO
 