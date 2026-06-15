package com.segat.trujilloinformado.model.dao;

import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.enums.Status;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ReporteDao extends JpaRepository<Reporte, Long>, JpaSpecificationExecutor<Reporte> {
    /**
     * Busca y pagina todos los reportes que pertenecen a un ciudadano,
     * identificado por su email.
     * Spring Data JPA automáticamente genera la consulta:
     * "SELECT r FROM Report r WHERE r.citizen.email = :email"
     */
    Page<Reporte> findByCitizenEmail(String email, Pageable pageable);
    Page<Reporte> findByCitizenEmailAndStatus(String email, Status estado, Pageable pageable);
    Page<Reporte> findByZoneNumber(Integer number, Pageable pageable);
}
