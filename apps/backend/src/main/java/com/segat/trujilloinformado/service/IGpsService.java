
package com.segat.trujilloinformado.service;

public interface IGpsService {
    /**
     * Registra la ubicacion de un reporte en DynamoDB. No lanza excepciones
     * hacia el llamador -- un fallo en DynamoDB nunca debe tumbar la
     * creacion del reporte en Postgres, que es la operacion principal.
     */
    void registrarUbicacion(Long reporteId, double lat, double lng, String recordedBy);
}

