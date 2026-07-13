package com.segat.trujilloinformado.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.MessageAttributeValue;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Publica eventos de negocio (reporte creado, tarea asignada) en el topico
 * SNS "segat-sns-negocio". Ese topico ya esta suscrito a la cola SQS de
 * Notificaciones (modules/messaging en Terraform), asi que todo lo que se
 * publica aqui termina en esa cola. No lanza excepciones hacia el llamador.
 */
@Component
public class SnsNegocioPublisher {

    private static final Logger LOGGER = Logger.getLogger(SnsNegocioPublisher.class.getName());

    private final SnsClient snsClient;
    private final ObjectMapper objectMapper;

    @Value("${aws.sns.negocio-topic-arn}")
    private String negocioTopicArn;

    public SnsNegocioPublisher(SnsClient snsClient, ObjectMapper objectMapper) {
        this.snsClient = snsClient;
        this.objectMapper = objectMapper;
    }

    public void publicarEvento(String eventType, Map<String, Object> payload) {
        try {
            String body = objectMapper.writeValueAsString(payload);

            snsClient.publish(PublishRequest.builder()
                    .topicArn(negocioTopicArn)
                    .message(body)
                    .messageAttributes(Map.of(
                            "eventType", MessageAttributeValue.builder()
                                    .dataType("String")
                                    .stringValue(eventType)
                                    .build()
                    ))
                    .build());
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "No se pudo publicar el evento '" + eventType + "' en el topico SNS de negocio", e);
        }
    }
}
