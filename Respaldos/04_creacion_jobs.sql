USE GimnasioDB;
GO

--1. CREAR BITACORA DE RESPALDOS


IF OBJECT_ID(N'dbo.BitacoraRespaldos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.BitacoraRespaldos
    (
        BitacoraID INT IDENTITY(1,1) PRIMARY KEY,
        TipoRespaldo VARCHAR(10) NOT NULL,
        Estado VARCHAR(20) NOT NULL,
        FechaDeteccion DATETIME2 NOT NULL
            CONSTRAINT DF_BitacoraRespaldos_Fecha
            DEFAULT SYSDATETIME(),
        FechaResolucion DATETIME2 NULL,
        Descripcion NVARCHAR(1000) NOT NULL
    );
END;
GO


--2. PROCEDIMIENTO DE VERIFICACION

CREATE OR ALTER PROCEDURE dbo.usp_VerificarRespaldos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Ahora DATETIME = GETDATE();

    DECLARE @UltimoFull DATETIME;
    DECLARE @UltimoDiff DATETIME;
    DECLARE @UltimoLog DATETIME;

    -- Obtener el ultimo FULL 
    SELECT @UltimoFull = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = N'GimnasioDB'
      AND type = 'D';

    -- Obtener el ultimo diferencial posterior al FULL 
    SELECT @UltimoDiff = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = N'GimnasioDB'
      AND type = 'I'
      AND backup_finish_date >= @UltimoFull
      AND @UltimoFull IS NOT NULL;

    -- Obtener el ultimo LOG 
    SELECT @UltimoLog = MAX(backup_finish_date)
    FROM msdb.dbo.backupset
    WHERE database_name = N'GimnasioDB'
      AND type = 'L';


    --VERIFICAR FULL: MAXIMO 7 DIAS


    IF @UltimoFull IS NULL
       OR @UltimoFull < DATEADD(DAY, -7, @Ahora)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.BitacoraRespaldos
            WHERE TipoRespaldo = 'FULL'
              AND Estado = 'PENDIENTE'
        )
        BEGIN
            INSERT INTO dbo.BitacoraRespaldos
            (
                TipoRespaldo,
                Estado,
                Descripcion
            )
            VALUES
            (
                'FULL',
                'PENDIENTE',
                CASE
                    WHEN @UltimoFull IS NULL
                        THEN N'No existe ningun respaldo FULL registrado.'
                    ELSE N'El ultimo FULL supera los 7 dias de antiguedad. Fecha: '
                         + CONVERT(NVARCHAR(30), @UltimoFull, 120)
                END
            );
        END;
    END
    ELSE
    BEGIN
        UPDATE dbo.BitacoraRespaldos
        SET
            Estado = 'RESUELTO',
            FechaResolucion = SYSDATETIME(),
            Descripcion = Descripcion
                + N' | Resuelto. Nuevo FULL detectado: '
                + CONVERT(NVARCHAR(30), @UltimoFull, 120)
        WHERE TipoRespaldo = 'FULL'
          AND Estado = 'PENDIENTE';
    END;


    -- VERIFICAR DIFERENCIAL: MAXIMO 24 HORAS


    IF @UltimoDiff IS NULL
       OR @UltimoDiff < DATEADD(HOUR, -24, @Ahora)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.BitacoraRespaldos
            WHERE TipoRespaldo = 'DIFF'
              AND Estado = 'PENDIENTE'
        )
        BEGIN
            INSERT INTO dbo.BitacoraRespaldos
            (
                TipoRespaldo,
                Estado,
                Descripcion
            )
            VALUES
            (
                'DIFF',
                'PENDIENTE',
                CASE
                    WHEN @UltimoDiff IS NULL
                        THEN N'No existe un respaldo diferencial posterior al ultimo FULL.'
                    ELSE N'El ultimo diferencial supera las 24 horas. Fecha: '
                         + CONVERT(NVARCHAR(30), @UltimoDiff, 120)
                END
            );
        END;
    END
    ELSE
    BEGIN
        UPDATE dbo.BitacoraRespaldos
        SET
            Estado = 'RESUELTO',
            FechaResolucion = SYSDATETIME(),
            Descripcion = Descripcion
                + N' | Resuelto. Nuevo diferencial detectado: '
                + CONVERT(NVARCHAR(30), @UltimoDiff, 120)
        WHERE TipoRespaldo = 'DIFF'
          AND Estado = 'PENDIENTE';
    END;


    -- VERIFICAR LOG: MAXIMO 75 MINUTOS


    IF @UltimoLog IS NULL
       OR @UltimoLog < DATEADD(MINUTE, -75, @Ahora)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.BitacoraRespaldos
            WHERE TipoRespaldo = 'LOG'
              AND Estado = 'PENDIENTE'
        )
        BEGIN
            INSERT INTO dbo.BitacoraRespaldos
            (
                TipoRespaldo,
                Estado,
                Descripcion
            )
            VALUES
            (
                'LOG',
                'PENDIENTE',
                CASE
                    WHEN @UltimoLog IS NULL
                        THEN N'No existe ningun respaldo LOG registrado.'
                    ELSE N'El ultimo respaldo LOG supera los 75 minutos. Fecha: '
                         + CONVERT(NVARCHAR(30), @UltimoLog, 120)
                END
            );
        END;
    END
    ELSE
    BEGIN
        UPDATE dbo.BitacoraRespaldos
        SET
            Estado = 'RESUELTO',
            FechaResolucion = SYSDATETIME(),
            Descripcion = Descripcion
                + N' | Resuelto. Nuevo LOG detectado: '
                + CONVERT(NVARCHAR(30), @UltimoLog, 120)
        WHERE TipoRespaldo = 'LOG'
          AND Estado = 'PENDIENTE';
    END;

    PRINT N'Verificacion de respaldos finalizada.';

