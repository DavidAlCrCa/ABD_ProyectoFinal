USE GimnasioDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY

    BEGIN TRANSACTION;

    -- 1. VERIFICAR QUE LAS TABLAS ESTEN VACIAS
    IF EXISTS (SELECT 1 FROM dbo.Socios)
       OR EXISTS (SELECT 1 FROM dbo.Entrenadores)
       OR EXISTS (SELECT 1 FROM dbo.TiposMembresia)
       OR EXISTS (SELECT 1 FROM dbo.Membresias)
       OR EXISTS (SELECT 1 FROM dbo.Clases)
       OR EXISTS (SELECT 1 FROM dbo.Reservaciones)
       OR EXISTS (SELECT 1 FROM dbo.Pagos)
       OR EXISTS (SELECT 1 FROM dbo.Asistencias)
    BEGIN
        THROW 50001,
        'IMPORTACION CANCELADA: Una o mas tablas ya contienen registros.',
        1;
    END;

    -- 2. IMPORTAR SOCIOS

    BULK INSERT dbo.Socios
    FROM '/csv/Socios.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Socios importados correctamente.';

    -- 3. IMPORTAR ENTRENADORES

    BULK INSERT dbo.Entrenadores
    FROM '/csv/Entrenadores.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Entrenadores importados correctamente.';

    -- 4. IMPORTAR TIPOS DE MEMBRESIA

    BULK INSERT dbo.TiposMembresia
    FROM '/csv/TiposMembresia.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Tipos de membresia importados correctamente.';

    -- 5. IMPORTAR MEMBRESIAS

    BULK INSERT dbo.Membresias
    FROM '/csv/Membresias.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Membresias importadas correctamente.';

    -- 6. IMPORTAR CLASES
    BULK INSERT dbo.Clases
    FROM '/csv/Clases.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Clases importadas correctamente.';

    -- 7. IMPORTAR RESERVACIONES
    BULK INSERT dbo.Reservaciones
    FROM '/csv/Reservaciones.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Reservaciones importadas correctamente.';

    -- 8. IMPORTAR PAGOS
    BULK INSERT dbo.Pagos
    FROM '/csv/Pagos.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        KEEPIDENTITY,
        CHECK_CONSTRAINTS,
        TABLOCK
    );

    PRINT 'Pagos importados correctamente.';

    -- 9. CREAR TABLA AUXILIAR PARA ASISTENCIAS

    IF OBJECT_ID('dbo.Asistencias_Staging', 'U') IS NOT NULL
        DROP TABLE dbo.Asistencias_Staging;

    CREATE TABLE dbo.Asistencias_Staging (
        AsistenciaID INT,
        ReservacionID INT,
        FechaRegistro DATETIME2,
        EstadoAsistencia VARCHAR(15)
    );

    PRINT 'Tabla auxiliar creada correctamente.';

    -- 10. CARGAR CSV DE ASISTENCIAS EN TABLA AUXILIAR
    BULK INSERT dbo.Asistencias_Staging
    FROM '/csv/Asistencias.csv'
    WITH (
        FIRSTROW = 2,
        FIELDTERMINATOR = ';',
        ROWTERMINATOR = '0x0a',
        TABLOCK
    );

    PRINT 'CSV de asistencias cargado en tabla auxiliar.';


    -- 11. VALIDAR CANTIDAD DE ASISTENCIAS

    IF (SELECT COUNT(*) FROM dbo.Asistencias_Staging) <> 3000
    BEGIN
        THROW 50002,
        'ERROR: La cantidad de asistencias no coincide con los 3000 registros esperados.',
        1;
    END;

    -- 12. VALIDAR CLAVES FORANEAS

    IF EXISTS (
        SELECT 1
        FROM dbo.Asistencias_Staging A
        LEFT JOIN dbo.Reservaciones R
            ON A.ReservacionID = R.ReservacionID
        WHERE R.ReservacionID IS NULL
    )
    BEGIN
        THROW 50003,
        'ERROR: Existen asistencias relacionadas con reservaciones inexistentes.',
        1;
    END;

    PRINT 'Validacion de claves foraneas completada.';


    -- 13. VALIDAR IDENTIFICADORES DUPLICADOS

    IF EXISTS (
        SELECT ReservacionID
        FROM dbo.Asistencias_Staging
        GROUP BY ReservacionID
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50004,
        'ERROR: Existen ReservacionID duplicados en el archivo de asistencias.',
        1;
    END;

    PRINT 'Validacion de identificadores duplicados completada.';

    -- 14. INSERTAR ASISTENCIAS DEFINITIVAMENTE

    SET IDENTITY_INSERT dbo.Asistencias ON;

    INSERT INTO dbo.Asistencias (
        AsistenciaID,
        ReservacionID,
        FechaRegistro,
        EstadoAsistencia
    )
    SELECT
        AsistenciaID,
        ReservacionID,
        FechaRegistro,
        EstadoAsistencia
    FROM dbo.Asistencias_Staging;

    SET IDENTITY_INSERT dbo.Asistencias OFF;

    PRINT 'Asistencias importadas correctamente.';

    -- 15. ELIMINAR TABLA AUXILIAR
    DROP TABLE dbo.Asistencias_Staging;

    PRINT 'Tabla auxiliar eliminada correctamente.';

    -- 16. VERIFICAR CANTIDADES DE REGISTROS
    IF (SELECT COUNT(*) FROM dbo.Socios) <> 1000
       OR (SELECT COUNT(*) FROM dbo.Entrenadores) <> 20
       OR (SELECT COUNT(*) FROM dbo.TiposMembresia) <> 3
       OR (SELECT COUNT(*) FROM dbo.Membresias) <> 5
       OR (SELECT COUNT(*) FROM dbo.Clases) <> 100
       OR (SELECT COUNT(*) FROM dbo.Reservaciones) <> 3000
       OR (SELECT COUNT(*) FROM dbo.Pagos) <> 1500
       OR (SELECT COUNT(*) FROM dbo.Asistencias) <> 3000
    BEGIN
        THROW 50005,
        'ERROR: Una o mas tablas no contienen la cantidad esperada de registros.',
        1;
    END;


    -- 17. CONFIRMAR TRANSACCION
    COMMIT TRANSACTION;

    PRINT '=========================================';
    PRINT 'IMPORTACION COMPLETADA CORRECTAMENTE';
    PRINT 'TOTAL: 8628 REGISTROS';
    PRINT '=========================================';


END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    -- Asegurar que IDENTITY_INSERT quede desactivado.
    BEGIN TRY
        SET IDENTITY_INSERT dbo.Asistencias OFF;
    END TRY
    BEGIN CATCH
        -- Se ignora si ya estaba desactivado.
    END CATCH;

    PRINT '=========================================';
    PRINT 'ERROR DURANTE LA IMPORTACION';
    PRINT ERROR_MESSAGE();
    PRINT 'LA TRANSACCION FUE REVERTIDA';
    PRINT '=========================================';

    THROW;

END CATCH;

GO

-- 18. REPORTE FINAL DE REGISTROS IMPORTADOS
SELECT 'Socios' AS Tabla, COUNT(*) AS Registros
FROM dbo.Socios

UNION ALL

SELECT 'Entrenadores', COUNT(*)
FROM dbo.Entrenadores

UNION ALL

SELECT 'TiposMembresia', COUNT(*)
FROM dbo.TiposMembresia

UNION ALL

SELECT 'Membresias', COUNT(*)
FROM dbo.Membresias

UNION ALL

SELECT 'Clases', COUNT(*)
FROM dbo.Clases

UNION ALL

SELECT 'Reservaciones', COUNT(*)
FROM dbo.Reservaciones

UNION ALL

SELECT 'Pagos', COUNT(*)
FROM dbo.Pagos

UNION ALL

SELECT 'Asistencias', COUNT(*)
FROM dbo.Asistencias;

GO
