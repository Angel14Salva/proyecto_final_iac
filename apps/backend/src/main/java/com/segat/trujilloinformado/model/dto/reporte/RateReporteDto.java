package com.segat.trujilloinformado.model.dto.reporte;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class RateReporteDto {
    @NotNull(message = "La calificación es obligatoria")
    @Min(1)
    @Max(5)
    private Integer rating;
    private String comment; // Opcional
}