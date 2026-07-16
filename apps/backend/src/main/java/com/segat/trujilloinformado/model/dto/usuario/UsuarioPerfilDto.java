package com.segat.trujilloinformado.model.dto.usuario;

import com.segat.trujilloinformado.model.entity.enums.Role;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Respuesta pública del perfil de un usuario: nunca incluye el password ni
 * la entidad Zona completa (que arrastra un Polygon de JTS via lazy-loading
 * y produce JSON con profundidad patológica al serializarse).
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class UsuarioPerfilDto {
    private Long id;
    private String email;
    private String firstname;
    private String lastname;
    private String phone;
    private Role role;
}
