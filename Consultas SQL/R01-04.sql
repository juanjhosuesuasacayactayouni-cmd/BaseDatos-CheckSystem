USE SafeWork_CheckSystem;
GO
--1
SELECT 
    S.nombre AS [Sede],
    A.nombre AS [Área Operativa],
    COUNT(DISTINCT I.id_inspeccion) AS [Total Inspecciones],
    COUNT(HI.id_hallazgo) AS [Total Hallazgos Detectados]
FROM Sede S
INNER JOIN Area A ON S.id_sede = A.id_sede
INNER JOIN Inspeccion I ON A.id_area = I.id_area
LEFT JOIN HallazgoInspeccion HI ON I.id_inspeccion = HI.id_inspeccion
WHERE YEAR(I.fecha_realizada) = 2026
GROUP BY S.nombre, A.nombre
HAVING COUNT(DISTINCT I.id_inspeccion) > 5
ORDER BY [Total Inspecciones] DESC;
GO
--2
SELECT
    PT.nombre AS [Puesto de Trabajo],
    M.numero_version AS [Versión],
    CASE WHEN M.vigente = 1 THEN 'VIGENTE' ELSE 'Histórica' END AS [Estado],
    M.fecha_elaboracion AS [Fecha de Elaboración],
    CONCAT(E.nombres, ' ', E.apellidos) AS [Elaborado Por],
    ISNULL(M.motivo_actualizacion, 'Versión inicial') AS [Motivo de Actualización]
FROM MatrizIPERC M
INNER JOIN PuestoTrabajo PT ON M.id_puesto = PT.id_puesto
INNER JOIN Empleado E ON M.id_elaborador = E.id_empleado
WHERE PT.id_puesto = 1
ORDER BY M.numero_version DESC;
GO
--3
SELECT 
    PT.nombre AS [Puesto de Trabajo],
    PR.actividad AS [Actividad Evaluada],
    P.descripcion AS [Peligro Identificado],
    PR.riesgo_asociado AS [Riesgo Asociado],
    NRI.nombre AS [Nivel Riesgo Inicial],
    PR.medidas_control AS [Medidas de Control Estipuladas],
    NRR.nombre AS [Nivel Riesgo Residual]
FROM MatrizIPERC M
INNER JOIN PuestoTrabajo PT ON M.id_puesto = PT.id_puesto
INNER JOIN PeligroRiesgo PR ON M.id_matriz = PR.id_matriz
INNER JOIN Peligro P ON PR.id_peligro = P.id_peligro
INNER JOIN NivelRiesgo NRI ON PR.id_nivel_riesgo_inicial = NRI.id_nivel_riesgo
INNER JOIN NivelRiesgo NRR ON PR.id_nivel_riesgo_residual = NRR.id_nivel_riesgo
WHERE M.vigente = 1 
  AND PT.id_puesto = 1;
GO
--4
SELECT 
    I.id_inspeccion AS [N° Inspección],
    I.fecha_realizada AS [Fecha],
    HI.descripcion AS [Descripción del Hallazgo],
    NRM.nombre AS [Nivel Riesgo Momentáneo],
    P.descripcion AS [Peligro Enlazado en Matriz IPERC],
    PR.actividad AS [Actividad de la Matriz]
FROM HallazgoInspeccion HI
INNER JOIN Inspeccion I ON HI.id_inspeccion = I.id_inspeccion
INNER JOIN NivelRiesgo NRM ON HI.id_nivel_riesgo_momentaneo = NRM.id_nivel_riesgo
INNER JOIN PeligroRiesgo PR ON HI.id_peligro_riesgo = PR.id_peligro_riesgo
INNER JOIN Peligro P ON PR.id_peligro = P.id_peligro
WHERE I.id_inspeccion = 1;
GO
