package com.segat.trujilloinformado.model.dto.tarea;

import java.util.List;

public record CompletarTareaRequest(
        String notes, List<String> evidences
) {

}
