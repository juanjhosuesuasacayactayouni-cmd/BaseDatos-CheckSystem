CREATE DATABASE SafeWork_CheckSystem;
GO

USE SafeWork_CheckSystem;
GO

CREATE TABLE AccionCorrectiva
(
  id_accion        INT          IDENTITY(1,1),
  id_hallazgo      INT          NOT NULL,
  id_responsable   INT          NOT NULL,
  id_severidad     INT          NOT NULL,
  id_estado        INT          NOT NULL,
  descripcion      VARCHAR(500) NOT NULL,
  fecha_asignacion DATE         NOT NULL,
  fecha_limite     DATE         NOT NULL,
  fecha_cierre     DATE        ,
  CONSTRAINT PK_AccionCorrectiva PRIMARY KEY (id_accion)
)
GO

CREATE TABLE Area
(
  id_area     INT          IDENTITY(1,1),
  id_sede     INT          NOT NULL,
  nombre      VARCHAR(100) NOT NULL,
  descripcion VARCHAR(300),
  CONSTRAINT PK_Area PRIMARY KEY (id_area)
)
GO

CREATE TABLE CategoriaIncidente
(
  id_categoria INT          IDENTITY(1,1),
  nombre       VARCHAR(60)  NOT NULL,
  descripcion  VARCHAR(200),
  CONSTRAINT PK_CategoriaIncidente PRIMARY KEY (id_categoria)
)
GO

CREATE TABLE Empleado
(
  id_empleado INT          IDENTITY(1,1),
  id_area     INT          NOT NULL,
  nombres     VARCHAR(100) NOT NULL,
  apellidos   VARCHAR(100) NOT NULL,
  cargo       VARCHAR(120)  NOT NULL,
  correo      VARCHAR(120) NOT NULL,
  CONSTRAINT PK_Empleado PRIMARY KEY (id_empleado)
)
GO

CREATE TABLE EstadoAccion
(
  id_estado   INT          IDENTITY(1,1),
  nombre      VARCHAR(30)  NOT NULL,
  descripcion VARCHAR(200),
  CONSTRAINT PK_EstadoAccion PRIMARY KEY (id_estado)
)
GO

CREATE TABLE HallazgoInspeccion
(
  id_hallazgo                INT          IDENTITY(1,1),
  id_inspeccion              INT          NOT NULL,
  id_peligro_riesgo          INT          NOT NULL,
  descripcion                VARCHAR(500) NOT NULL,
  id_nivel_riesgo_momentaneo INT          NOT NULL,
  CONSTRAINT PK_HallazgoInspeccion PRIMARY KEY (id_hallazgo)
)
GO

CREATE TABLE HistorialEstadoAccion
(
  id_accion     INT          NOT NULL,
  numero_cambio INT          NOT NULL,
  id_estado     INT          NOT NULL,
  id_empleado   INT          NOT NULL,
  fecha_cambio  DATETIME     NOT NULL DEFAULT GETDATE(),
  comentario    VARCHAR(300),
  CONSTRAINT PK_HistorialEstadoAccion PRIMARY KEY (id_accion, numero_cambio)
)
GO

CREATE TABLE Incidente
(
  id_incidente     INT          IDENTITY(1,1),
  id_area          INT          NOT NULL,
  id_categoria     INT          NOT NULL,
  id_registrador   INT          NOT NULL,
  fecha_ocurrencia DATE         NOT NULL,
  descripcion      VARCHAR(500) NOT NULL,
  CONSTRAINT PK_Incidente PRIMARY KEY (id_incidente)
)
GO

CREATE TABLE Inspeccion
(
  id_inspeccion       INT          IDENTITY(1,1),
  id_area             INT          NOT NULL,
  id_inspector        INT          NOT NULL,
  tipo_inspeccion     VARCHAR(20)  NOT NULL,
  fecha_programada    DATE        ,
  fecha_realizada     DATE        ,
  observacion_general VARCHAR(500),
  CONSTRAINT PK_Inspeccion PRIMARY KEY (id_inspeccion)
)
GO

CREATE TABLE MatrizIPERC
(
  id_matriz            INT          IDENTITY(1,1),
  id_puesto            INT          NOT NULL,
  id_elaborador        INT          NOT NULL,
  numero_version       INT          NOT NULL,
  fecha_elaboracion    DATE         NOT NULL,
  vigente              BIT          NOT NULL DEFAULT 1,
  motivo_actualizacion VARCHAR(300),
  CONSTRAINT PK_MatrizIPERC PRIMARY KEY (id_matriz)
)
GO

