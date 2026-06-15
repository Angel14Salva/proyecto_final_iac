package com.segat.trujilloinformado.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

@Entity
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NotificationLog {

    @Id
    @GeneratedValue
    private Long id;

    @ManyToOne
    @JoinColumn(name = "reporte_id")
    private Reporte reporte;

    private String recipientPhone;

    @Column(length = 500)
    private String messageContent;

    private String status; // "SENT", "PENDING", "FAILED"

    @CreationTimestamp
    private LocalDateTime createdAt;
}
