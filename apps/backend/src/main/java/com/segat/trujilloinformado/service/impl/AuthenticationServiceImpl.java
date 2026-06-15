package com.segat.trujilloinformado.service.impl;

import com.segat.trujilloinformado.model.dao.UsuarioDao;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import com.segat.trujilloinformado.model.entity.Usuario;
import com.segat.trujilloinformado.model.entity.enums.Role;
import com.segat.trujilloinformado.service.IAuthenticationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AuthenticationServiceImpl implements IAuthenticationService {

    private final UsuarioDao usuarioDao;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    @Override
    public AuthenticationResponse register(RegisterRequest registerRequest) {

        if (usuarioDao.findByEmail(registerRequest.getEmail()).isPresent()) throw new IllegalArgumentException("Email already in use");

        Usuario user = Usuario.builder()
                .firstname(registerRequest.getFirstname())
                .lastname(registerRequest.getLastname())
                .email(registerRequest.getEmail())
                .phone(registerRequest.getPhone())
                .birthDate(LocalDate.parse(registerRequest.getBirthdate()))
                .password(passwordEncoder.encode(registerRequest.getPassword()))
                .role(Role.CIUDADANO)
                .build();


        usuarioDao.save(user);

        String accessToken = jwtService.generateToken(user, new HashMap<>());
        String refreshToken = jwtService.generateRefreshToken(user, new HashMap<>());

        return AuthenticationResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .role(user.getRole().name())
                .build();
    }

    @Override
    public AuthenticationResponse authenticate(AuthenticationRequest request) {

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        request.getEmail(),
                        request.getPassword()
                )
        );

        Usuario user = usuarioDao.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Map<String, Object> claims = new HashMap<>();
        claims.put("id", user.getId());
        claims.put("name", user.getFirstname() + " " + user.getLastname());
        claims.put("phone", user.getPhone());

        String accessToken = jwtService.generateToken(user, claims);
        String refreshToken = jwtService.generateRefreshToken(user, claims);

        return AuthenticationResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .role(user.getRole().name())
                .build();
    }
}
