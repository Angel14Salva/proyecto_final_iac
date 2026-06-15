package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.NotificationLogDao;
import com.segat.trujilloinformado.model.entity.NotificationLog;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.service.INotificationService;
import com.segat.trujilloinformado.service.IUsuarioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

@Service
public class NotificationServiceImpl implements INotificationService {
    private final RestTemplate restTemplate;
    private final NotificationLogDao logRepository;

    @Autowired
    private IUsuarioService usuarioService;

    @Value("${n8n.webhook.new-report}")
    private String newReport;

    @Value("${n8n.webhook.new-task}")
    private String newTask;

    public NotificationServiceImpl(NotificationLogDao logRepository) {
        this.restTemplate = new RestTemplate();
        this.logRepository = logRepository;
    }

    /**
     * Este método se ejecuta en un hilo separado
     * y no bloqueará la creación del reporte.
     */
    @Async
    public void sendNewReportNotification(Reporte reporte) {
        // 1. Obtener el supervisor y su teléfono
        // (Asumo que puedes obtener el supervisor desde la zona del reporte)
        Integer zoneNumber = reporte.getZone().getNumber();
        Usuario supervisor = usuarioService.findByZoneNumber(zoneNumber).orElseThrow(() -> new IllegalStateException("La supervisor asignado a la zona " + zoneNumber + " no existe."));; // O lógica similar
        String supervisorPhone = supervisor.getPhone(); // Tu modelo Usuario debe tener 'phone'

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss")
                .withZone(ZoneId.of("America/Lima"));
        String formattedDate = reporte.getCreatedAt() != null ? formatter.format(reporte.getCreatedAt()) : "";

        // 2. Formatear el mensaje
        String message = String.format(
                "¡Nuevo Reporte Pendiente! ID: %d, Tipo: %s, Estado: %s, Ubicación: %s, Fecha: %s",
                reporte.getId(),
                reporte.getType().toString(),
                reporte.getStatus().toString(),
                reporte.getAddress(),
                formattedDate
        );

        // 3. Crear el log inicial
        NotificationLog log = NotificationLog.builder()
                .reporte(reporte)
                .recipientPhone(supervisorPhone)
                .messageContent(message)
                .status("PENDING")
                .build();
        logRepository.save(log);

        // 4. Preparar los datos para el webhook de n8n
        Map<String, String> payload = new HashMap<>();
        payload.put("supervisorPhone", supervisorPhone);
        payload.put("reporteId", String.valueOf(reporte.getId()));
        payload.put("tipo", reporte.getType().toString());
        payload.put("estado", "Pendiente"); // Criterio 3: Indicar "Pendiente"
        payload.put("ubicacion", reporte.getAddress());
        payload.put("fechaRegistro", reporte.getCreatedAt().toString());

        try {
            // 5. Enviar a n8n
            restTemplate.postForObject(newReport, payload, String.class);

            // 6. Actualizar el log a ÉXITO
            log.setStatus("SENT");
            logRepository.save(log);

        } catch (Exception e) {
            // 7. Actualizar el log a FALLIDO
            log.setStatus("FAILED");
            logRepository.save(log);
            // Manejar el error (log.error("..."))
        }
    }

    @Async
    public void sendNewTaskNotification(Tarea tarea) {
        // Criterio 3: Obtener el teléfono del trabajador
        String workerPhone = tarea.getWorker().getPhone();

        // Formatear el mensaje (puedes hacerlo aquí o en n8n)
        String message = String.format(
                "¡Nueva Tarea Asignada! ID: %d, Tipo: %s, Ubicación: %s",
                tarea.getId(),
                tarea.getType().toString(),
                tarea.getAddress() // La ubicación está en el reporte
        );

        // Criterio 4: Registrar en el historial
        NotificationLog log = NotificationLog.builder()
                .reporte(tarea.getReport()) // Asocia el log al reporte principal
                .recipientPhone(workerPhone)
                .messageContent(message)
                .status("PENDING")
                .build();
        logRepository.save(log);

        // Preparar el payload para n8n
        Map<String, String> payload = new HashMap<>();
        payload.put("workerPhone", workerPhone);
        payload.put("taskId", String.valueOf(tarea.getId()));
        payload.put("tipo", tarea.getType().toString());
        payload.put("ubicacion", tarea.getReport().getAddress());
        payload.put("fechaAsignacion", tarea.getCreatedAt().toString());

        try {
            // Enviar a la NUEVA URL de n8n
            restTemplate.postForObject(newTask, payload, String.class);
            log.setStatus("SENT");
            logRepository.save(log);

        } catch (Exception e) {
            log.setStatus("FAILED");
            logRepository.save(log);
            // log.error("Error al enviar notificación de tarea a n8n", e);
        }
    }
}
