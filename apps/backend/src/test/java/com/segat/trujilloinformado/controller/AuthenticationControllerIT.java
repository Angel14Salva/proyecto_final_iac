package com.segat.trujilloinformado.controller;

import com.segat.trujilloinformado.integration.AbstractIntegrationTest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthenticationControllerIT extends AbstractIntegrationTest {

    @Test
    void registraUnCiudadanoNuevoYDevuelveTokens() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .firstname("Ana")
                .lastname("Perez")
                .email("ana.perez@example.com")
                .phone("987654321")
                .birthdate("1998-05-10")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/v1/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.role").value("CIUDADANO"));
    }

    @Test
    void rechazaRegistroConEmailYaUsado() throws Exception {
        RegisterRequest request = RegisterRequest.builder()
                .firstname("Luis")
                .lastname("Gomez")
                .email("luis.gomez@example.com")
                .phone("987654321")
                .birthdate("1998-05-10")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/v1/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        // mismo email, segundo intento: AuthenticationServiceImpl.register() lanza
        // IllegalArgumentException; sin @ControllerAdvice que la traduzca, MockMvc
        // no la convierte en una respuesta 500 -- la re-lanza desde perform()
        ServletException ex = assertThrows(ServletException.class, () ->
                mockMvc.perform(post("/api/v1/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request))));
        assertThat(ex.getCause())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Email already in use");
    }

    @Test
    void autenticaConCredencialesValidasYRechazaConInvalidas() throws Exception {
        RegisterRequest registerRequest = RegisterRequest.builder()
                .firstname("Marta")
                .lastname("Diaz")
                .email("marta.diaz@example.com")
                .phone("987654321")
                .birthdate("1995-03-20")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/v1/auth/registro")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(registerRequest)))
                .andExpect(status().isOk());

        AuthenticationRequest validLogin = AuthenticationRequest.builder()
                .email("marta.diaz@example.com")
                .password("Password123")
                .build();

        mockMvc.perform(post("/api/v1/auth/autenticar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validLogin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.role").value("CIUDADANO"));

        AuthenticationRequest wrongPassword = AuthenticationRequest.builder()
                .email("marta.diaz@example.com")
                .password("password-incorrecto")
                .build();

        // AuthenticationManager.authenticate() lanza BadCredentialsException.
        // A diferencia de una IllegalArgumentException comun, esta SI es traducida
        // a una respuesta HTTP real: ExceptionTranslationFilter de Spring Security
        // intercepta cualquier AuthenticationException downstream y, al no haber
        // un AuthenticationEntryPoint configurado, cae al 403 por defecto
        mockMvc.perform(post("/api/v1/auth/autenticar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongPassword)))
                .andExpect(status().isForbidden());
    }
}
