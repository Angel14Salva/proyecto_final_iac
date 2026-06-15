package com.segat.trujilloinformado.controller;

import com.segat.trujilloinformado.model.dto.TrabajadorDto;
import com.segat.trujilloinformado.model.dto.usuario.UpdateProfileRequest;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.service.IUsuarioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
public class UsuarioController {
    @Autowired
    private IUsuarioService usuarioService;

    @GetMapping("/trabajadores")
    public ResponseEntity<?> getCurrentUserWorkers(@AuthenticationPrincipal UserDetails userDetails) {
        String supervisorEmail = userDetails.getUsername();
        Usuario supervisor = usuarioService.findByEmailWithZone(supervisorEmail)
                .orElseThrow(() -> new IllegalStateException("Supervisor not found"));
        Integer zoneNumber = supervisor.getZone().getNumber();
        List<Usuario> trabajadores = usuarioService.findTrabajadoresByZoneNumber(zoneNumber);
        List<TrabajadorDto> dtos = trabajadores.stream().map(trabajador ->
            TrabajadorDto.builder()
                    .id(trabajador.getId())
                    .name(trabajador.getFirstname())
                    .lastname(trabajador.getLastname())
                    .build()
        ).toList();
        return ResponseEntity.ok(dtos);
    }

    /**
     * Actualiza el perfil del usuario autenticado (teléfono y/o contraseña)
     */
    @PatchMapping("/perfil")
    public ResponseEntity<?> updateProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody UpdateProfileRequest request) {

        String userEmail = userDetails.getUsername();

        try {
            Usuario updatedUser = usuarioService.updateProfile(userEmail, request);
            return ResponseEntity.ok(updatedUser);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.internalServerError()
                    .body("Error al actualizar el perfil");
        }
    }
}
