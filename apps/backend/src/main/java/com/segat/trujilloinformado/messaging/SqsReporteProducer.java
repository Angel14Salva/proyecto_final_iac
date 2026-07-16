package com.segat.trujilloinformado.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.segat.trujilloinformado.model.entity.Reporte;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

import java.util.HashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Publica un mensaje por cada reporte nuevo en la cola SQS de Reportes
 * (segat-cola-reportes). No lanza excepciones hacia el llamador.
 */
@Component
public class SqsReporteProducer {

    private static final Logger LOGGER = Logger.getLogger(SqsReporteProducer.class.getName());

    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;

    @Value("${aws.sqs.reportes-queue-url}")
    private String reportesQueueUrl;

    public SqsReporteProducer(SqsClient sqsClient, ObjectMapper objectMapper) {
        this.sqsClient = sqsClient;
        this.objectMapper = objectMapper;
    }

    public void publicarNuevoReporte(Reporte reporte) {
        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("reporteId", reporte.getId());
            payload.put("tipo", reporte.getType().toString());
            payload.put("estado", reporte.getStatus().toString());
            payload.put("zona", reporte.getZone() != null ? reporte.getZone().getNumber() : null);
            payload.put("lat", reporte.getLat());
            payload.put("lng", reporte.getLng());
            payload.put("createdAt", reporte.getCreatedAt() != null ? reporte.getCreatedAt().toString() : null);

            String body = objectMapper.writeValueAsString(payload);

            sqsClient.sendMessage(SendMessageRequest.builder()
                    .queueUrl(reportesQueueUrl)
                    .messageBody(body)
                    .build());
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "No se pudo publicar el reporte " + reporte.getId() + " en la cola SQS de reportes", e);
        }
    }
}
