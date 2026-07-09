package com.segat.trujilloinformado.integration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.segat.trujilloinformado.model.dao.UsuarioDao;
import com.segat.trujilloinformado.model.dao.ZonaDao;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import com.segat.trujilloinformado.model.entity.Zona;
import com.segat.trujilloinformado.model.entity.interno.Location;
import org.junit.jupiter.api.Tag;
import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Base para pruebas de integración: levanta un Postgres+PostGIS real vía
 * Testcontainers (patrón "singleton container": un solo contenedor para
 * toda la suite, compartido entre subclases) y expone helpers comunes
 * (registro de ciudadanos, ubicación válida dentro de una zona).
 */
@Tag("integration")
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
public abstract class AbstractIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("postgis/postgis:15-3.3").asCompatibleSubstituteFor("postgres")
    );

    @Autowired
    protected MockMvc mockMvc;

    @Autowired
    protected ObjectMapper objectMapper;

    @Autowired
    protected UsuarioDao usuarioDao;

    @Autowired
    protected ZonaDao zonaDao;

    protected record AuthenticatedCitizen(Long id, String email, String accessToken) {
    }

    /**
     * Registra un ciudadano nuevo a través del endpoint público de registro
     * y devuelve su id (consultado en BD) junto con el access token emitido.
     */
    protected AuthenticatedCitizen registerCitizen(String emailLocalPart) throws Exception {
        String email = emailLocalPart + "@example.com";
        RegisterRequest request = RegisterRequest.builder()
                .firstname("Test")
                .lastname("Citizen")
                .email(email)
                .phone("999999999")
                .birthdate("2000-01-01")
                .password("Password123")
                .build();

        MvcResult result = mockMvc.perform(post("/api/v1/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andReturn();

        AuthenticationResponse response = objectMapper.readValue(
                result.getResponse().getContentAsString(), AuthenticationResponse.class);
        Long id = usuarioDao.findByEmail(email).orElseThrow().getId();
        return new AuthenticatedCitizen(id, email, response.getAccessToken());
    }

    /**
     * Calcula una ubicación garantizada dentro del polígono de la zona dada,
     * usando Polygon.getInteriorPoint() de JTS en vez de coordenadas fijas
     * (evita depender de la forma exacta del polígono cargado por el seeder).
     */
    protected Location interiorLocationForZone(Integer zoneNumber) {
        Zona zona = zonaDao.findByNumber(zoneNumber).orElseThrow();
        Point interior = zona.getBoundaries().getInteriorPoint();
        return Location.builder()
                .lng(interior.getX())
                .lat(interior.getY())
                .address("Direccion de prueba - " + zona.getName())
                .build();
    }
}
