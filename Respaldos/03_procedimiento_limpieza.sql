USE GimnasioDB;
GO

-- Limpieza segura de respaldos.
--   @Ejecutar = 0 : simulacion. Hace TODAS las validaciones, pero no elimina archivos.
--   @Ejecutar = 1 : elimina los archivos antiguos, solo si las validaciones se cumplen.
-- Retencion: FULL 30 dias, DIFF 7 dias, LOG 22 dias.
-- Politica de recuperacion: poder recuperar a cualquier punto de los ultimos 14 dias.
CREATE OR ALTER PROCEDURE dbo.usp_LimpiarRespaldos
    @Ejecutar BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BaseDatos SYSNAME = N'GimnasioDB';

    DECLARE @RutaFull NVARCHAR(4000) = N'/backup/GimnasioDB/FULL';
    DECLARE @RutaDiff NVARCHAR(4000) = N'/backup/GimnasioDB/DIFF';
    DECLARE @RutaLog  NVARCHAR(4000) = N'/backup/GimnasioDB/LOG';

    DECLARE @Ahora DATETIME = GETDATE();

    DECLARE @CorteFull DATETIME = DATEADD(DAY, -30, @Ahora);
    DECLARE @CorteDiff DATETIME = DATEADD(DAY, -7,  @Ahora);
    DECLARE @CorteLog  DATETIME = DATEADD(DAY, -22, @Ahora);

    DECLARE @IdFullAncla INT;
    DECLARE @FechaFullAncla DATETIME;
    DECLARE @UltimoFull DATETIME;
    DECLARE @PrimerLog DATETIME;
    DECLARE @UltimoLog DATETIME;

    DECLARE @Archivo NVARCHAR(4000);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ArchivosVerificados INT = 0;

    SELECT
        @CorteFull AS LimiteFULL,
        @CorteDiff AS LimiteDIFF,
        @CorteLog  AS LimiteLOG,
        @Ejecutar  AS EjecutarEliminacion;

    -- 1. Buscar el FULL que sirve de base
    -- para recuperar los ultimos 14 dias.

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
        PRINT N'Limpieza omitida: aun no existe un FULL anterior al periodo de 14 dias.';
        RETURN;
    END;

    -- 2. Comprobar que el FULL ancla no sea
    -- demasiado antiguo.

    IF @FechaFullAncla < DATEADD(DAY, -22, @Ahora)
    BEGIN
        THROW 54001,
            'Limpieza cancelada: el FULL necesario para la recuperacion es demasiado antiguo.',
            1;
    END;

    -- 3. Comprobar que exista un FULL reciente.

    SELECT
        @UltimoFull = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = @BaseDatos
      AND type = 'D'
      AND is_copy_only = 0;

    IF @UltimoFull IS NULL
       OR @UltimoFull < DATEADD(DAY, -8, @Ahora)
    BEGIN
        THROW 54002,
            'Limpieza cancelada: no existe un respaldo FULL reciente.',
            1;
    END;

    -- 4. Comprobar los respaldos LOG.

    SELECT
        @PrimerLog = MIN(backup_start_date),
        @UltimoLog = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = @BaseDatos
      AND type = 'L'
      AND backup_finish_date > @FechaFullAncla;

    IF @PrimerLog IS NULL OR @UltimoLog IS NULL
    BEGIN
        THROW 54003,
            'Limpieza cancelada: no se encontro una cadena LOG posterior al FULL ancla.',
            1;
    END;

    IF @PrimerLog > DATEADD(HOUR, 2, @FechaFullAncla)
    BEGIN
        THROW 54004,
            'Limpieza cancelada: no se encontro oportunamente el primer respaldo LOG.',
            1;
    END;

    IF @UltimoLog < DATEADD(HOUR, -2, @Ahora)
    BEGIN
        THROW 54005,
            'Limpieza cancelada: el ultimo respaldo LOG es demasiado antiguo.',
            1;
    END;

    -- 5. Revisar continuidad de los LSN y horarios.

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
        THROW 54006,
            'Limpieza cancelada: se detecto una posible interrupcion en la cadena LOG.',
            1;
    END;

    -- 6. Verificar fisicamente el FULL ancla y todos los LOG posteriores a ese FULL.

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
        THROW 54007,
            'Limpieza cancelada: no se verificaron archivos de respaldo.',
            1;
    END;

    -- Modo simulacion: las validaciones ya se superaron, pero no se elimina ningun archivo.

    IF @Ejecutar = 0
    BEGIN
        PRINT N'MODO DE SIMULACION: validaciones superadas, no se elimino ningun archivo.';
        PRINT N'FULL: se eliminarian archivos anteriores a 30 dias.';
        PRINT N'DIFF: se eliminarian archivos anteriores a 7 dias.';
        PRINT N'LOG: se eliminarian archivos anteriores a 22 dias.';
        RETURN;
    END;

    -- 7. Eliminar diferenciales de mas de 7 dias.

    EXEC master.dbo.xp_delete_file
        0, @RutaDiff, N'bak', @CorteDiff, 0;

    -- 8. Eliminar FULL de mas de 30 dias.

    EXEC master.dbo.xp_delete_file
        0, @RutaFull, N'bak', @CorteFull, 0;

    -- 9. Eliminar LOG de mas de 22 dias.
    -- Se realiza al final porque son necesarios
    -- para la recuperacion a un punto en el tiempo.

    EXEC master.dbo.xp_delete_file
        0, @RutaLog, N'trn', @CorteLog, 0;

    PRINT N'Limpieza terminada correctamente.';
    PRINT N'FULL: conservacion de 30 dias.';
    PRINT N'DIFFERENTIAL: conservacion de 7 dias.';
    PRINT N'LOG: conservacion de 22 dias.';
END;
GO


-- Prueba en modo simulacion
EXEC dbo.usp_LimpiarRespaldos @Ejecutar = 0;
GO
