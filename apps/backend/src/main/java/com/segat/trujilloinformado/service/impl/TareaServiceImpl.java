package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.ReporteDao;
import com.segat.trujilloinformado.model.dao.TareaDao;
import com.segat.trujilloinformado.model.dao.UsuarioDao;
import com.segat.trujilloinformado.model.dto.ReporteDto;
import com.segat.trujilloinformado.model.dto.TareaDto;
import com.segat.trujilloinformado.model.entity.Evidencia;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.interno.Location;
import com.segat.trujilloinformado.service.INotificationService;
import com.segat.trujilloinformado.service.ITareaService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collections;
import java.util.List;

@Service
public class TareaServiceImpl implements ITareaService {
    @Autowired
    private TareaDao tareaDao;

    @Autowired
    private UsuarioDao usuarioDao;

    @Autowired
    private ReporteDao reporteDao;

    @Autowired
    private INotificationService notificationService;

    @Transactional
    @Override
    public Tarea save(TareaDto tareaDto) {
        Reporte reporte = reporteDao.findById(tareaDto.getReportId()).orElseThrow(() -> new IllegalStateException("Report not found"));
        Usuario worker = usuarioDao.findById(tareaDto.getWorkerId()).orElseThrow(() -> new IllegalStateException("Worker not found"));
        Usuario supervisor = usuarioDao.findById(tareaDto.getSupervisorId()).orElseThrow(() -> new IllegalStateException("Supervisor not found"));

        reporte.setType(tareaDto.getType());
        reporte.setAssignedBy(supervisor);
        reporte.setAssignedTo(worker);
        reporte.setAssignedAt(tareaDto.getAssignedAt());
        reporte.setCompletedAt(tareaDto.getCompletedAt());
        reporte.setStatus(tareaDto.getStatus() != null ? tareaDto.getStatus() : Status.PENDIENTE);
        reporteDao.save(reporte);

        Tarea tarea = Tarea.builder()
                .id(tareaDto.getId())
                .report(reporte)
                .worker(worker)
                .supervisor(supervisor)
                .description(tareaDto.getDescription())
                .type(tareaDto.getType())
                .lat(reporte.getLat())
                .lng(reporte.getLng())
                .address(reporte.getAddress())
                .status(tareaDto.getStatus() != null ? tareaDto.getStatus() : Status.PENDIENTE)
                .assignedAt(tareaDto.getAssignedAt())
                .completedAt(tareaDto.getCompletedAt())
                .build();

        Tarea tareaGuardada = tareaDao.save(tarea);

        try {
            // Llamar al nuevo método asíncrono
            notificationService.sendNewTaskNotification(tareaGuardada);
        } catch (Exception e) {
            // No bloquear la respuesta al supervisor por un error de notificación
            // log.error("No se pudo encolar la notificación para la tarea {}", tareaGuardada.getId(), e);
        }

        return tareaGuardada;
    }

    @Override
    public TareaDto completeTask(Long tareaId, String notes, List<String> evidences) {
        // 1. Busca la tarea existente
        Tarea tarea = tareaDao.findById(tareaId)
                .orElseThrow(() -> new IllegalStateException("La tarea con ID " + tareaId + " no existe."));

        // Ahora `String.join` funciona perfectamente porque `evidences` es una lista
        String evidenceAsString = (evidences != null && !evidences.isEmpty())
                ? String.join(",", evidences)
                : null;

        // 2. Modifica solo los campos necesarios
        tarea.setStatus(Status.RESUELTO);
        tarea.setEvidences(evidenceAsString);
        tarea.setCompletedAt(Instant.now());
        tarea.setNotes(notes);
        // Aquí puedes agregar la lógica para guardar la URL de la foto si es necesario
        // Evidencia evidencia = new Evidencia(null, tarea, tarea.getWorker(), photoUrl, Instant.now());

        // 3. Actualiza el reporte asociado
        Reporte reporte = tarea.getReport();
        reporte.setStatus(Status.RESUELTO);
        reporte.setEvidence(evidenceAsString);
        reporte.setCompletedAt(Instant.now());

        // 4. Guarda las entidades actualizadas (JPA lo hará al final de la transacción, pero explícito es más claro)
        tareaDao.save(tarea);
        reporteDao.save(reporte);

        // 5. Devuelve un DTO con la información actualizada
        return convertToDto(tarea);
    }

    @Transactional(readOnly = true)
    @Override
    public Tarea findById(Long id) {
        return tareaDao.findById(id).orElse(null);
    }

    @Override
    public void delete(Tarea tarea) {
        tareaDao.delete(tarea);
    }

    @Override
    public boolean existsById(Long id) {
        return tareaDao.existsById(id);
    }

    @Override
    public List<Tarea> findAll() {
        return (List<Tarea>) tareaDao.findAll();
    }

    @Transactional(readOnly = true)
    @Override
    public Page<TareaDto> findByWorkerEmail(String workerEmail, Status estado, Pageable pageable) {
        if (estado != null) {
            Page<Tarea> tareasPage = tareaDao.findByWorkerEmailAndStatus(workerEmail, estado, pageable);
            return tareasPage.map(this::convertToDto);
        }
        else {
            Page<Tarea> tareasPage = tareaDao.findByWorkerEmail(workerEmail, pageable);
            return tareasPage.map(this::convertToDto);
        }
    }

    // Método privado para encapsular la lógica de conversión
    private TareaDto convertToDto(Tarea tarea) {
        // Asumiendo que 'getPhotos()' en Reporte devuelve una List<String>
        List<String> photos = tarea.getReport() != null ? Collections.singletonList(tarea.getReport().getPhotos()) : Collections.emptyList();

        ReporteDto reporteInfo = ReporteDto.builder()
                .id(tarea.getReport().getId())
                .location(Location.builder()
                        .lng(tarea.getReport().getLng()) // Datos del reporte
                        .lat(tarea.getReport().getLat())   // Datos del reporte
                        .address(tarea.getReport().getAddress()) // Datos del reporte
                        .build())
                .photos(photos)
                .type(tarea.getReport().getType()) // Datos del reporte
                .build();

        return TareaDto.builder()
                .id(tarea.getId()) // No te olvides de los demás campos
                .status(tarea.getStatus())
                .description(tarea.getDescription())
                .report(reporteInfo)
                .assignedAt(tarea.getAssignedAt())
                .completedAt(tarea.getCompletedAt())
                .build();
    }
}
