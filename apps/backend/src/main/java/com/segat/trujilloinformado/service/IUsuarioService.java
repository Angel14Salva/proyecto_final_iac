package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import com.segat.trujilloinformado.model.dto.usuario.UpdateProfileRequest;
import com.segat.trujilloinformado.model.entity.Usuario;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface IUsuarioService {
    Usuario save(RegisterRequest registerRequest);
    Usuario findById(Long id);
    List<Usuario> findAll();
    List<Usuario> findTrabajadoresByZoneNumber(Integer number);
    Optional<Usuario> findByZoneNumber(Integer number);
    Optional<Usuario> findByEmail(String email);
    Optional<Usuario> findByEmailWithZone(String email);
    Usuario updateProfile(String email, UpdateProfileRequest request);
    Boolean existsByEmail(String email);
    void deleteById(Long id);
}
