package com.segat.trujilloinformado.model.entity.enums;

import lombok.Getter;

@Getter
public enum Type {
    RESIDUOS_SOLIDOS("Residuos Sólidos"),
    MALEZA("Maleza"),
    BARRIDO("Barrido"),;

    private final String descripcion;

    Type(String descripcion) {
        this.descripcion = descripcion;
    }

}
