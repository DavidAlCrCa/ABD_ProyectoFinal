USE GimnasioDB;
GO
 
SET NOCOUNT ON;
SET XACT_ABORT ON;
 
-- CONFIGURACION
DECLARE @RutaBase     NVARCHAR(200) = N'/csv/';
DECLARE @ArchivosUTF8 BIT           = 1;
 
DECLARE @Imports TABLE (
    Orden    INT PRIMARY KEY,
    Tabla    SYSNAME,
    Archivo  NVARCHAR(100),
    Sep      NCHAR(1),
    Esperado INT
);
 
INSERT INTO @Imports (Orden, Tabla, Archivo, Sep, Esperado) VALUES
    (1, N'dbo.Socios',         N'Socios.csv',         N';', 1000),
    (2, N'dbo.Entrenadores',   N'Entrenadores.csv',   N';',   20),
    (3, N'dbo.TiposMembresia', N'TiposMembresia.csv', N';',    3),
    (4, N'dbo.Membresias',     N'Membresias.csv',     N',', 1000),  -- usa coma
    (5, N'dbo.Clases',         N'Clases.csv',         N';',  100),
    (6, N'dbo.Reservaciones',  N'Reservaciones.csv',  N';', 3000),
    (7, N'dbo.Pagos',          N'Pagos.csv',          N',', 1500),  -- usa coma
    (8, N'dbo.Asistencias',    N'Asistencias.csv',    N';', 3000);
 
DECLARE @i INT = 1,
        @max INT = (SELECT MAX(Orden) FROM @Imports),
        @Tabla SYSNAME,
        @Stg SYSNAME,
        @Archivo NVARCHAR(100),
        @Sep NCHAR(1),
        @Esperado INT,
        @Ruta NVARCHAR(300),
        @EsCRLF BIT,
        @RowTerm NVARCHAR(10),
        @Coll NVARCHAR(60) = CASE WHEN @ArchivosUTF8 = 1
                                  THEN N' COLLATE Latin1_General_100_CI_AS_SC_UTF8'
                                  ELSE N'' END,
        @cols NVARCHAR(MAX),
        @defs NVARCHAR(MAX),
        @sql NVARCHAR(MAX),
        @n INT,
        @msg NVARCHAR(2000);
 
