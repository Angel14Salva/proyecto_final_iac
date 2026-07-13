package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.entity.dynamo.GpsLocation;
import com.segat.trujilloinformado.service.IGpsService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.logging.Level;
import java.util.logging.Logger;

@Service
public class GpsServiceImpl implements IGpsService {

    private static final Logger LOGGER = Logger.getLogger(GpsServiceImpl.class.getName());
    private static final long TTL_DIAS = 90;

    private final DynamoDbTable<GpsLocation> gpsTable;

    public GpsServiceImpl(DynamoDbEnhancedClient dynamoDbEnhancedClient,
                           @Value("${aws.dynamodb.gps-table}") String gpsTableName) {
        this.gpsTable = dynamoDbEnhancedClient.table(gpsTableName, TableSchema.fromBean(GpsLocation.class));
    }

    @Override
    public void registrarUbicacion(Long reporteId, double lat, double lng, String recordedBy) {
        try {
            Instant now = Instant.now();
            GpsLocation location = GpsLocation.builder()
                    .reporteId(String.valueOf(reporteId))
                    .timestamp(DateTimeFormatter.ISO_INSTANT.format(now))
                    .lat(lat)
                    .lng(lng)
                    .recordedBy(recordedBy)
                    .expirationTime(now.plusSeconds(TTL_DIAS * 24 * 3600).getEpochSecond())
                    .build();
            gpsTable.putItem(location);
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "No se pudo registrar la ubicacion GPS del reporte " + reporteId + " en DynamoDB", e);
        }
    }
}
