package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.ReporteDao;
import com.segat.trujilloinformado.model.dto.ReporteDto;
import com.segat.trujilloinformado.model.dto.reporte.IndicadoresDto;
import com.segat.trujilloinformado.model.dto.reporte.RateReporteDto;
import com.segat.trujilloinformado.model.dto.reporte.ReporteSpecification;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.Zona;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.enums.Type;
import com.segat.trujilloinformado.service.INotificationService;
import com.segat.trujilloinformado.service.IReporteService;
import com.segat.trujilloinformado.service.IUsuarioService;
import com.segat.trujilloinformado.service.IZonaService;
import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
public class ReporteServiceImpl implements IReporteService {
    @Autowired
    private ReporteDao reporteDao;

    @Autowired
    private IUsuarioService usuarioService;

    @Autowired
    private IZonaService zonaService;

    @Autowired
    private INotificationService notificationService;

    @Transactional
    @Override
    public Reporte save(ReporteDto dto) {
        // 1) Validar ciudadano
        Usuario usuario = usuarioService.findById(Long.valueOf(dto.getCitizenId()));
        if (usuario == null) {
            throw new IllegalArgumentException("El ciudadano con ID " + dto.getCitizenId() + " no existe.");
        }

        // 2) Tomar lng/lat (¡en ese orden!)
        double lng = dto.getLocation().getLng();
        double lat = dto.getLocation().getLat();

        // 3) Encontrar zona obligatoria (si no hay, 400)
        Zona zona = zonaService.classifyLocation(lng, lat)
                .orElseThrow(() -> new IllegalArgumentException(
                        "La ubicación (" + lat + ", " + lng + ") no pertenece a ninguna zona definida."));

        // 4) Construir el Point con SRID 4326
        Point point = zonaService.createPoint(lng, lat);

        // 5) Armar la entidad y guardar
        Reporte reporte = Reporte.builder()
                .id(dto.getId())
                .type(dto.getType())
                .description(dto.getDescription())
                .lat(lat)
                .lng(lng)
                .address(dto.getLocation().getAddress())
                .point(point)
                .photos(dto.getPhotos() != null ? String.join(",", dto.getPhotos()) : null)
                .priority(dto.getPriority())
                .zone(zona) // <-- garantizado
                .citizen(usuario)
                .status(dto.getStatus() != null ? dto.getStatus() : Status.PENDIENTE)
                .createdAt(dto.getCreatedAt())
                .updatedAt(dto.getUpdatedAt())
                .assignedAt(dto.getAssignedAt())
                .completedAt(dto.getCompletedAt())
                .build();

        Reporte reporteGuardado = reporteDao.save(reporte);

        try {
            notificationService.sendNewReportNotification(reporteGuardado);
        }
        catch (Exception e) {
            // No relanzar la excepción. La creación del reporte fue exitosa.
            // El servicio de notificación ya maneja sus propios errores.
            // Simplemente loguear que la tarea de notificación no se pudo encolar.
            // log.error("No se pudo encolar la notificación para el reporte {}", reporteGuardado.getId(), e);
        }

        return reporteGuardado;
    }

    @Transactional(readOnly = true)
    @Override
    public Reporte findById(Long id) {
        return reporteDao.findById(id).orElse(null);
    }

