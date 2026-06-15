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

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class TareaDto {
    private Long id;
    private Long reportId;
    private ReporteDto report;
    private Long workerId;
    private Long supervisorId;
    private String evidence;
    private String description;
    private Type type;
    private Location location;
    private Status status;
    private Instant assignedAt;
    private Instant completedAt;
}
