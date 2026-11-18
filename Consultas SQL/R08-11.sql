USE SafeWork_CheckSystem;
GO

-- REQ08: Medidas preventivas implementadas y evaluadas
SELECT
    mp.id_medida,
    mp.descripcion              AS medida_preventiva,
    mp.evaluacion_efectividad,
    mp.fecha_implementacion,
    e.nombres + ' ' + e.apellidos AS responsable,
    i.fecha_ocurrencia          AS fecha_incidente
FROM MedidaPreventiva mp
INNER JOIN Empleado  e ON e.id_empleado  = mp.id_responsable
INNER JOIN Incidente i ON i.id_incidente = mp.id_incidente
WHERE mp.evaluacion_efectividad NOT LIKE 'Pendiente%'
ORDER BY i.fecha_ocurrencia DESC;
GO

-- REQ09: Inspecciones por inspector (inopinadas y periodicas)
SELECT
    e.id_empleado,
    e.nombres + ' ' + e.apellidos AS inspector,
    SUM(CASE WHEN ins.tipo_inspeccion = 'Inopinada' THEN 1 ELSE 0 END) AS inspecciones_inopinadas,
    SUM(CASE WHEN ins.tipo_inspeccion = 'Periodica' THEN 1 ELSE 0 END) AS inspecciones_periodicas,
    COUNT(*) AS total_inspecciones
FROM Empleado e
INNER JOIN Inspeccion ins ON ins.id_inspector = e.id_empleado
GROUP BY e.id_empleado, e.nombres, e.apellidos
ORDER BY total_inspecciones DESC;
GO

-- REQ10: Areas con siniestralidad superior al promedio
WITH incidentes_area AS (
    SELECT
        a.id_area,
        a.nombre AS area,
        s.nombre AS sede,
        COUNT(i.id_incidente) AS total_incidentes
    FROM Area a
    INNER JOIN Sede s ON s.id_sede = a.id_sede
    LEFT JOIN Incidente i ON i.id_area = a.id_area
    GROUP BY a.id_area, a.nombre, s.nombre
)
SELECT
    area,
    sede,
    total_incidentes,
    (SELECT AVG(CAST(total_incidentes AS DECIMAL(10,2))) FROM incidentes_area) AS promedio_global
FROM incidentes_area
WHERE total_incidentes > (SELECT AVG(CAST(total_incidentes AS DECIMAL(10,2))) FROM incidentes_area)
ORDER BY total_incidentes DESC;
GO

-- REQ11: Sedes con mas acciones Verificadas que Pendientes en un rango de fechas
DECLARE @fecha_inicio DATE = '20260701';
DECLARE @fecha_fin    DATE = '20260930';

SELECT
    s.id_sede,
    s.nombre AS sede,
    SUM(CASE WHEN ea.nombre = 'Verificado' THEN 1 ELSE 0 END) AS acciones_verificadas,
    SUM(CASE WHEN ea.nombre = 'Pendiente'  THEN 1 ELSE 0 END) AS acciones_pendientes
FROM AccionCorrectiva ac
INNER JOIN EstadoAccion      ea ON ea.id_estado     = ac.id_estado
INNER JOIN HallazgoInspeccion h ON h.id_hallazgo    = ac.id_hallazgo
INNER JOIN Inspeccion        ins ON ins.id_inspeccion = h.id_inspeccion
INNER JOIN Area              a  ON a.id_area        = ins.id_area
INNER JOIN Sede              s  ON s.id_sede        = a.id_sede
WHERE ac.fecha_asignacion BETWEEN @fecha_inicio AND @fecha_fin
GROUP BY s.id_sede, s.nombre
HAVING SUM(CASE WHEN ea.nombre = 'Verificado' THEN 1 ELSE 0 END)
     > SUM(CASE WHEN ea.nombre = 'Pendiente'  THEN 1 ELSE 0 END)
ORDER BY acciones_verificadas DESC;
GO