package com.segat.trujilloinformado.model.entity.enums;

import lombok.Getter;

@Getter
public enum Status {
    PENDIENTE("Pendiente"),
    EN_PROGRESO("En Progreso"),
    RESUELTO("Resuelto");

    private final String descripcion;

    Status(String descripcion) {
        this.descripcion = descripcion;
    }

}
