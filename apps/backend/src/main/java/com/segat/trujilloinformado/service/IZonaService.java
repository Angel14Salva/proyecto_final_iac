package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.entity.Zona;
import org.locationtech.jts.geom.Point;

import java.util.Optional;

public interface IZonaService {
    Optional<Zona> classifyLocation(Double lng, Double lat);
    Point createPoint(Double lng, Double lat);
    Optional<Zona>  findByNumber(Integer number);
}
