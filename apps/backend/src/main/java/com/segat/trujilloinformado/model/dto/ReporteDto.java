package com.segat.trujilloinformado.model.dto;

import com.segat.trujilloinformado.model.entity.enums.Priority;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.enums.Type;
import com.segat.trujilloinformado.model.entity.interno.Location;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class ReporteDto {
    private Long id;
    private Type type;
    private String description;
    private Location location;
    private List<String> photos; // aquí guardaremos URLs de Cloudinary
    private List<String> evidence; // aquí guardaremos URLs de Cloudinary
    private Priority priority;
    private String zone;
    private Status status;
    private Integer rating;
    private String citizenId;
    private String citizenName;
    private String citizenPhone;
    private String citizenEmail;
    private String assignedTo;
    private String assignedBy;
    private Instant createdAt;
    private Instant updatedAt;
    private Instant assignedAt;
    private Instant completedAt;
}