BEGIN TRY
 
    BEGIN TRANSACTION;
 

    PRINT 'INICIANDO PROCESO DE IMPORTACION';

 
    --ELIMINAR DATOS ANTERIORES (hijas primero)
    PRINT 'ELIMINANDO DATOS ANTERIORES';
 
    DELETE FROM dbo.Asistencias;
    DELETE FROM dbo.Pagos;
    DELETE FROM dbo.Reservaciones;
    DELETE FROM dbo.Membresias;
    DELETE FROM dbo.Clases;
    DELETE FROM dbo.Socios;
    DELETE FROM dbo.Entrenadores;
    DELETE FROM dbo.TiposMembresia;
 
    PRINT 'Datos anteriores eliminados correctamente.';
 
    --IMPORTAR CADA CSV
    WHILE @i <= @max
    BEGIN
        SELECT @Tabla = Tabla, @Archivo = Archivo, @Sep = Sep, @Esperado = Esperado
        FROM @Imports
        WHERE Orden = @i;
 
        SET @Ruta = @RutaBase + @Archivo;
        SET @Stg  = N'dbo.Stg_' + PARSENAME(@Tabla, 1);
 
        --Detectar CRLF / LF
        SET @EsCRLF = 0;
        SET @sql = N'SELECT @crlf = CASE WHEN CHARINDEX(CHAR(13) + CHAR(10), BulkColumn) > 0
                                         THEN 1 ELSE 0 END
                     FROM OPENROWSET(BULK ''' + @Ruta + N''', SINGLE_CLOB) AS f;';
        BEGIN TRY
            EXEC sp_executesql @sql, N'@crlf BIT OUTPUT', @crlf = @EsCRLF OUTPUT;
        END TRY
        BEGIN CATCH
            SET @msg = CONCAT(N'No se pudo abrir ', @Ruta, N': ', ERROR_MESSAGE());
            THROW 50001, @msg, 1;
        END CATCH;
 
        SET @RowTerm = CASE WHEN @EsCRLF = 1 THEN N'0x0d0a' ELSE N'0x0a' END;
 
        --Armar lista de columnas y definicion de la tabla de paso
        SET @cols = NULL;
        SET @defs = NULL;
 
        SELECT
            @cols = STRING_AGG(CAST(QUOTENAME(c.name) AS NVARCHAR(MAX)), N',')
                        WITHIN GROUP (ORDER BY c.column_id),
            @defs = STRING_AGG(CAST(QUOTENAME(c.name) + N' ' +
                        CASE
                            WHEN t.name IN (N'varchar', N'nvarchar')
                                THEN N'VARCHAR(' + CAST(y.L2 AS NVARCHAR(10)) + N')' + @Coll
                            WHEN t.name IN (N'decimal', N'numeric')
                                THEN t.name + N'(' + CAST(c.precision AS NVARCHAR(5)) + N','
                                            + CAST(c.scale AS NVARCHAR(5)) + N')'
                            WHEN t.name = N'datetime2'
                                THEN N'DATETIME2(' + CAST(c.scale AS NVARCHAR(5)) + N')'
                            ELSE QUOTENAME(t.name)
                        END AS NVARCHAR(MAX)), N',')
                        WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.columns c
        JOIN sys.types t ON t.user_type_id = c.user_type_id
        CROSS APPLY (SELECT CASE WHEN c.max_length = -1 THEN 8000
                                 ELSE (CASE WHEN t.name = N'nvarchar'
                                            THEN c.max_length / 2
                                            ELSE c.max_length END) * 4
                            END AS L) x
        CROSS APPLY (SELECT CASE WHEN x.L > 8000 THEN 8000 ELSE x.L END AS L2) y
        WHERE c.object_id = OBJECT_ID(@Tabla);
 
        IF @cols IS NULL
        BEGIN
            SET @msg = CONCAT(N'No se encontro la tabla ', @Tabla, N' en la base de datos.');
            THROW 50002, @msg, 1;
        END;
 
        -- Crear tabla de paso
        SET @sql = N'IF OBJECT_ID(''' + @Stg + N''', ''U'') IS NOT NULL DROP TABLE ' + @Stg + N';
                     CREATE TABLE ' + @Stg + N' (' + @defs + N');';
        EXEC (@sql);
 
        --BULK INSERT hacia la tabla de paso
        SET @sql = N'BULK INSERT ' + @Stg + N'
                     FROM ''' + @Ruta + N'''
                     WITH (
                         FIRSTROW = 2,
                         FIELDTERMINATOR = ''' + @Sep + N''',
                         ROWTERMINATOR = ''' + @RowTerm + N''',
                         TABLOCK
                     );';
        BEGIN TRY
            EXEC (@sql);
        END TRY
        BEGIN CATCH
            SET @msg = CONCAT(N'Fallo al leer ', @Ruta, N' (separador "', @Sep,
                              N'", fin de linea ',
                              CASE WHEN @EsCRLF = 1 THEN N'CRLF' ELSE N'LF' END,
                              N'): ', ERROR_MESSAGE());
            THROW 50003, @msg, 1;
        END CATCH;
 
        --Validar cantidad leida
        SET @sql = N'SELECT @n = COUNT(*) FROM ' + @Stg + N';';
        EXEC sp_executesql @sql, N'@n INT OUTPUT', @n = @n OUTPUT;
 
        IF @n <> @Esperado
        BEGIN
            SET @msg = CONCAT(N'El archivo ', @Archivo, N' trajo ', @n,
                              N' filas y se esperaban ', @Esperado,
                              N'. Revisa lineas vacias o filas de mas/menos.');
            THROW 50004, @msg, 1;
        END;
 
        --Insertar en la tabla real (aqui se validan FK, UNIQUE y CHECK)
        SET @sql = N'SET IDENTITY_INSERT ' + @Tabla + N' ON;
                     INSERT INTO ' + @Tabla + N' (' + @cols + N')
                     SELECT ' + @cols + N' FROM ' + @Stg + N';
                     SET IDENTITY_INSERT ' + @Tabla + N' OFF;';
        BEGIN TRY
            EXEC (@sql);
        END TRY
        BEGIN CATCH
            SET @msg = CONCAT(N'Fallo al insertar en ', @Tabla, N' los datos de ', @Archivo,
                              N': ', ERROR_MESSAGE());
            THROW 50005, @msg, 1;
        END CATCH;
 
        --Eliminar tabla de paso
        SET @sql = N'DROP TABLE ' + @Stg + N';';
        EXEC (@sql);
 
        PRINT CONCAT(@Tabla, ' importada correctamente (', @n, ' registros).');
 
        SET @i += 1;
    END;
 
    --VALIDACION FINAL
    IF (SELECT COUNT(*) FROM dbo.Socios)          <> 1000
    OR (SELECT COUNT(*) FROM dbo.Entrenadores)    <> 20
    OR (SELECT COUNT(*) FROM dbo.TiposMembresia)  <> 3
    OR (SELECT COUNT(*) FROM dbo.Membresias)      <> 1000
    OR (SELECT COUNT(*) FROM dbo.Clases)          <> 100
    OR (SELECT COUNT(*) FROM dbo.Reservaciones)   <> 3000
    OR (SELECT COUNT(*) FROM dbo.Pagos)           <> 1500
    OR (SELECT COUNT(*) FROM dbo.Asistencias)     <> 3000
        THROW 50006, 'ERROR: Una o mas tablas no contienen la cantidad esperada de registros.', 1;
 
    COMMIT TRANSACTION;
 
    PRINT '=========================================';
    PRINT 'IMPORTACION COMPLETADA CORRECTAMENTE';
    PRINT 'TOTAL: 9623 REGISTROS';
    PRINT '=========================================';
 
END TRY
BEGIN CATCH
 
    DECLARE @ErrMsg  NVARCHAR(2000) = ERROR_MESSAGE();
    DECLARE @ErrNum  INT            = ERROR_NUMBER();
    DECLARE @ErrLine INT            = ERROR_LINE();
 
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
 
    PRINT '=========================================';
    PRINT 'ERROR DURANTE LA IMPORTACION';
    PRINT CONCAT('Numero: ', @ErrNum, ' | Linea: ', @ErrLine);
    PRINT @ErrMsg;
    PRINT 'LA TRANSACCION FUE REVERTIDA';
    PRINT '=========================================';
 
    THROW;
 
END CATCH;
GO
 
 
-- REPORTE FINAL DE REGISTROS
SELECT 'Socios' AS Tabla, COUNT(*) AS Registros FROM dbo.Socios
UNION ALL SELECT 'Entrenadores',   COUNT(*) FROM dbo.Entrenadores
UNION ALL SELECT 'TiposMembresia', COUNT(*) FROM dbo.TiposMembresia
UNION ALL SELECT 'Membresias',     COUNT(*) FROM dbo.Membresias
UNION ALL SELECT 'Clases',         COUNT(*) FROM dbo.Clases
UNION ALL SELECT 'Reservaciones',  COUNT(*) FROM dbo.Reservaciones
UNION ALL SELECT 'Pagos',          COUNT(*) FROM dbo.Pagos
UNION ALL SELECT 'Asistencias',    COUNT(*) FROM dbo.Asistencias;
GO
 
-- Verificacion de acentos (debe verse "Asistió", no "AsistiÃ³"):
SELECT TOP 5 Nombres, Apellidos FROM dbo.Socios WHERE Nombres LIKE N'%[áéíóúñ]%' OR Apellidos LIKE N'%[áéíóúñ]%';
SELECT EstadoAsistencia, COUNT(*) AS Total FROM dbo.Asistencias GROUP BY EstadoAsistencia;
GO
 
