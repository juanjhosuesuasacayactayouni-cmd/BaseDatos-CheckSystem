--15--
CREATE TRIGGER TRG_ValidarCierreVerificado_Completo
ON AccionCorrectiva
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1 
        FROM inserted i
        JOIN deleted d ON i.id_accion = d.id_accion
        JOIN EstadoAccion ea ON i.id_estado = ea.id_estado
        WHERE ea.nombre = 'Verificado' AND d.id_estado <> i.id_estado
    )
    BEGIN

        IF NOT EXISTS (
            SELECT 1 
            FROM inserted i
            JOIN HistorialEstadoAccion h ON i.id_accion = h.id_accion
            JOIN EstadoAccion ea ON h.id_estado = ea.id_estado
            WHERE ea.nombre = 'Subsanado'
        )
        BEGIN
            THROW 51001, 'Error: No se puede marcar como Verificado una accion que no ha pasado previamente por el estado Subsanado.', 1;
            ROLLBACK TRANSACTION;
            RETURN;
        END

     
        IF EXISTS (
            SELECT 1 FROM inserted WHERE fecha_cierre IS NULL
        )
        BEGIN
            THROW 51002, 'Error: Toda accion correctiva en estado Verificado debe registrar obligatoriamente una fecha de cierre.', 1;
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 
            FROM inserted i
            JOIN HistorialEstadoAccion h ON i.id_accion = h.id_accion
            WHERE h.numero_cambio = (SELECT MAX(numero_cambio) FROM HistorialEstadoAccion WHERE id_accion = i.id_accion)
              AND h.id_empleado = i.id_responsable
        )
        BEGIN
            THROW 51003, 'Error de segregacion de funciones (Regla 10): El empleado responsable de ejecutar la accion no puede ser el mismo que apruebe el cierre a Verificado.', 1;
            ROLLBACK TRANSACTION;
            RETURN;
        END
    END
END;
GO

--16--
CREATE PROCEDURE sp_NotificarAccionesProximasAVencer
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FechaConsulta DATE = DATEADD(DAY, 1, CAST(GETDATE() AS DATE));

    DECLARE @correo_actual VARCHAR(120) = NULL;
    DECLARE @correo        VARCHAR(120);
    DECLARE @nombre        VARCHAR(200);
    DECLARE @cuerpo        NVARCHAR(MAX) = N'';
    DECLARE @asunto        NVARCHAR(200);
    DECLARE @id_accion     INT;
    DECLARE @descripcion   VARCHAR(500);
    DECLARE @fecha_lim     DATE;

    DECLARE cur_acciones CURSOR LOCAL FAST_FORWARD FOR
        SELECT ac.id_accion,
               e.correo,
               e.nombres + ' ' + e.apellidos,
               ac.descripcion,
               ac.fecha_limite
        FROM AccionCorrectiva ac
        INNER JOIN Empleado     e  ON ac.id_responsable = e.id_empleado
        INNER JOIN EstadoAccion ea ON ac.id_estado      = ea.id_estado
        WHERE ac.fecha_limite = @FechaConsulta
          AND ea.nombre IN ('Pendiente', 'En Proceso')
        ORDER BY e.correo, ac.id_accion;

    OPEN cur_acciones;
    FETCH NEXT FROM cur_acciones
        INTO @id_accion, @correo, @nombre, @descripcion, @fecha_lim;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        IF @correo_actual IS NULL OR @correo <> @correo_actual
        BEGIN

            IF @correo_actual IS NOT NULL
            BEGIN
                SET @cuerpo = @cuerpo + CHAR(13) + CHAR(10)
                            + N'Registre el avance o la subsanacion antes del vencimiento.'
                            + CHAR(13) + CHAR(10)
                            + N'Seguridad y Salud Ocupacional - SafeWork';

                BEGIN TRY
                    EXEC msdb.dbo.sp_send_dbmail
                         @profile_name = N'SafeWorkMail',
                         @recipients   = @correo_actual,
                         @subject      = @asunto,
                         @body         = @cuerpo,
                         @body_format  = N'TEXT';
                END TRY
                BEGIN CATCH
                    PRINT 'No se pudo enviar el correo a ' + @correo_actual + ': ' + ERROR_MESSAGE();
                END CATCH
            END

            SET @correo_actual = @correo;
            SET @asunto = N'[SafeWork] Acciones correctivas que vencen el '
                        + CONVERT(NVARCHAR(10), @fecha_lim, 103);
            SET @cuerpo = N'Estimado(a) ' + @nombre + N':' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10)
                        + N'Las siguientes acciones correctivas a su cargo vencen manana:'
                        + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
        END

        SET @cuerpo = @cuerpo
            + N'- Accion #' + CAST(@id_accion AS NVARCHAR(10))
            + N' | Vence: ' + CONVERT(NVARCHAR(10), @fecha_lim, 103)
            + CHAR(13) + CHAR(10)
            + N'  ' + @descripcion + CHAR(13) + CHAR(10);

        FETCH NEXT FROM cur_acciones
            INTO @id_accion, @correo, @nombre, @descripcion, @fecha_lim;
    END

    IF @correo_actual IS NOT NULL
    BEGIN
        SET @cuerpo = @cuerpo + CHAR(13) + CHAR(10)
                    + N'Registre el avance o la subsanacion antes del vencimiento.'
                    + CHAR(13) + CHAR(10)
                    + N'Seguridad y Salud Ocupacional - SafeWork';

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                 @profile_name = N'SafeWorkMail',
                 @recipients   = @correo_actual,
                 @subject      = @asunto,
                 @body         = @cuerpo,
                 @body_format  = N'TEXT';
        END TRY
        BEGIN CATCH
            PRINT 'No se pudo enviar el correo a ' + @correo_actual + ': ' + ERROR_MESSAGE();
        END CATCH
    END

    CLOSE cur_acciones;
    DEALLOCATE cur_acciones;
END;
GO
--17--

IF COL_LENGTH('dbo.AccionCorrectiva', 'anulado') IS NULL
    ALTER TABLE dbo.AccionCorrectiva ADD anulado BIT NOT NULL DEFAULT 0;
IF COL_LENGTH('dbo.AccionCorrectiva', 'motivo_anulacion') IS NULL
    ALTER TABLE dbo.AccionCorrectiva ADD motivo_anulacion VARCHAR(300) NULL;
IF COL_LENGTH('dbo.AccionCorrectiva', 'fecha_anulacion') IS NULL
    ALTER TABLE dbo.AccionCorrectiva ADD fecha_anulacion DATETIME NULL;
GO

CREATE TRIGGER TRG_PrevenirEliminacionAccionCorrectiva
ON AccionCorrectiva
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    UPDATE ac
    SET ac.anulado          = 1,
        ac.motivo_anulacion = 'Intento de eliminacion fisica bloqueado',
        ac.fecha_anulacion  = GETDATE()
    FROM AccionCorrectiva ac
    INNER JOIN deleted d ON ac.id_accion = d.id_accion
    WHERE ac.anulado = 0;

    PRINT 'Alerta de Seguridad: la eliminacion fisica de registros de seguridad '
        + 'esta prohibida. El registro fue marcado como ANULADO y se conserva en el historial.';
END;
GO

 