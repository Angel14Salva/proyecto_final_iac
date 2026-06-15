package com.segat.trujilloinformado.model.entity.enums;

import lombok.Getter;

@Getter
public enum Priority {
    BAJA("Baja"),
    MEDIA("Media"),
    ALTA("Alta");

    private final String descripcion;

    Priority(String descripcion) {
        this.descripcion = descripcion;
    }

}
