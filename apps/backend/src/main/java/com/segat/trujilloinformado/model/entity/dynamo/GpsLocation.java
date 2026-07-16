
package com.segat.trujilloinformado.model.entity.dynamo;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

/**
 * Mapea la tabla DynamoDB "segat-gps-locations" (modules/database, Terraform).
 * hash_key = reporteId, range_key = timestamp -- coincide con el schema real
 * de la tabla ya desplegada, no inventar atributos nuevos sin actualizar
 * primero infraestructure/iac/modules/database/main.tf.
 */
@DynamoDbBean
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GpsLocation {

    private String reporteId;
    private String timestamp;
    private Double lat;
    private Double lng;
    private String recordedBy;
    private Long expirationTime; // TTL de DynamoDB (epoch seconds), tabla ya tiene ttl.attribute_name = expiration_time

    @DynamoDbPartitionKey
    @DynamoDbAttribute("reporte_id")
    public String getReporteId() {
        return reporteId;
    }

    @DynamoDbSortKey
    public String getTimestamp() {
        return timestamp;
    }
}

