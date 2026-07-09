package com.segat.trujilloinformado.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.segat.trujilloinformado.integration.AbstractIntegrationTest;
import com.segat.trujilloinformado.model.dto.ReporteDto;
import com.segat.trujilloinformado.model.entity.enums.Priority;
import com.segat.trujilloinformado.model.entity.enums.Type;
import com.segat.trujilloinformado.model.entity.interno.Location;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ReporteControllerIT extends AbstractIntegrationTest {

    @Test
    void unCiudadanoCreaUnReporteYLoConsultaDespues() throws Exception {
        AuthenticatedCitizen citizen = registerCitizen("reportante");
        Location location = interiorLocationForZone(1);

        ReporteDto dto = ReporteDto.builder()
                .type(Type.BARRIDO)
                .description("Acumulacion de basura en la vereda")
                .location(location)
                .priority(Priority.MEDIA)
                .citizenId(String.valueOf(citizen.id()))
                .build();

        MvcResult createResult = mockMvc.perform(post("/api/v1/reporte")
                        .header("Authorization", "Bearer " + citizen.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.objecto.zone").value("Zona 1"))
                .andExpect(jsonPath("$.objecto.citizenEmail").value(citizen.email()))
                .andReturn();

        JsonNode created = objectMapper.readTree(createResult.getResponse().getContentAsString());
        long reporteId = created.get("objecto").get("id").asLong();

        mockMvc.perform(get("/api/v1/reporte/{id}", reporteId)
                        .header("Authorization", "Bearer " + citizen.accessToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.objecto.id").value(reporteId))
                .andExpect(jsonPath("$.objecto.type").value("BARRIDO"));

        MvcResult myReportsResult = mockMvc.perform(get("/api/v1/reportes/me")
                        .header("Authorization", "Bearer " + citizen.accessToken()))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode page = objectMapper.readTree(myReportsResult.getResponse().getContentAsString());
        assertThat(page.get("content")).hasSize(1);
        assertThat(page.get("content").get(0).get("id").asLong()).isEqualTo(reporteId);
    }

    @Test
    void rechazaCrearReporteConUbicacionFueraDeCualquierZona() throws Exception {
        AuthenticatedCitizen citizen = registerCitizen("reportante.fuera");

        ReporteDto dto = ReporteDto.builder()
                .type(Type.MALEZA)
                .description("Ubicacion en pleno oceano, fuera de cualquier zona")
                .location(Location.builder().lat(-8.5).lng(-80.5).address("Fuera de zona").build())
                .priority(Priority.BAJA)
                .citizenId(String.valueOf(citizen.id()))
                .build();

        // ReporteServiceImpl.save() lanza IllegalArgumentException si la ubicacion
        // no cae en ninguna zona; el controller solo atrapa DataAccessException,
        // asi que sin @ControllerAdvice esto termina en 500
        mockMvc.perform(post("/api/v1/reporte")
                        .header("Authorization", "Bearer " + citizen.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().is5xxServerError());
    }

    @Test
    void rechazaCrearReporteSinAutenticacion() throws Exception {
        Location location = interiorLocationForZone(1);
        ReporteDto dto = ReporteDto.builder()
                .type(Type.BARRIDO)
                .description("Sin token")
                .location(location)
                .priority(Priority.BAJA)
                .citizenId("1")
                .build();

        mockMvc.perform(post("/api/v1/reporte")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isForbidden());
    }
}
