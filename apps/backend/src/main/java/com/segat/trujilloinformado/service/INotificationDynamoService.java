
package com.segat.trujilloinformado.service;

public interface INotificationDynamoService {
    /**
     * Guarda un registro liviano del evento de notificacion en DynamoDB
     * (tabla segat-notifications), ademas del log que ya se guarda en
     * Postgres via NotificationServiceImpl. No lanza excepciones hacia el
     * llamador.
     */
    void registrarNotificacion(String userId, String type, String message, String relatedEntityId);
}

