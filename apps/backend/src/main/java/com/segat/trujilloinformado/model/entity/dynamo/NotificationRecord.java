
package com.segat.trujilloinformado.model.entity.dynamo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

/**
 * Mapea la tabla DynamoDB "segat-notifications" (modules/database, Terraform).
 * hash_key = notificationId, range_key = userId -- coincide con el schema
 * real de la tabla ya desplegada.
 * <p>
 * Este registro es un log liviano en DynamoDB de los eventos que pasaron por
 * la capa de mensajeria (para trazabilidad/auditoria), separado del
 * NotificationLog en Postgres que ya usa NotificationServiceImpl para la
 * entrega real via n8n. No reemplaza esa tabla, la complementa.
 */
@DynamoDbBean
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationRecord {

    private String notificationId;
    private String userId;
    private String type;
    private String message;
    private String relatedEntityId;
    private String createdAt;

    @DynamoDbPartitionKey
    public String getNotificationId() {
        return notificationId;
    }

    @DynamoDbSortKey
    public String getUserId() {
        return userId;
    }
}