CREATE TABLE MedidaPreventiva
(
  id_medida              INT          IDENTITY(1,1),
  id_incidente           INT          NOT NULL,
  id_responsable         INT          NOT NULL,
  descripcion            VARCHAR(500) NOT NULL,
  fecha_implementacion   DATE        ,
  evaluacion_efectividad VARCHAR(20)  NOT NULL DEFAULT 'Pendiente',
  CONSTRAINT PK_MedidaPreventiva PRIMARY KEY (id_medida)
)
GO

CREATE TABLE NivelRiesgo
(
  id_nivel_riesgo INT          IDENTITY(1,1),
  nombre          VARCHAR(40)  NOT NULL,
  descripcion     VARCHAR(200),
  CONSTRAINT PK_NivelRiesgo PRIMARY KEY (id_nivel_riesgo)
)
GO

CREATE TABLE NivelSeveridad
(
  id_severidad INT          IDENTITY(1,1),
  nombre       VARCHAR(40)  NOT NULL,
  descripcion  VARCHAR(200),
  CONSTRAINT PK_NivelSeveridad PRIMARY KEY (id_severidad)
)
GO

CREATE TABLE Peligro
(
  id_peligro      INT          IDENTITY(1,1),
  id_tipo_peligro INT          NOT NULL,
  descripcion     VARCHAR(300) NOT NULL,
  CONSTRAINT PK_Peligro PRIMARY KEY (id_peligro)
)
GO

CREATE TABLE PeligroRiesgo
(
  id_peligro_riesgo        INT          IDENTITY(1,1),
  id_matriz                INT          NOT NULL,
  id_peligro               INT          NOT NULL,
  actividad                VARCHAR(200) NOT NULL,
  riesgo_asociado          VARCHAR(300) NOT NULL,
  id_nivel_riesgo_inicial  INT          NOT NULL,
  medidas_control          VARCHAR(500),
  id_nivel_riesgo_residual INT          NOT NULL,
  CONSTRAINT PK_PeligroRiesgo PRIMARY KEY (id_peligro_riesgo)
)
GO

CREATE TABLE PuestoTrabajo
(
  id_puesto   INT          IDENTITY(1,1),
  id_area     INT          NOT NULL,
  nombre      VARCHAR(100) NOT NULL,
  descripcion VARCHAR(300),
  CONSTRAINT PK_PuestoTrabajo PRIMARY KEY (id_puesto)
)
GO

CREATE TABLE Sede
(
  id_sede   INT          IDENTITY(1,1),
  nombre    VARCHAR(100) NOT NULL,
  direccion VARCHAR(200) NOT NULL,
  distrito  VARCHAR(80)  NOT NULL,
  estado    BIT          NOT NULL DEFAULT 1,
  CONSTRAINT PK_Sede PRIMARY KEY (id_sede)
)
GO

CREATE TABLE TipoPeligro
(
  id_tipo_peligro INT          IDENTITY(1,1),
  nombre          VARCHAR(60)  NOT NULL,
  descripcion     VARCHAR(200),
  CONSTRAINT PK_TipoPeligro PRIMARY KEY (id_tipo_peligro)
)
GO

ALTER TABLE Area
  ADD CONSTRAINT FK_Sede_TO_Area
    FOREIGN KEY (id_sede)
    REFERENCES Sede (id_sede)
GO
  
ALTER TABLE PuestoTrabajo
  ADD CONSTRAINT FK_Area_TO_PuestoTrabajo
    FOREIGN KEY (id_area)
    REFERENCES Area (id_area)
GO

ALTER TABLE Empleado
  ADD CONSTRAINT FK_Area_TO_Empleado
    FOREIGN KEY (id_area)
    REFERENCES Area (id_area)
GO

ALTER TABLE Peligro
  ADD CONSTRAINT FK_TipoPeligro_TO_Peligro
    FOREIGN KEY (id_tipo_peligro)
    REFERENCES TipoPeligro (id_tipo_peligro)
GO

ALTER TABLE MatrizIPERC
  ADD CONSTRAINT FK_PuestoTrabajo_TO_MatrizIPERC
    FOREIGN KEY (id_puesto)
    REFERENCES PuestoTrabajo (id_puesto)
GO

ALTER TABLE MatrizIPERC
  ADD CONSTRAINT FK_Empleado_TO_MatrizIPERC
    FOREIGN KEY (id_elaborador)
    REFERENCES Empleado (id_empleado)
GO

ALTER TABLE PeligroRiesgo
  ADD CONSTRAINT FK_MatrizIPERC_TO_PeligroRiesgo
    FOREIGN KEY (id_matriz)
    REFERENCES MatrizIPERC (id_matriz)
GO

ALTER TABLE PeligroRiesgo
  ADD CONSTRAINT FK_Peligro_TO_PeligroRiesgo
    FOREIGN KEY (id_peligro)
    REFERENCES Peligro (id_peligro)
