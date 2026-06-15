package com.segat.trujilloinformado.model.entity;

import com.segat.trujilloinformado.model.entity.enums.Priority;
import com.segat.trujilloinformado.model.entity.enums.Status;
import com.segat.trujilloinformado.model.entity.enums.Type;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.locationtech.jts.geom.Point;

import java.time.Instant;

@Entity
@Table(name = "reportes")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Reporte {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "citizen_id", nullable = false)
    private Usuario citizen; // Ciudadano que reporta

    @Column(nullable = false)
    private Type type;

    private String description;

    private double lat;
    private double lng;
    private String address;

    @Column(columnDefinition = "geometry(Point,4326)")
    private Point point;

    @Column(columnDefinition = "TEXT") // Almacenar URLs separadas por comas
    private String photos;

    @Column(columnDefinition = "TEXT")
    private String evidence;

    private Status status;
    private Priority priority;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "zone_id")
    private Zona zone;

    @Column(nullable = true)
    private Integer rating; // 1, 2, 3, 4, 5

    @Column(length = 500, nullable = true)
    private String feedbackComment;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_to")
    private Usuario assignedTo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_by")
    private Usuario assignedBy;

    private Instant assignedAt;
    private Instant completedAt;

    @CreationTimestamp
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;
}


