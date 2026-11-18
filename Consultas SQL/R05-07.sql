-- ============================================================================
-- PROYECTO: SafeWork - CheckSystem 
-- ============================================================================

USE SafeWork_CheckSystem;
GO

-- ============================================================================
-- REQUISITO 05 (REQ05): Historial cronológico de cambios de estado de una
--                       acción correctiva (Auditor de Calidad).
-- Reglas de Negocio asociadas: Regla 6 (secuencia estricta e inalterable) y
--                              Regla 8 (prohibición de borrado físico).
-- Objetos SQL Server: Índice no agrupado, Trigger INSTEAD OF (inalterabilidad),
--                     Procedimiento Almacenado y función de ventana LAG().
-- ============================================================================

-- 1. Índice de cobertura para acelerar la reconstrucción cronológica de auditoría
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HistorialEstadoAccion_AccionOrden')
    DROP INDEX IX_HistorialEstadoAccion_AccionOrden ON HistorialEstadoAccion;
GO

CREATE NONCLUSTERED INDEX IX_HistorialEstadoAccion_AccionOrden
    ON HistorialEstadoAccion (id_accion ASC, numero_cambio ASC)
    INCLUDE (id_estado, id_empleado, fecha_cambio, comentario);
GO

-- 2. Trigger de inalterabilidad del historial (garantiza Regla 6 y Regla 8)
IF OBJECT_ID('TR_HistorialEstadoAccion_Inalterable', 'TR') IS NOT NULL
    DROP TRIGGER TR_HistorialEstadoAccion_Inalterable;
GO

CREATE TRIGGER TR_HistorialEstadoAccion_Inalterable
ON HistorialEstadoAccion
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    RAISERROR(
        'Regla de Negocio 6 y 8: El historial de estados de una acción correctiva es inalterable; no se permite modificar ni eliminar registros.',
        16, 1
    );
END;
GO

-- 3. Procedimiento almacenado para consultar la trazabilidad secuencial
IF OBJECT_ID('usp_ConsultarHistorialAccionCorrectiva', 'P') IS NOT NULL
    DROP PROCEDURE usp_ConsultarHistorialAccionCorrectiva;
GO

CREATE PROCEDURE usp_ConsultarHistorialAccionCorrectiva
    @id_accion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        h.id_accion,
        ac.descripcion AS accion_correctiva,
        h.numero_cambio AS paso_secuencial,
        ISNULL(
            LAG(ea.nombre) OVER (PARTITION BY h.id_accion ORDER BY h.numero_cambio ASC),
            'Registro Inicial'
        ) AS estado_anterior,
        ea.nombre AS estado_asignado,
        FORMAT(h.fecha_cambio, 'dd/MM/yyyy HH:mm:ss') AS fecha_hora_modificacion,
        ISNULL(
            DATEDIFF(
                HOUR,
                LAG(h.fecha_cambio) OVER (PARTITION BY h.id_accion ORDER BY h.numero_cambio ASC),
                h.fecha_cambio
            ),
            0
        ) AS horas_desde_estado_previo,
        CONCAT(e.nombres, ' ', e.apellidos) AS responsable_cambio,
        e.cargo AS cargo_responsable,
        ISNULL(h.comentario, 'Sin comentario adjunto') AS comentario_adjunto
    FROM HistorialEstadoAccion h
    INNER JOIN AccionCorrectiva ac ON h.id_accion = ac.id_accion
    INNER JOIN EstadoAccion ea     ON h.id_estado = ea.id_estado
    INNER JOIN Empleado e          ON h.id_empleado = e.id_empleado
    WHERE (@id_accion IS NULL OR h.id_accion = @id_accion)
    ORDER BY h.id_accion ASC, h.numero_cambio ASC;
END;
GO

-- Ejecución de prueba REQ05 (auditoría general y por acción específica)
EXEC usp_ConsultarHistorialAccionCorrectiva @id_accion = NULL;
GO


-- ============================================================================
-- REQUISITO 06 (REQ06): Listado de acciones correctivas vencidas en estado
--                       'Pendiente' o 'En Proceso' (Coordinador de SST).
-- Reglas de Negocio asociadas: Regla 5 (plazo límite, responsable y severidad)
--                              y Regla 9 (control de cierre de acciones).
-- Objetos SQL Server: Índice filtrado, Función Escalar (UDF) y Vista (VIEW).
-- ============================================================================

-- 1. Índice filtrado únicamente sobre acciones abiertas (fecha_cierre IS NULL)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AccionCorrectiva_PlazosAbiertos')
    DROP INDEX IX_AccionCorrectiva_PlazosAbiertos ON AccionCorrectiva;
GO

CREATE NONCLUSTERED INDEX IX_AccionCorrectiva_PlazosAbiertos
    ON AccionCorrectiva (fecha_limite ASC, id_estado, id_severidad)
    INCLUDE (id_hallazgo, id_responsable, descripcion, fecha_asignacion)
    WHERE fecha_cierre IS NULL;
GO

