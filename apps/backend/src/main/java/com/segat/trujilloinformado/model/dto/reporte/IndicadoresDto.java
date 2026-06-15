package com.segat.trujilloinformado.model.dto.reporte;

import lombok.Builder;
import lombok.Data;

import java.util.Map;

@Data
@Builder
public class IndicadoresDto {
    private long total;
    private long pending;
    private long resolved;
    private Map<String, Long> byType; // Ej: {"BARRIDO": 15, "MALEZA": 10}
}