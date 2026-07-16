
package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.NotificationLogDao;
import com.segat.trujilloinformado.model.entity.NotificationLog;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.service.INotificationService;
import com.segat.trujilloinformado.service.IUsuarioService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/**
 * Envia notificaciones por email directamente via SMTP (JavaMailSender).
 * Reemplaza la version anterior que dependia de webhooks de n8n -- se quito
 * n8n del proyecto para no tener que levantar y mantener una instancia
 * aparte solo para reenviar estos dos mensajes.
 * <p>
 * WhatsApp queda fuera de alcance por ahora: la API de WhatsApp Business
 * exige una plantilla de mensaje pre-aprobada por Meta para mensajes que
 * inicia el negocio (no el usuario), y el equipo no tiene esa aprobacion
 * todavia. Si se agrega mas adelante, este mismo patron (metodo privado que
 * arma el mensaje + try/catch que no relanza) sirve de base.
 */
@Slf4j
@Service
public class NotificationServiceImpl implements INotificationService {

    private final JavaMailSender mailSender;
    private final NotificationLogDao logRepository;

    @Autowired
    private IUsuarioService usuarioService;

    @Value("${mail.from}")
    private String mailFrom;

    public NotificationServiceImpl(JavaMailSender mailSender, NotificationLogDao logRepository) {
        this.mailSender = mailSender;
        this.logRepository = logRepository;
    }

    /**
     * Este método se ejecuta en un hilo separado
     * y no bloqueará la creación del reporte.
     */
    @Async
    public void sendNewReportNotification(Reporte reporte) {
        Integer zoneNumber = reporte.getZone().getNumber();
        Usuario supervisor = usuarioService.findByZoneNumber(zoneNumber)
                .orElseThrow(() -> new IllegalStateException("El supervisor asignado a la zona " + zoneNumber + " no existe."));
        String supervisorEmail = supervisor.getEmail();

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss")
                .withZone(ZoneId.of("America/Lima"));
        String formattedDate = reporte.getCreatedAt() != null ? formatter.format(reporte.getCreatedAt()) : "";

        String asunto = "Nuevo reporte pendiente #" + reporte.getId();
        String mensaje = String.format(
                "¡Nuevo Reporte Pendiente! ID: %d, Tipo: %s, Estado: %s, Ubicación: %s, Fecha: %s",
                reporte.getId(),
                reporte.getType().toString(),
                reporte.getStatus().toString(),
                reporte.getAddress(),
                formattedDate
        );

        // NOTA: se reutiliza la columna "recipientPhone" para guardar el
        // email del destinatario. El proyecto usa ddl-auto=validate sin
        // Flyway/Liquibase, asi que agregar una columna nueva (por ejemplo
        // recipient_email) exigiria un ALTER TABLE manual coordinado contra
        // la base real -- fuera de alcance de este cambio. Renombrar el
        // campo queda como mejora futura si se agrega una herramienta de
        // migraciones.
        NotificationLog notificationLog = NotificationLog.builder()
                .reporte(reporte)
                .recipientPhone(supervisorEmail)
                .messageContent(mensaje)
                .status("PENDING")
                .build();
        logRepository.save(notificationLog);

        try {
            enviarCorreo(supervisorEmail, asunto, mensaje);
            notificationLog.setStatus("SENT");
        } catch (Exception e) {
            notificationLog.setStatus("FAILED");
            log.error("No se pudo enviar el correo de nuevo reporte al supervisor {}: {}", supervisorEmail, e.getMessage());
        } finally {
            logRepository.save(notificationLog);
        }
    }

    @Async
    public void sendNewTaskNotification(Tarea tarea) {
        String workerEmail = tarea.getWorker().getEmail();

        String asunto = "Nueva tarea asignada #" + tarea.getId();
        String mensaje = String.format(
                "¡Nueva Tarea Asignada! ID: %d, Tipo: %s, Ubicación: %s",
                tarea.getId(),
                tarea.getType().toString(),
                tarea.getAddress()
        );

        NotificationLog notificationLog = NotificationLog.builder()
                .reporte(tarea.getReport())
                .recipientPhone(workerEmail)
                .messageContent(mensaje)
                .status("PENDING")
                .build();
        logRepository.save(notificationLog);

        try {
            enviarCorreo(workerEmail, asunto, mensaje);
            notificationLog.setStatus("SENT");
        } catch (Exception e) {
            notificationLog.setStatus("FAILED");
            log.error("No se pudo enviar el correo de nueva tarea al trabajador {}: {}", workerEmail, e.getMessage());
        } finally {
            logRepository.save(notificationLog);
        }
    }

    private void enviarCorreo(String destinatario, String asunto, String cuerpo) {
        SimpleMailMessage mensaje = new SimpleMailMessage();
        mensaje.setFrom(mailFrom);
        mensaje.setTo(destinatario);
        mensaje.setSubject(asunto);
        mensaje.setText(cuerpo);
        mailSender.send(mensaje);
    }
}