-- 2. Función escalar para calcular los días calendario de atraso
IF OBJECT_ID('dbo.fn_CalcularDiasAtraso', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_CalcularDiasAtraso;
GO

CREATE FUNCTION dbo.fn_CalcularDiasAtraso (@fecha_limite DATE)
RETURNS INT
AS
BEGIN
    DECLARE @dias_atraso INT;
    SET @dias_atraso = DATEDIFF(DAY, @fecha_limite, CAST(GETDATE() AS DATE));
    RETURN CASE WHEN @dias_atraso > 0 THEN @dias_atraso ELSE 0 END;
END;
GO

-- 3. Vista de seguimiento inmediato de acciones correctivas fuera de plazo
IF OBJECT_ID('vw_AccionesCorrectivasVencidas', 'V') IS NOT NULL
    DROP VIEW vw_AccionesCorrectivasVencidas;
GO

CREATE VIEW vw_AccionesCorrectivasVencidas
AS
SELECT
    ac.id_accion,
    s.nombre AS sede,
    a.nombre AS area,
    hi.descripcion AS hallazgo_original,
    ac.descripcion AS accion_correctiva,
    CONCAT(e.nombres, ' ', e.apellidos) AS responsable_asignado,
    e.cargo AS cargo_responsable,
    e.correo AS correo_responsable,
    ns.nombre AS severidad,
    ea.nombre AS estado_actual,
    ac.fecha_asignacion,
    ac.fecha_limite,
    dbo.fn_CalcularDiasAtraso(ac.fecha_limite) AS dias_vencidos
FROM AccionCorrectiva ac
INNER JOIN EstadoAccion ea       ON ac.id_estado = ea.id_estado
INNER JOIN HallazgoInspeccion hi ON ac.id_hallazgo = hi.id_hallazgo
INNER JOIN Inspeccion i          ON hi.id_inspeccion = i.id_inspeccion
INNER JOIN Area a                ON i.id_area = a.id_area
INNER JOIN Sede s                ON a.id_sede = s.id_sede
INNER JOIN Empleado e            ON ac.id_responsable = e.id_empleado
INNER JOIN NivelSeveridad ns     ON ac.id_severidad = ns.id_severidad
WHERE ea.nombre IN ('Pendiente', 'En Proceso')
  AND ac.fecha_limite < CAST(GETDATE() AS DATE);
GO

-- Ejecución de prueba REQ06
SELECT *
FROM vw_AccionesCorrectivasVencidas
ORDER BY dias_vencidos DESC, severidad ASC;
GO


-- ============================================================================
-- REQUISITO 07 (REQ07): Registro de incidentes ocurridos en el área durante
--                       el último año (Encargado de SST).
-- Reglas de Negocio asociadas: Regla 7 (clasificación, área, registrador y
--                              medidas preventivas) y Regla 8 (historial).
-- Objetos SQL Server: Índice no agrupado, Función con Valores de Tabla en
--                     Línea (iTVF) y consulta analítica con ROLLUP.
-- ============================================================================

-- 1. Índice compuesto por área y fecha de ocurrencia descendente
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Incidente_AreaFecha')
    DROP INDEX IX_Incidente_AreaFecha ON Incidente;
GO

CREATE NONCLUSTERED INDEX IX_Incidente_AreaFecha
    ON Incidente (id_area ASC, fecha_ocurrencia DESC)
    INCLUDE (id_categoria, id_registrador, descripcion);
GO

-- 2. Función con valores de tabla en línea (Inline TVF) para filtrar los
--    incidentes de los últimos 12 meses por área (o todas si @id_area IS NULL)
IF OBJECT_ID('dbo.fn_IncidentesUltimoAnioPorArea', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_IncidentesUltimoAnioPorArea;
GO

CREATE FUNCTION dbo.fn_IncidentesUltimoAnioPorArea
(
    @id_area          INT  = NULL,
    @fecha_referencia DATE = NULL
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        inc.id_incidente,
        s.nombre AS sede,
        a.nombre AS area,
        ci.nombre AS categoria_incidente,
        inc.fecha_ocurrencia,
        inc.descripcion AS descripcion_hechos,
        CONCAT(e.nombres, ' ', e.apellidos) AS empleado_registrador,
        e.cargo AS cargo_registrador,
        COUNT(mp.id_medida) AS medidas_preventivas_derivadas
    FROM Incidente inc
    INNER JOIN CategoriaIncidente ci ON inc.id_categoria = ci.id_categoria
    INNER JOIN Area a                ON inc.id_area = a.id_area
    INNER JOIN Sede s                ON a.id_sede = s.id_sede
    INNER JOIN Empleado e            ON inc.id_registrador = e.id_empleado
    LEFT JOIN MedidaPreventiva mp    ON inc.id_incidente = mp.id_incidente
    WHERE (@id_area IS NULL OR inc.id_area = @id_area)
      AND inc.fecha_ocurrencia >= DATEADD(YEAR, -1, ISNULL(@fecha_referencia, CAST(GETDATE() AS DATE)))
      AND inc.fecha_ocurrencia <= ISNULL(@fecha_referencia, CAST(GETDATE() AS DATE))
    GROUP BY
        inc.id_incidente,
        s.nombre,
        a.nombre,
        ci.nombre,
        inc.fecha_ocurrencia,
        inc.descripcion,
        e.nombres,
        e.apellidos,
        e.cargo
);
GO

-- Ejecución de prueba REQ07 (A: Detalle cronológico del último año)
SELECT
    id_incidente,
    sede,
    area,
    categoria_incidente,
    fecha_ocurrencia,
    descripcion_hechos,
    empleado_registrador,
    cargo_registrador,
    medidas_preventivas_derivadas
FROM dbo.fn_IncidentesUltimoAnioPorArea(NULL, CAST(GETDATE() AS DATE))
ORDER BY fecha_ocurrencia DESC;
GO

-- Ejecución de prueba REQ07 (B: Resumen de siniestralidad por área y categoría)
SELECT
    ISNULL(area, 'TOTAL GENERAL') AS area,
    ISNULL(categoria_incidente, 'Subtotal Área') AS categoria_incidente,
    COUNT(*) AS total_incidentes
FROM dbo.fn_IncidentesUltimoAnioPorArea(NULL, CAST(GETDATE() AS DATE))
GROUP BY ROLLUP (area, categoria_incidente);
GO
