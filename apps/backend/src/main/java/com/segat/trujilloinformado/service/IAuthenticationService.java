package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.dto.authentication.AuthenticationRequest;
import com.segat.trujilloinformado.model.dto.authentication.AuthenticationResponse;
import com.segat.trujilloinformado.model.dto.authentication.RegisterRequest;

public interface IAuthenticationService {

    public AuthenticationResponse register(RegisterRequest registerRequest);
    public AuthenticationResponse authenticate(AuthenticationRequest request);
}