END;
GO


--CREAR JOBS


USE msdb;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.databases
    WHERE name = N'GimnasioDB'
)
    THROW 52001, 'No existe GimnasioDB.', 1;
GO


/*
OPCIONAL: eliminar los jobs de la version anterior (nombres 'Gimnasio - ...')
para que los respaldos no se hagan por duplicado. Quitar los comentarios para usarlo.

IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Gimnasio - Respaldo FULL')
    EXEC dbo.sp_delete_job @job_name = N'Gimnasio - Respaldo FULL', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Gimnasio - Respaldo DIFFERENTIAL')
    EXEC dbo.sp_delete_job @job_name = N'Gimnasio - Respaldo DIFFERENTIAL', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Gimnasio - Respaldo LOG')
    EXEC dbo.sp_delete_job @job_name = N'Gimnasio - Respaldo LOG', @delete_unused_schedule = 1;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'Gimnasio - Limpieza de respaldos')
    EXEC dbo.sp_delete_job @job_name = N'Gimnasio - Limpieza de respaldos', @delete_unused_schedule = 1;
GO
*/

--JOB 1: FULL SEMANAL


IF EXISTS
(
    SELECT 1 FROM dbo.sysjobs
    WHERE name = N'GimnasioDB - FULL semanal'
)
    EXEC dbo.sp_delete_job
        @job_name = N'GimnasioDB - FULL semanal',
        @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'GimnasioDB - FULL semanal',
    @enabled = 1,
    @description = N'Respaldo FULL semanal de GimnasioDB.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'GimnasioDB - FULL semanal',
    @step_name = N'Crear respaldo FULL',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @Archivo NVARCHAR(4000);
DECLARE @Fecha CHAR(8);
DECLARE @Hora CHAR(6);

SET @Fecha = CONVERT(CHAR(8), GETDATE(), 112);
SET @Hora = REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

SET @Archivo =
    N''/backup/GimnasioDB/FULL/GimnasioDB_FULL_''
    + @Fecha + N''_'' + @Hora + N''.bak'';

BACKUP DATABASE GimnasioDB
TO DISK = @Archivo
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'GimnasioDB - Domingo 0100',
    @enabled = 1,
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'GimnasioDB - FULL semanal',
    @schedule_name = N'GimnasioDB - Domingo 0100';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'GimnasioDB - FULL semanal';
GO


--JOB 2: DIFERENCIAL DIARIO


IF EXISTS
(
    SELECT 1 FROM dbo.sysjobs
    WHERE name = N'GimnasioDB - DIFF diario'
)
    EXEC dbo.sp_delete_job
        @job_name = N'GimnasioDB - DIFF diario',
        @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'GimnasioDB - DIFF diario',
    @enabled = 1,
    @description = N'Respaldo diferencial diario de GimnasioDB.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'GimnasioDB - DIFF diario',
    @step_name = N'Crear respaldo DIFF',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @Archivo NVARCHAR(4000);
DECLARE @Fecha CHAR(8);
DECLARE @Hora CHAR(6);

SET @Fecha = CONVERT(CHAR(8), GETDATE(), 112);
SET @Hora = REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

IF
(
    SELECT recovery_model_desc
    FROM sys.databases
    WHERE name = N''GimnasioDB''
) <> N''FULL''
    THROW 52002, ''GimnasioDB no esta en modelo FULL.'', 1;

SET @Archivo =
    N''/backup/GimnasioDB/DIFF/GimnasioDB_DIFF_''
    + @Fecha + N''_'' + @Hora + N''.bak'';

