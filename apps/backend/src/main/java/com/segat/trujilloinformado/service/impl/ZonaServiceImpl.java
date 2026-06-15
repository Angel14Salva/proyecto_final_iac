package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.ZonaDao;
import com.segat.trujilloinformado.model.entity.Zona;
import com.segat.trujilloinformado.service.IZonaService;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class ZonaServiceImpl implements IZonaService {
    private static final int SRID_WGS84 = 4326;
    private final GeometryFactory geometryFactory;

    @Autowired
    private ZonaDao zonaDao;

    public ZonaServiceImpl() {
        this.geometryFactory = new GeometryFactory(new PrecisionModel(), SRID_WGS84);
    }

    @Override
    public Optional<Zona> classifyLocation(Double lng, Double lat) {
        return zonaDao.findZonaByLngLat(lng, lat);
    }

    @Override
    public Point createPoint(Double lng, Double lat) {
        Coordinate cord = new Coordinate(lng, lat);
        Point point = geometryFactory.createPoint(cord);
        point.setSRID(SRID_WGS84);
        return point;
    }

    @Override
    public Optional<Zona> findByNumber(Integer number) {
        return zonaDao.findByNumber(number);
    }
}
