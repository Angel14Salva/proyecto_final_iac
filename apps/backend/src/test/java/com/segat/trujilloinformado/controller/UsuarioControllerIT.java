package com.segat.trujilloinformado.controller;

import com.segat.trujilloinformado.integration.AbstractIntegrationTest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.dto.usuario.UpdateProfileRequest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Usa las cuentas que DataSeeder crea en cada arranque, todas en la Zona 1:
 * supervisorzona1@gmail.com (SUPERVISOR) y colaboradorzona1-1..5@gmail.com (TRABAJADOR).
 */
class UsuarioControllerIT extends AbstractIntegrationTest {

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
    void supervisorListaLosTrabajadoresDeSuZona() throws Exception {
        String supervisorToken = login("supervisorzona1@gmail.com", "supervisorzona1");

        mockMvc.perform(get("/api/v1/trabajadores")
                        .header("Authorization", "Bearer " + supervisorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(5));
    }

    @Test
    void soloUnTrabajadorPuedeActualizarSuNombre() throws Exception {
        String supervisorToken = login("supervisorzona1@gmail.com", "supervisorzona1");

        UpdateProfileRequest request = UpdateProfileRequest.builder()
                .name("Nuevo Nombre")
                .build();

        // UsuarioServiceImpl.updateProfile() rechaza el cambio de nombre si el rol no es TRABAJADOR
        mockMvc.perform(patch("/api/v1/perfil")
                        .header("Authorization", "Bearer " + supervisorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unTrabajadorActualizaSuTelefono() throws Exception {
        String workerToken = login("colaboradorzona1-2@gmail.com", "colaboradorzona1-2");

        UpdateProfileRequest request = UpdateProfileRequest.builder()
                .phone("912345678")
                .build();

        mockMvc.perform(patch("/api/v1/perfil")
                        .header("Authorization", "Bearer " + workerToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phone").value("912345678"))
                .andExpect(jsonPath("$.email").value("colaboradorzona1-2@gmail.com"));

        assertThat(usuarioDao.findByEmail("colaboradorzona1-2@gmail.com").orElseThrow().getPhone())
                .isEqualTo("912345678");
    }
}
