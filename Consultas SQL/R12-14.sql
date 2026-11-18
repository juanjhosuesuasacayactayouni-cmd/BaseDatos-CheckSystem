USE SafeWork_CheckSystem;
GO

-- REQ12 
IF OBJECT_ID('dbo.sp_RegistrarInspeccionCompleta') IS NOT NULL
    DROP PROCEDURE dbo.sp_RegistrarInspeccionCompleta;
GO

CREATE PROCEDURE dbo.sp_RegistrarInspeccionCompleta
    @id_area             INT,
    @id_inspector        INT,
    @tipo_inspeccion     VARCHAR(20),
    @fecha_programada    DATE,
    @fecha_realizada     DATE,
    @observacion_general VARCHAR(500),
    @id_inspeccion       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF NOT EXISTS (SELECT 1 FROM #Hallazgos)
            RAISERROR('La inspeccion debe registrarse con al menos un hallazgo.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Area WHERE id_area = @id_area)
            RAISERROR('El area indicada no existe.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE id_empleado = @id_inspector)
            RAISERROR('El inspector indicado no existe.', 16, 1);

        BEGIN TRANSACTION;

            INSERT INTO dbo.Inspeccion
                (id_area, id_inspector, tipo_inspeccion, fecha_programada, fecha_realizada, observacion_general)
            VALUES
                (@id_area, @id_inspector, @tipo_inspeccion, @fecha_programada, @fecha_realizada, @observacion_general);

            SET @id_inspeccion = SCOPE_IDENTITY();

            INSERT INTO dbo.HallazgoInspeccion
                (id_inspeccion, id_peligro_riesgo, descripcion, id_nivel_riesgo_momentaneo)
            SELECT
                @id_inspeccion, id_peligro_riesgo, descripcion, id_nivel_riesgo_momentaneo
            FROM #Hallazgos;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;   

        SET @id_inspeccion = NULL;

        DECLARE @mensaje VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@mensaje, 16, 1);
    END CATCH
END
GO

-- PRUEBAS REQ12 
CREATE TABLE #Hallazgos
(
    id_peligro_riesgo          INT,
    descripcion                VARCHAR(500),
    id_nivel_riesgo_momentaneo INT
);

INSERT INTO #Hallazgos VALUES
    (1, 'Prueba REQ12: hallazgo A', 3),
    (2, 'Prueba REQ12: hallazgo B', 2);

DECLARE @id INT;
EXEC dbo.sp_RegistrarInspeccionCompleta
     @id_area             = 5,
     @id_inspector        = 40,
     @tipo_inspeccion     = 'Periodica',
     @fecha_programada    = '20261110',
     @fecha_realizada     = '20261112',
     @observacion_general = 'Prueba REQ12 - registro correcto',
     @id_inspeccion       = @id OUTPUT;

SELECT * FROM dbo.Inspeccion         WHERE id_inspeccion = @id;
SELECT * FROM dbo.HallazgoInspeccion WHERE id_inspeccion = @id;

DROP TABLE #Hallazgos;
GO

-- Prueba 2
CREATE TABLE #Hallazgos
(
    id_peligro_riesgo          INT,
    descripcion                VARCHAR(500),
    id_nivel_riesgo_momentaneo INT
);

INSERT INTO #Hallazgos VALUES
    (1,      'Prueba REQ12: hallazgo valido',            3),
    (999999, 'Prueba REQ12: linea IPERC que no existe',  2);

DECLARE @id INT;
DECLARE @inspecciones_antes INT = (SELECT COUNT(*) FROM dbo.Inspeccion);
DECLARE @hallazgos_antes    INT = (SELECT COUNT(*) FROM dbo.HallazgoInspeccion);

BEGIN TRY
    EXEC dbo.sp_RegistrarInspeccionCompleta
         @id_area             = 5,
         @id_inspector        = 40,
         @tipo_inspeccion     = 'Inopinada',
         @fecha_programada    = NULL,
         @fecha_realizada     = '20261112',
         @observacion_general = 'Prueba REQ12 - debe fallar y revertirse',
         @id_inspeccion       = @id OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_MESSAGE() AS mensaje_error;
END CATCH;

SELECT
    @inspecciones_antes                           AS inspecciones_antes,
    (SELECT COUNT(*) FROM dbo.Inspeccion)         AS inspecciones_despues,
    @hallazgos_antes                              AS hallazgos_antes,
    (SELECT COUNT(*) FROM dbo.HallazgoInspeccion) AS hallazgos_despues; 

DROP TABLE #Hallazgos;
GO



--REQ13
IF OBJECT_ID('dbo.sp_ActualizarMatrizIPERC') IS NOT NULL
    DROP PROCEDURE dbo.sp_ActualizarMatrizIPERC;
GO

CREATE PROCEDURE dbo.sp_ActualizarMatrizIPERC
    @id_puesto            INT,
    @id_elaborador        INT,
    @motivo_actualizacion VARCHAR(300),
    @id_matriz_nueva      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @id_matriz_anterior INT;
        DECLARE @version_nueva      INT;

        IF NOT EXISTS (SELECT 1 FROM dbo.PuestoTrabajo WHERE id_puesto = @id_puesto)
            RAISERROR('El puesto de trabajo indicado no existe.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE id_empleado = @id_elaborador)
            RAISERROR('El empleado elaborador indicado no existe.', 16, 1);

        IF LTRIM(RTRIM(ISNULL(@motivo_actualizacion, ''))) = ''
            RAISERROR('El motivo de actualizacion es obligatorio.', 16, 1);

        SELECT @id_matriz_anterior = id_matriz
        FROM dbo.MatrizIPERC
        WHERE id_puesto = @id_puesto AND vigente = 1;

        IF @id_matriz_anterior IS NULL
            RAISERROR('El puesto no tiene una matriz vigente que actualizar.', 16, 1);

        SELECT @version_nueva = MAX(numero_version) + 1
        FROM dbo.MatrizIPERC
        WHERE id_puesto = @id_puesto;

        BEGIN TRANSACTION;

            UPDATE dbo.MatrizIPERC
            SET vigente = 0
            WHERE id_matriz = @id_matriz_anterior;

            INSERT INTO dbo.MatrizIPERC
                (id_puesto, id_elaborador, numero_version, fecha_elaboracion, vigente, motivo_actualizacion)
            VALUES
                (@id_puesto, @id_elaborador, @version_nueva, CAST(GETDATE() AS DATE), 1, @motivo_actualizacion);

            SET @id_matriz_nueva = SCOPE_IDENTITY();

            INSERT INTO dbo.PeligroRiesgo
                (id_matriz, id_peligro, actividad, riesgo_asociado,
                 id_nivel_riesgo_inicial, medidas_control, id_nivel_riesgo_residual)
            SELECT
                @id_matriz_nueva, id_peligro, actividad, riesgo_asociado,
                id_nivel_riesgo_inicial, medidas_control, id_nivel_riesgo_residual
            FROM dbo.PeligroRiesgo
            WHERE id_matriz = @id_matriz_anterior;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @id_matriz_nueva = NULL;

        DECLARE @mensaje VARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@mensaje, 16, 1);
    END CATCH
END
GO

--PRUEBAS REQ13 
SELECT id_matriz, id_puesto, numero_version, vigente, fecha_elaboracion, motivo_actualizacion
FROM dbo.MatrizIPERC
WHERE id_puesto = 11
ORDER BY numero_version;
GO

DECLARE @nueva INT;
EXEC dbo.sp_ActualizarMatrizIPERC
     @id_puesto            = 11,
     @id_elaborador        = 40,
     @motivo_actualizacion = 'Prueba REQ13 - incorporacion de nuevos controles',
     @id_matriz_nueva      = @nueva OUTPUT;
SELECT @nueva AS id_matriz_nueva;
GO

SELECT id_matriz, id_puesto, numero_version, vigente, fecha_elaboracion, motivo_actualizacion
FROM dbo.MatrizIPERC
WHERE id_puesto = 11
ORDER BY numero_version;

SELECT m.id_matriz, m.numero_version, m.vigente, COUNT(pr.id_peligro_riesgo) AS lineas
FROM dbo.MatrizIPERC m
LEFT JOIN dbo.PeligroRiesgo pr ON pr.id_matriz = m.id_matriz
WHERE m.id_puesto = 11
GROUP BY m.id_matriz, m.numero_version, m.vigente
ORDER BY m.numero_version;
GO

SELECT id_puesto, COUNT(*) AS versiones_vigentes
FROM dbo.MatrizIPERC
WHERE vigente = 1
GROUP BY id_puesto
HAVING COUNT(*) > 1;
GO


--REQ14
IF OBJECT_ID('dbo.sp_ConsultarAccionesVisibles') IS NOT NULL
    DROP PROCEDURE dbo.sp_ConsultarAccionesVisibles;
GO
IF OBJECT_ID('dbo.fn_AccionesVisibles') IS NOT NULL
    DROP FUNCTION dbo.fn_AccionesVisibles;
GO
IF OBJECT_ID('dbo.vw_AccionCorrectivaDetalle') IS NOT NULL
    DROP VIEW dbo.vw_AccionCorrectivaDetalle;
GO

CREATE VIEW dbo.vw_AccionCorrectivaDetalle
AS
SELECT
    ac.id_accion,
    s.id_sede,
    s.nombre                            AS sede,
    ar.id_area,
    ar.nombre                           AS area,
    ac.id_hallazgo,
    ac.id_responsable,
    resp.nombres + ' ' + resp.apellidos AS responsable,
    resp.cargo                          AS cargo_responsable,
    sev.nombre                          AS severidad,
    est.nombre                          AS estado,
    ac.descripcion,
    ac.fecha_asignacion,
    ac.fecha_limite,
    ac.fecha_cierre
FROM dbo.AccionCorrectiva AS ac
INNER JOIN dbo.HallazgoInspeccion AS h    ON h.id_hallazgo    = ac.id_hallazgo
INNER JOIN dbo.Inspeccion         AS i    ON i.id_inspeccion  = h.id_inspeccion
INNER JOIN dbo.Area               AS ar   ON ar.id_area       = i.id_area
INNER JOIN dbo.Sede               AS s    ON s.id_sede        = ar.id_sede
INNER JOIN dbo.Empleado           AS resp ON resp.id_empleado = ac.id_responsable
INNER JOIN dbo.NivelSeveridad     AS sev  ON sev.id_severidad = ac.id_severidad
INNER JOIN dbo.EstadoAccion       AS est  ON est.id_estado    = ac.id_estado;
GO

CREATE FUNCTION dbo.fn_AccionesVisibles (@id_empleado INT)
RETURNS TABLE
AS
RETURN
(
    SELECT d.*
    FROM dbo.vw_AccionCorrectivaDetalle AS d
    INNER JOIN dbo.Empleado AS e ON e.id_empleado = @id_empleado
    INNER JOIN dbo.Area     AS a ON a.id_area     = e.id_area
    WHERE
        d.id_responsable = e.id_empleado
        OR ((e.cargo LIKE 'Supervisor%' OR e.cargo LIKE 'Jefe de Area%')
            AND d.id_area = e.id_area)
        OR ((e.cargo LIKE 'Coordinador%' OR e.cargo LIKE 'Gerente%'
             OR e.cargo LIKE 'Ingeniero de Seguridad%')
            AND d.id_sede = a.id_sede)
);
GO

CREATE PROCEDURE dbo.sp_ConsultarAccionesVisibles
    @id_empleado INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE id_empleado = @id_empleado)
        RAISERROR('El empleado indicado no existe.', 16, 1);
    ELSE
        SELECT *
        FROM dbo.fn_AccionesVisibles(@id_empleado)
        ORDER BY id_accion;
END
GO

--PRUEBAS REQ14
SELECT COUNT(*) AS acciones_totales FROM dbo.vw_AccionCorrectivaDetalle;
GO

SELECT sede, area, COUNT(*) AS acciones_visibles
FROM dbo.fn_AccionesVisibles(40)
GROUP BY sede, area;
GO

SELECT sede, area, COUNT(*) AS acciones_visibles
FROM dbo.fn_AccionesVisibles(53)
GROUP BY sede, area;
GO

BEGIN TRANSACTION;

    DECLARE @hz INT =
        (SELECT TOP 1 h.id_hallazgo
         FROM dbo.HallazgoInspeccion AS h
         INNER JOIN dbo.Inspeccion AS i ON i.id_inspeccion = h.id_inspeccion
         WHERE i.id_area = 5
         ORDER BY h.id_hallazgo);

    INSERT INTO dbo.AccionCorrectiva
        (id_hallazgo, id_responsable, id_severidad, id_estado, descripcion, fecha_asignacion, fecha_limite)
    VALUES
        (@hz, 38, 1, 1, 'Prueba REQ14 - accion asignada al operario',
         CAST(GETDATE() AS DATE), DATEADD(DAY, 15, CAST(GETDATE() AS DATE)));

    EXEC dbo.sp_ConsultarAccionesVisibles @id_empleado = 38;   -- solo 1 fila: la propia

ROLLBACK TRANSACTION;
GO