    @Override
    public Page<Reporte> findByCitizenEmail(String email, Status estado, Pageable pageable) {

        if (estado != null) {
            return reporteDao.findByCitizenEmailAndStatus(email, estado, pageable);
        }
        else {
            return reporteDao.findByCitizenEmail(email, pageable);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public Page<Reporte> findByZoneNumber(Integer number, Pageable pageable) {
        return reporteDao.findByZoneNumber(number, pageable);
    }

    /**
     * Busca reportes para un supervisor aplicando filtros dinámicos.
     * La lógica de negocio principal está encapsulada en ReporteSpecification.
     */
    @Override
    public Page<Reporte> findSupervisorReportsWithFilters(Integer zoneNumber, List<Status> statuses, List<Type> types, LocalDate startDate, LocalDate endDate, Pageable pageable) {
        Specification<Reporte> spec = ReporteSpecification.withFilters(
                zoneNumber, statuses, types, startDate, endDate
        );

        // El método findAll viene de JpaSpecificationExecutor
        return reporteDao.findAll(spec, pageable);
    }

    @Override
    public List<Reporte> findAllSupervisorReportsWithFilters(Integer zoneNumber, List<Status> statuses, List<Type> types, LocalDate startDate, LocalDate endDate) {
        Specification<Reporte> spec = ReporteSpecification.withFilters(
                zoneNumber, statuses, types, startDate, endDate
        );

        // Usamos findAll con un Sort, pero sin Pageable para traer todos los resultados
        return reporteDao.findAll(spec, Sort.by(Sort.Direction.DESC, "createdAt"));
    }

    @Override
    public IndicadoresDto calculateIndicators(Integer zoneNumber, List<Status> statuses, List<Type> types, LocalDate startDate, LocalDate endDate) {
        // Especificación base (incluye zona, fechas, tipos y estados seleccionados)
        Specification<Reporte> baseSpec = ReporteSpecification.withFilters(
                zoneNumber, statuses, types, startDate, endDate
        );

        // 1. Calcular el total de reportes que coinciden con los filtros
        long totalCount = reporteDao.count(baseSpec);

        // 2. Calcular total de pendientes (añadiendo la condición PENDIENTE a la base)
        Specification<Reporte> pendingSpec = baseSpec.and((root, query, cb) -> cb.equal(root.get("status"), Status.PENDIENTE));
        long pendingCount = reporteDao.count(pendingSpec);

        // 3. Calcular total de resueltos
        Specification<Reporte> resolvedSpec = baseSpec.and((root, query, cb) -> cb.equal(root.get("status"), Status.RESUELTO));
        long resolvedCount = reporteDao.count(resolvedSpec);

        // 4. Calcular totales por tipo (BARRIDO, MALEZA, etc.)
        Map<String, Long> byType = new HashMap<>();
        for (Type typeEnum : Type.values()) {
            Specification<Reporte> typeSpec = baseSpec.and((root, query, cb) -> cb.equal(root.get("type"), typeEnum));
            byType.put(typeEnum.name(), reporteDao.count(typeSpec));
        }

        return IndicadoresDto.builder()
                .total(totalCount)
                .pending(pendingCount)
                .resolved(resolvedCount)
                .byType(byType)
                .build();
    }


    @Override
    public void delete(Reporte reporte) {
        reporteDao.delete(reporte);
    }

    @Override
    public Reporte calificarReporte(Long reporteId, String citizenEmail, RateReporteDto dto) {
        // Buscar reporte y verificar que pertenezca al ciudadano
        Reporte reporte = reporteDao.findById(reporteId)
                .orElseThrow(() -> new IllegalArgumentException("El reporte con ID " + reporteId + " no existe."));

        if (!reporte.getCitizen().getEmail().equals(citizenEmail)) {
            throw new IllegalArgumentException("El reporte no pertenece al ciudadano con email " + citizenEmail + ".");
        }

        // AC #1: Solo si está RESUELTO
        if (reporte.getStatus() != Status.RESUELTO) {
            throw new IllegalStateException("Solo se pueden calificar reportes en estado RESUELTO.");
        }

        // AC #6: No modificar si ya fue calificado (Inmutabilidad)
        if (reporte.getRating() != null) {
            throw new IllegalStateException("Este reporte ya ha sido calificado.");
        }

        // Guardar datos
        reporte.setRating(dto.getRating());
        reporte.setFeedbackComment(dto.getComment());

        return reporteDao.save(reporte);
    }

    @Override
    public boolean existsById(Long id) {
        return reporteDao.existsById(id);
    }

    @Override
    public List<Reporte> findAll() {
        return (List<Reporte>) reporteDao.findAll();
    }

    @Override
    public Page<Reporte> findAll(Pageable pageable) {
        return reporteDao.findAll(pageable);
    }
}
