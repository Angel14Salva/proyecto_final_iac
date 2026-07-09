package com.segat.trujilloinformado.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.segat.trujilloinformado.integration.AbstractIntegrationTest;
import com.segat.trujilloinformado.model.dto.ReporteDto;
import com.segat.trujilloinformado.model.dto.TareaDto;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.entity.enums.Priority;
import com.segat.trujilloinformado.model.entity.enums.Type;
import com.segat.trujilloinformado.model.entity.interno.Location;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Usa las cuentas que DataSeeder crea en cada arranque: supervisorzona1@gmail.com
 * y colaboradorzona1-1@gmail.com, ambas atadas a la Zona 1.
 */
class TareaControllerIT extends AbstractIntegrationTest {

    private static final String SUPERVISOR_EMAIL = "supervisorzona1@gmail.com";
    private static final String SUPERVISOR_PASSWORD = "supervisorzona1";
    private static final String WORKER_EMAIL = "colaboradorzona1-1@gmail.com";
    private static final String WORKER_PASSWORD = "colaboradorzona1-1";

    private String login(String email, String password) throws Exception {
        AuthenticationRequest request = AuthenticationRequest.builder()
                .email(email)
                .password(password)
                .build();

        MvcResult result = mockMvc.perform(post("/api/v1/auth/autenticar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), AuthenticationResponse.class)
                .getAccessToken();
    }

    @Test
    void supervisorAsignaTareaYElTrabajadorLaVeYLaCompleta() throws Exception {
        AuthenticatedCitizen citizen = registerCitizen("vecino.tarea");
        Location location = interiorLocationForZone(1);

        ReporteDto reporteDto = ReporteDto.builder()
                .type(Type.MALEZA)
                .description("Maleza crecida en el parque")
                .location(location)
                .priority(Priority.ALTA)
                .citizenId(String.valueOf(citizen.id()))
                .build();

        MvcResult reporteResult = mockMvc.perform(post("/api/v1/reporte")
                        .header("Authorization", "Bearer " + citizen.accessToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(reporteDto)))
                .andExpect(status().isCreated())
                .andReturn();
        long reporteId = objectMapper.readTree(reporteResult.getResponse().getContentAsString())
                .get("objecto").get("id").asLong();

        String supervisorToken = login(SUPERVISOR_EMAIL, SUPERVISOR_PASSWORD);
        Long workerId = usuarioDao.findByEmail(WORKER_EMAIL).orElseThrow().getId();

        TareaDto tareaDto = TareaDto.builder()
                .reportId(reporteId)
                .workerId(workerId)
                .description("Cortar la maleza del parque")
                .type(Type.MALEZA)
                .build();

        MvcResult tareaResult = mockMvc.perform(post("/api/v1/tarea")
                        .header("Authorization", "Bearer " + supervisorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(tareaDto)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.objecto.workerId").value(workerId))
                .andReturn();
        long tareaId = objectMapper.readTree(tareaResult.getResponse().getContentAsString())
                .get("objecto").get("id").asLong();

        String workerToken = login(WORKER_EMAIL, WORKER_PASSWORD);

        MvcResult myTasksResult = mockMvc.perform(get("/api/v1/tareas/me")
                        .header("Authorization", "Bearer " + workerToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode page = objectMapper.readTree(myTasksResult.getResponse().getContentAsString());
        assertThat(page.get("content")).hasSize(1);
        assertThat(page.get("content").get(0).get("id").asLong()).isEqualTo(tareaId);

        mockMvc.perform(patch("/api/v1/tarea/{id}/completar", tareaId)
                        .header("Authorization", "Bearer " + workerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "notes", "Trabajo terminado",
                                "evidences", java.util.List.of("http://example.com/foto.jpg")
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESUELTO"));
    }
}
