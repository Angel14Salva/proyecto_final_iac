package com.segat.trujilloinformado.model.dao;

import com.segat.trujilloinformado.model.entity.Zona;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface ZonaDao extends JpaRepository<Zona, Long> {
    @Query(value = """
        SELECT *
        FROM zonas z
        WHERE ST_Contains(z.boundaries, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326))
        LIMIT 1
        """, nativeQuery = true)
    Optional<Zona> findZonaByLngLat(@Param("lng") double lng, @Param("lat") double lat);

    Optional<Zona> findByNumber(Integer number);
}
