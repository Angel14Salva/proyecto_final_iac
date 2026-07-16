package com.segat.trujilloinformado.messaging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;

import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Poller (long-polling) de la cola SQS de Notificaciones (segat-cola-notificaciones).
 * Esa cola recibe por fan-out todo lo publicado en el topico SNS de negocio.
 * <p>
 * La entrega final al ciudadano/trabajador (WhatsApp/email) la sigue
 * haciendo el webhook de n8n, disparado directamente desde
 * ReporteServiceImpl/TareaServiceImpl -- este consumer solo confirma que el
 * mensaje efectivamente atraveso la capa de mensajeria (SNS -> SQS) y lo
 * retira de la cola, dejando trazabilidad en el log.
 */
@Component
public class SqsNotificacionConsumer {

    private static final Logger LOGGER = Logger.getLogger(SqsNotificacionConsumer.class.getName());
    private static final int MAX_MESSAGES = 10;
    private static final int WAIT_TIME_SECONDS = 10;

    private final SqsClient sqsClient;

    @Value("${aws.sqs.notificaciones-queue-url}")
    private String notificacionesQueueUrl;

    public SqsNotificacionConsumer(SqsClient sqsClient) {
        this.sqsClient = sqsClient;
    }

    @Scheduled(fixedDelay = 15000, initialDelay = 15000)
    public void consumirNotificaciones() {
        try {
            List<Message> messages = sqsClient.receiveMessage(ReceiveMessageRequest.builder()
                    .queueUrl(notificacionesQueueUrl)
                    .maxNumberOfMessages(MAX_MESSAGES)
                    .waitTimeSeconds(WAIT_TIME_SECONDS)
                    .build()).messages();

            for (Message message : messages) {
                LOGGER.info("Notificacion recibida desde SQS (via SNS negocio): " + message.body());

                sqsClient.deleteMessage(DeleteMessageRequest.builder()
                        .queueUrl(notificacionesQueueUrl)
                        .receiptHandle(message.receiptHandle())
                        .build());
            }
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Error al hacer polling de la cola SQS de notificaciones", e);
        }
    }
}
