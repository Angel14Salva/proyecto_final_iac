package com.segat.trujilloinformado.model.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class TrabajadorDto {
    private Long id;
    private String name;
    private String lastname;
}