GO

ALTER TABLE PeligroRiesgo
  ADD CONSTRAINT FK_NivelRiesgo_TO_PeligroRiesgo
    FOREIGN KEY (id_nivel_riesgo_inicial)
    REFERENCES NivelRiesgo (id_nivel_riesgo)
GO

ALTER TABLE PeligroRiesgo
  ADD CONSTRAINT FK_NivelRiesgo_TO_PeligroRiesgo1
    FOREIGN KEY (id_nivel_riesgo_residual)
    REFERENCES NivelRiesgo (id_nivel_riesgo)
GO

ALTER TABLE Inspeccion
  ADD CONSTRAINT FK_Area_TO_Inspeccion
    FOREIGN KEY (id_area)
    REFERENCES Area (id_area)
GO

ALTER TABLE Inspeccion
  ADD CONSTRAINT FK_Empleado_TO_Inspeccion
    FOREIGN KEY (id_inspector)
    REFERENCES Empleado (id_empleado)
GO

ALTER TABLE HallazgoInspeccion
  ADD CONSTRAINT FK_Inspeccion_TO_HallazgoInspeccion
    FOREIGN KEY (id_inspeccion)
    REFERENCES Inspeccion (id_inspeccion)
GO

ALTER TABLE HallazgoInspeccion
  ADD CONSTRAINT FK_PeligroRiesgo_TO_HallazgoInspeccion
    FOREIGN KEY (id_peligro_riesgo)
    REFERENCES PeligroRiesgo (id_peligro_riesgo)
GO

ALTER TABLE HallazgoInspeccion
  ADD CONSTRAINT FK_NivelRiesgo_TO_HallazgoInspeccion
    FOREIGN KEY (id_nivel_riesgo_momentaneo)
    REFERENCES NivelRiesgo (id_nivel_riesgo)
GO

ALTER TABLE AccionCorrectiva
  ADD CONSTRAINT FK_HallazgoInspeccion_TO_AccionCorrectiva
    FOREIGN KEY (id_hallazgo)
    REFERENCES HallazgoInspeccion (id_hallazgo)
GO

ALTER TABLE AccionCorrectiva
  ADD CONSTRAINT FK_Empleado_TO_AccionCorrectiva
    FOREIGN KEY (id_responsable)
    REFERENCES Empleado (id_empleado)
GO

ALTER TABLE AccionCorrectiva
  ADD CONSTRAINT FK_NivelSeveridad_TO_AccionCorrectiva
    FOREIGN KEY (id_severidad)
    REFERENCES NivelSeveridad (id_severidad)
GO

ALTER TABLE AccionCorrectiva
  ADD CONSTRAINT FK_EstadoAccion_TO_AccionCorrectiva
    FOREIGN KEY (id_estado)
    REFERENCES EstadoAccion (id_estado)
GO

ALTER TABLE HistorialEstadoAccion
  ADD CONSTRAINT FK_AccionCorrectiva_TO_HistorialEstadoAccion
    FOREIGN KEY (id_accion)
    REFERENCES AccionCorrectiva (id_accion)
GO

ALTER TABLE HistorialEstadoAccion
  ADD CONSTRAINT FK_EstadoAccion_TO_HistorialEstadoAccion
    FOREIGN KEY (id_estado)
    REFERENCES EstadoAccion (id_estado)
GO

ALTER TABLE HistorialEstadoAccion
  ADD CONSTRAINT FK_Empleado_TO_HistorialEstadoAccion
    FOREIGN KEY (id_empleado)
    REFERENCES Empleado (id_empleado)
GO

ALTER TABLE Incidente
  ADD CONSTRAINT FK_Area_TO_Incidente
    FOREIGN KEY (id_area)
    REFERENCES Area (id_area)
GO

ALTER TABLE Incidente
  ADD CONSTRAINT FK_CategoriaIncidente_TO_Incidente
    FOREIGN KEY (id_categoria)
    REFERENCES CategoriaIncidente (id_categoria)
GO

ALTER TABLE Incidente
  ADD CONSTRAINT FK_Empleado_TO_Incidente
    FOREIGN KEY (id_registrador)
    REFERENCES Empleado (id_empleado)
GO

ALTER TABLE MedidaPreventiva
  ADD CONSTRAINT FK_Incidente_TO_MedidaPreventiva
    FOREIGN KEY (id_incidente)
    REFERENCES Incidente (id_incidente)
GO

ALTER TABLE MedidaPreventiva
  ADD CONSTRAINT FK_Empleado_TO_MedidaPreventiva
    FOREIGN KEY (id_responsable)
    REFERENCES Empleado (id_empleado)
GO