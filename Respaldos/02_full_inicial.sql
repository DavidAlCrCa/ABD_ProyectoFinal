USE master;
GO

IF DB_ID(N'GimnasioDB') IS NULL
    THROW 51001, 'No existe la base de datos GimnasioDB.', 1;
GO

-- FULL recovery es necesario para respaldos de log.
ALTER DATABASE GimnasioDB SET RECOVERY FULL;
GO

DECLARE @Archivo NVARCHAR(4000);
DECLARE @Fecha CHAR(8);
DECLARE @Hora CHAR(6);

SET @Fecha = CONVERT(CHAR(8), GETDATE(), 112);
SET @Hora = REPLACE(CONVERT(CHAR(8), GETDATE(), 108), ':', '');

SET @Archivo =
    N'/backup/GimnasioDB/FULL/GimnasioDB_FULL_' +
    @Fecha + N'_' + @Hora + N'.bak';

BACKUP DATABASE GimnasioDB
TO DISK = @Archivo
WITH
    INIT,
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

PRINT N'Respaldo FULL creado: ' + @Archivo;
GO

/*
Verificación adicional del último FULL:
*/

DECLARE @UltimoFull NVARCHAR(4000);

SELECT TOP (1)
    @UltimoFull = mf.physical_device_name
FROM msdb.dbo.backupset AS bs
INNER JOIN msdb.dbo.backupmediafamily AS mf
    ON bs.media_set_id = mf.media_set_id
WHERE bs.database_name = N'GimnasioDB'
  AND bs.type = 'D'
ORDER BY bs.backup_finish_date DESC;

IF @UltimoFull IS NULL
    THROW 51002, 'No se encontró el respaldo FULL en el historial de msdb.', 1;

RESTORE VERIFYONLY
FROM DISK = @UltimoFull
WITH CHECKSUM;

PRINT N'El último respaldo FULL superó RESTORE VERIFYONLY.';
GO