BACKUP DATABASE GimnasioDB
TO DISK = @Archivo
WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'GimnasioDB - Diario 0200',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'GimnasioDB - DIFF diario',
    @schedule_name = N'GimnasioDB - Diario 0200';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'GimnasioDB - DIFF diario';
GO


--JOB 3: LOG CADA HORA


IF EXISTS
(
    SELECT 1 FROM dbo.sysjobs
    WHERE name = N'GimnasioDB - LOG cada hora'
)
    EXEC dbo.sp_delete_job
        @job_name = N'GimnasioDB - LOG cada hora',
        @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'GimnasioDB - LOG cada hora',
    @enabled = 1,
    @description = N'Respaldo del log de transacciones cada hora.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'GimnasioDB - LOG cada hora',
    @step_name = N'Crear respaldo LOG',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
DECLARE @Archivo NVARCHAR(4000);
DECLARE @Fecha CHAR(8);
DECLARE @Hora CHAR(6);

SET @Fecha = CONVERT(CHAR(8), GETDATE(), 112);
SET @Hora = REPLACE(CONVERT(CHAR(8), GETDATE(), 108), '':'', '''');

IF
(
    SELECT recovery_model_desc
    FROM sys.databases
    WHERE name = N''GimnasioDB''
) <> N''FULL''
    THROW 52003, ''GimnasioDB no esta en modelo FULL.'', 1;

SET @Archivo =
    N''/backup/GimnasioDB/LOG/GimnasioDB_LOG_''
    + @Fecha + N''_'' + @Hora + N''.trn'';

BACKUP LOG GimnasioDB
TO DISK = @Archivo
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;
RESTORE VERIFYONLY
FROM DISK = @Archivo
WITH CHECKSUM;
',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'GimnasioDB - Cada hora minuto 15',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 8,
    @freq_subday_interval = 1,
    @active_start_time = 001500;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'GimnasioDB - LOG cada hora',
    @schedule_name = N'GimnasioDB - Cada hora minuto 15';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'GimnasioDB - LOG cada hora';
GO


--JOB 4: LIMPIEZA SEGURA (elimina solo si la cadena de recuperacion es valida)


IF EXISTS
(
    SELECT 1 FROM dbo.sysjobs
    WHERE name = N'GimnasioDB - Limpieza respaldos'
)
    EXEC dbo.sp_delete_job
        @job_name = N'GimnasioDB - Limpieza respaldos',
        @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'GimnasioDB - Limpieza respaldos',
    @enabled = 1,
    @description = N'Elimina respaldos antiguos despues de verificar la cadena de recuperacion.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'GimnasioDB - Limpieza respaldos',
    @step_name = N'Verificar y limpiar archivos antiguos',
    @subsystem = N'TSQL',
    @database_name = N'GimnasioDB',
    @command = N'EXEC dbo.usp_LimpiarRespaldos @Ejecutar = 1;',  -- cambiar a 0 para solo simular
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'GimnasioDB - Limpieza domingo 0300',
    @enabled = 1,
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 030000;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'GimnasioDB - Limpieza respaldos',
    @schedule_name = N'GimnasioDB - Limpieza domingo 0300';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'GimnasioDB - Limpieza respaldos';
GO


--JOB 5: VERIFICACION CADA 15 MINUTOS


IF EXISTS
(
    SELECT 1 FROM dbo.sysjobs
    WHERE name = N'GimnasioDB - Verificar respaldos'
)
    EXEC dbo.sp_delete_job
        @job_name = N'GimnasioDB - Verificar respaldos',
        @delete_unused_schedule = 1;
GO

EXEC dbo.sp_add_job
    @job_name = N'GimnasioDB - Verificar respaldos',
    @enabled = 1,
    @description = N'Detecta respaldos atrasados y registra incidencias.';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'GimnasioDB - Verificar respaldos',
    @step_name = N'Comprobar antiguedad de respaldos',
    @subsystem = N'TSQL',
    @database_name = N'GimnasioDB',
    @command = N'EXEC dbo.usp_VerificarRespaldos;',
    @retry_attempts = 2,
    @retry_interval = 5,
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'GimnasioDB - Verificacion cada 15 minutos',
    @enabled = 1,
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 15,
    @active_start_time = 000000,
    @active_end_time = 235959;
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'GimnasioDB - Verificar respaldos',
    @schedule_name = N'GimnasioDB - Verificacion cada 15 minutos';
GO

EXEC dbo.sp_add_jobserver
    @job_name = N'GimnasioDB - Verificar respaldos';
GO

PRINT N'Jobs, programaciones y verificacion creados correctamente.';
GO
