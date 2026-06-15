package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.dto.TareaDto;
import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.enums.Status;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface ITareaService {
    Tarea save(TareaDto tareaDto);
    TareaDto completeTask(Long tareaId, String notes, List<String> evidences);
    Tarea findById(Long id);
    void delete(Tarea tarea);
    boolean existsById(Long id);
    List<Tarea> findAll();
    Page<TareaDto> findByWorkerEmail(String workerEmail, Status estado, Pageable pageable);
}
