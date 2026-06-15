package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.dto.ReporteDto;
import com.segat.trujilloinformado.model.dto.reporte.IndicadoresDto;
import com.segat.trujilloinformado.model.dto.reporte.RateReporteDto;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.enums.Type;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.LocalDate;
import java.util.List;

import static org.springframework.data.jpa.domain.AbstractPersistable_.id;

public interface IReporteService {
    Reporte save(ReporteDto reporteDto);
    Reporte findById(Long id);
    Page<Reporte> findByCitizenEmail(String email, Status estado, Pageable pageable);
    Page<Reporte> findByZoneNumber(Integer number, Pageable pageable);
    Page<Reporte> findSupervisorReportsWithFilters(
            Integer zoneNumber,
            List<Status> statuses, // Plural y tipo Lista
            List<Type> types,       // Plural y tipo Lista
            LocalDate startDate,
            LocalDate endDate,
            Pageable pageable);
    List<Reporte> findAllSupervisorReportsWithFilters(
            Integer zoneNumber,
            List<Status> statuses,
            List<Type> types,
            LocalDate startDate,
            LocalDate endDate);
    IndicadoresDto calculateIndicators(
            Integer zoneNumber,
            List<Status> statuses,
            List<Type> types,
            LocalDate startDate,
            LocalDate endDate);
    void delete(Reporte reporte);
    Reporte calificarReporte(Long reporteId, String citizenEmail, RateReporteDto dto);
    boolean existsById(Long id);
    List<Reporte> findAll();
    Page<Reporte> findAll(Pageable pageable);
}
