package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.UsuarioDao;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import com.segat.trujilloinformado.model.dto.usuario.UpdateProfileRequest;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.enums.Role;
import com.segat.trujilloinformado.service.IUsuarioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
public class UsuarioServiceImpl implements IUsuarioService {
    @Autowired
    private UsuarioDao usuarioDao;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Transactional
    @Override
    public Usuario save(RegisterRequest registerRequest) {
        Usuario usuario = Usuario.builder()
                .firstname(registerRequest.getFirstname())
                .lastname(registerRequest.getLastname())
                .email(registerRequest.getEmail())
                .phone(registerRequest.getPhone())
                .birthDate(LocalDate.parse(registerRequest.getBirthdate()))
                .password(registerRequest.getPassword())
                .role(Role.CIUDADANO)
                .build();
        return usuarioDao.save(usuario);
    }

    @Transactional(readOnly = true)
    @Override
    public Usuario findById(Long id) {
        return usuarioDao.findById(id).orElse(null);
    }

    @Override
    public List<Usuario> findAll() {
        return usuarioDao.findAll();
    }

    @Override
    public List<Usuario> findTrabajadoresByZoneNumber(Integer number) {
        return usuarioDao.findTrabajadoresByZoneNumber(number);
    }

    @Override
    public Optional<Usuario> findByZoneNumber(Integer number) {
        return usuarioDao.findByZone_NumberAndRole(number, Role.SUPERVISOR);
    }

    @Transactional(readOnly = true)
    @Override
    public Optional<Usuario> findByEmail(String email) {
        return usuarioDao.findByEmail(email);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Usuario> findByEmailWithZone(String email) {
        return usuarioDao.findByEmailWithZone(email);
    }

    @Override
    public Usuario updateProfile(String email, UpdateProfileRequest request) {
        Usuario usuario = usuarioDao.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("Usuario no encontrado"));

        boolean hasChanges = false;
        Role userRole = usuario.getRole();

        // ============================================
        // ACTUALIZAR NOMBRE Y FUNCION (solo TRABAJADOR)
        // ============================================

        if (request.getName() != null && !request.getName().trim().isEmpty()) {
            if (userRole != Role.TRABAJADOR) {
                throw new IllegalArgumentException("Solo los trabajadores pueden actualizar su nombre");
            }
            usuario.setFirstname(request.getName());
            hasChanges = true;
        }

        // Actualizar apellido y función (solo TRABAJADOR)
        if (request.getLastname() != null && !request.getLastname().trim().isEmpty()) {
            if (userRole != Role.TRABAJADOR) {
                throw new IllegalArgumentException("Solo los trabajadores pueden actualizar su apellido");
            }
            usuario.setLastname(request.getLastname());
            hasChanges = true;
        }

        // Actualizar teléfono si se proporciona
        if (request.getPhone() != null && !request.getPhone().trim().isEmpty()) {
            // Validar formato de teléfono (opcional)
            if (!request.getPhone().matches("\\d{9}")) {
                throw new IllegalArgumentException("El teléfono debe tener 9 dígitos");
            }
            usuario.setPhone(request.getPhone());
            hasChanges = true;
        }

        // Actualizar contraseña si se proporciona
        if (request.getPassword() != null && !request.getPassword().trim().isEmpty()) {
            // Validar contraseña (opcional pero recomendado)
            validatePassword(request.getPassword());

            // Encriptar la nueva contraseña
            usuario.setPassword(passwordEncoder.encode(request.getPassword()));
            hasChanges = true;
        }

        if (!hasChanges) {
            throw new IllegalArgumentException("Debe proporcionar al menos un campo para actualizar");
        }

        return usuarioDao.save(usuario);
    }

    @Override
    public Boolean existsByEmail(String email) {
        return usuarioDao.existsByEmail(email);
    }

    @Override
    public void deleteById(Long id) {
        usuarioDao.deleteById(id);
    }

    // Método auxiliar para validar contraseña
    private void validatePassword(String password) {
        if (password.length() < 8) {
            throw new IllegalArgumentException("La contraseña debe tener al menos 8 caracteres");
        }
        if (!password.matches(".*[A-Z].*")) {
            throw new IllegalArgumentException("La contraseña debe contener al menos una mayúscula");
        }
        if (!password.matches(".*\\d.*")) {
            throw new IllegalArgumentException("La contraseña debe contener al menos un número");
        }
        if (password.matches(".*[^a-zA-Z0-9].*")) {
            throw new IllegalArgumentException("La contraseña no debe contener caracteres especiales");
        }
    }
}
