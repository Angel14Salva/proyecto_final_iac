package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.entity.dynamo.NotificationRecord;
import com.segat.trujilloinformado.service.INotificationDynamoService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import java.time.Instant;
import java.util.UUID;
import java.util.logging.Level;
import java.util.logging.Logger;

@Service
public class NotificationDynamoServiceImpl implements INotificationDynamoService {

    private static final Logger LOGGER = Logger.getLogger(NotificationDynamoServiceImpl.class.getName());

    private final DynamoDbTable<NotificationRecord> notificationsTable;

    public NotificationDynamoServiceImpl(DynamoDbEnhancedClient dynamoDbEnhancedClient,
                                          @Value("${aws.dynamodb.notifications-table}") String notificationsTableName) {
        this.notificationsTable = dynamoDbEnhancedClient.table(notificationsTableName, TableSchema.fromBean(NotificationRecord.class));
    }

    @Override
    public void registrarNotificacion(String userId, String type, String message, String relatedEntityId) {
        try {
            NotificationRecord record = NotificationRecord.builder()
                    .notificationId(UUID.randomUUID().toString())
                    .userId(userId)
                    .type(type)
                    .message(message)
                    .relatedEntityId(relatedEntityId)
                    .createdAt(Instant.now().toString())
                    .build();
            notificationsTable.putItem(record);
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "No se pudo registrar la notificacion en DynamoDB para el usuario " + userId, e);
        }
    }
}
