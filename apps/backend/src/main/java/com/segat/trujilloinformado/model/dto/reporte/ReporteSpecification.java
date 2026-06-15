package com.segat.trujilloinformado.model.dto.reporte;

import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.enums.Type;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class ReporteSpecification {

    public static Specification<Reporte> withFilters(
            Integer zoneNumber,
            List<Status> statuses, // Usar Enums es una buena práctica
            List<Type> types,
            LocalDate startDate,
            LocalDate endDate) {

        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();

            // 1. Filtro OBLIGATORIO: Por zona del supervisor
            predicates.add(criteriaBuilder.equal(root.get("zone").get("number"), zoneNumber));

            // 2. Filtro OBLIGATORIO: Reportes no asignados
            // predicates.add(criteriaBuilder.isNull(root.get("assignedTo")));

            // 3. Filtros OPCIONALES: Se añaden solo si no son nulos
            if (statuses != null && !statuses.isEmpty()) {
                predicates.add(root.get("status").in(statuses)); // USA .in() EN LUGAR DE .equal()
            }

            if (types != null && !types.isEmpty()) {
                predicates.add(root.get("type").in(types)); // USA .in() EN LUGAR DE .equal()
            }

            if (startDate != null) {
                // Mayor o igual que el inicio del día de la fecha de inicio
                predicates.add(criteriaBuilder.greaterThanOrEqualTo(root.get("createdAt"), startDate.atStartOfDay()));
            }

            if (endDate != null) {
                // Menor o igual que el final del día de la fecha de fin
                predicates.add(criteriaBuilder.lessThanOrEqualTo(root.get("createdAt"), endDate.atTime(23, 59, 59)));
            }

            // Combina todos los predicados con un AND
            return criteriaBuilder.and(predicates.toArray(new Predicate[0]));
        };
    }
}
