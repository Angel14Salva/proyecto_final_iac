package com.segat.trujilloinformado.model.dao;

import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.enums.Status;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TareaDao extends JpaRepository<Tarea, Long> {
    @EntityGraph(attributePaths = {"report"})
    Page<Tarea> findByWorkerEmail(String workerEmail, Pageable pageable);

    // Método para filtrar por estado
    Page<Tarea> findByWorkerEmailAndStatus(String email, Status estado, Pageable pageable);
}
