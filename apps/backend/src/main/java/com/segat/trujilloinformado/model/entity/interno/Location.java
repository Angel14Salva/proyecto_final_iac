package com.segat.trujilloinformado.model.entity.interno;

import lombok.*;

@Builder
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Location {
    private double lat;
    private double lng;
    private String address;
}
