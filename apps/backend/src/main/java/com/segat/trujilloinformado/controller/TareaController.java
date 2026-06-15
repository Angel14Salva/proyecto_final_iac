package com.segat.trujilloinformado.controller;

import com.segat.trujilloinformado.model.dto.TareaDto;
import com.segat.trujilloinformado.model.dto.tarea.CompletarTareaRequest;
import com.segat.trujilloinformado.model.entity.Tarea;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.interno.Location;
import com.segat.trujilloinformado.model.payload.MessageResponse;
import com.segat.trujilloinformado.service.ITareaService;
import com.segat.trujilloinformado.service.IUsuarioService;
import com.segat.trujilloinformado.service.impl.CloudinaryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class TareaController {
    @Autowired
    private ITareaService tareaService;

    @Autowired
    private IUsuarioService usuarioService;

    @Autowired
    private CloudinaryService cloudinaryService;

    @PostMapping("tarea")
    public ResponseEntity<?> create(@RequestBody TareaDto tareaDto, @AuthenticationPrincipal UserDetails userDetails) {
        String supervisorEmail = userDetails.getUsername();
        Usuario supervisor = usuarioService.findByEmail(supervisorEmail).orElseThrow(() -> new IllegalStateException("Supervisor not found"));

        Tarea tareaSave = null;
        try {
            tareaDto.setSupervisorId(supervisor.getId());
            tareaDto.setAssignedAt(Instant.now());
            tareaSave = tareaService.save(tareaDto);
            return new ResponseEntity<>(
                    MessageResponse.builder()
                            .objecto(TareaDto.builder()
                                    .id(tareaSave.getId())
                                    .reportId(tareaSave.getReport().getId())
                                    .workerId(tareaSave.getWorker().getId())
                                    .supervisorId(tareaSave.getSupervisor().getId())
                                    .description(tareaSave.getDescription())
                                    .type(tareaSave.getType())
                                    .location(Location.builder()
                                            .lat(tareaSave.getLat())
                                            .lng(tareaSave.getLng())
                                            .address(tareaSave.getAddress())
                                            .build())
                                    .status(tareaSave.getStatus())
                                    .build())
                            .build()
                    , HttpStatus.CREATED);
        }
        catch (DataAccessException e) {
            return new ResponseEntity<>(
                    MessageResponse.builder()
                            .mensaje("Error al insertar el reporte: " + e.getMessage())
                            .build()
                    , HttpStatus.METHOD_NOT_ALLOWED);
        }
    }

    @PutMapping("tarea/{id}")
    public ResponseEntity<?> update(@RequestBody TareaDto tareaDto, @PathVariable Long id) {
        Tarea tareaUpdate = null;
        try {
            if (tareaService.existsById(id)) {
                tareaDto.setId(id);
                tareaDto.setCompletedAt(Instant.now());
                tareaDto.setStatus(Status.RESUELTO);
                tareaUpdate = tareaService.save(tareaDto);
                return new ResponseEntity<>(
                        MessageResponse.builder()
                                .objecto(TareaDto.builder()
                                        .id(tareaUpdate.getId())
                                        .status(tareaUpdate.getStatus())
                                        .completedAt(tareaUpdate.getCompletedAt())
                                        .build())
                                .build()
                        , HttpStatus.CREATED);
            }
            return new ResponseEntity<>(
                    MessageResponse.builder()
                            .mensaje("La tarea con ID " + id + " no existe.")
                            .build()
                    , HttpStatus.NOT_FOUND);
        }
        catch (DataAccessException e) {
            return new ResponseEntity<>(
                    MessageResponse.builder()
                            .mensaje("Error al actualizar la tarea: " + e.getMessage())
                            .build()
                    , HttpStatus.METHOD_NOT_ALLOWED);
        }
    }

    @PatchMapping("tarea/{id}/completar")
    public ResponseEntity<?> completarTarea(@PathVariable Long id, @RequestBody CompletarTareaRequest request) {
        try {
            // Llama a un nuevo método de servicio dedicado
            TareaDto tareaActualizada = tareaService.completeTask(id, request.notes(), request.evidences());
            return ResponseEntity.ok(tareaActualizada);

        } catch (IllegalStateException e) {
            return new ResponseEntity<>(
                    MessageResponse.builder().mensaje(e.getMessage()).build(),
                    HttpStatus.NOT_FOUND);
        } catch (DataAccessException e) {
            return new ResponseEntity<>(
                    MessageResponse.builder().mensaje("Error al actualizar la tarea: " + e.getMessage()).build(),
                    HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

//    @GetMapping("/tareas")
//    public ResponseEntity<?> showAll() {
//        List<Tarea> tareas = tareaService.findAll();
//        List<TareaDto> dtos = tareas.stream().map(tarea ->
//                TareaDto.builder()
//                        .id(tarea.getId())
//                        .reportId(tarea.getReportId())
//                        .workerId(tarea.getWorkerId())
//                        .supervisorId(tarea.getSupervisorId())
//                        .title(tarea.getTitle())
//                        .description(tarea.getDescription())
//                        .notes(tarea.getNotes())
//                        .type(tarea.getType())
//                        .location(
//                                Location.builder()
//                                        .lat(tarea.getLat())
//                                        .lng(tarea.getLng())
//                                        .address(tarea.getAddress())
//                                        .build()
//                        )
//                        .status(tarea.getStatus())
//                        .priority(tarea.getPriority())
//                        .build()
//        ).toList();
//
//        return ResponseEntity.ok(dtos);
//    }
//
    @GetMapping("/tareas/me")
    public ResponseEntity<Page<?>> getCurrentWorkerTask(
            @AuthenticationPrincipal UserDetails userDetails, // Spring Security inyecta al usuario autenticado
            @RequestParam(required = false) Status estado,
            Pageable pageable) { // Spring maneja automáticamente los parámetros ?page=0&size=10

        String workerEmail = userDetails.getUsername(); // O el ID, según lo que guardes en el token
        Page<TareaDto> tareas = tareaService.findByWorkerEmail(workerEmail, estado, pageable);

        return ResponseEntity.ok(tareas);
    }

    @PostMapping("/tarea/cargar")
    public ResponseEntity<String> uploadPhoto(@RequestParam("file") MultipartFile file) {
        String simulatedUrl = cloudinaryService.uploadFile(file, "tareas");
        return ResponseEntity.ok(simulatedUrl);
    }
}
