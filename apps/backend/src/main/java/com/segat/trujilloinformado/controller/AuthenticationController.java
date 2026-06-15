package com.segat.trujilloinformado.controller;

import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;
import com.segat.trujilloinformado.service.IAuthenticationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("api/v1/auth")
@RequiredArgsConstructor
public class AuthenticationController {
    private final IAuthenticationService IAuthenticationService;

    @PostMapping("/registro")
    public ResponseEntity<AuthenticationResponse> register(@RequestBody RegisterRequest request) {
        return ResponseEntity.ok(IAuthenticationService.register(request));
    }

    @PostMapping("/autenticar")
    public ResponseEntity<AuthenticationResponse> authenticate(@RequestBody AuthenticationRequest request) {
        return ResponseEntity.ok(IAuthenticationService.authenticate(request));
    }

}
