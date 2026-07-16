// src/js/index.js
import { loginUser } from './utils/api/apiService.js';
import { saveSession, homeForRole, isAuthenticated, getRole } from './utils/auth/auth.js';

function init() {
    // Si ya hay una sesión activa, no tiene sentido mostrar el login de nuevo.
    if (isAuthenticated()) {
        window.location.href = homeForRole(getRole());
        return;
    }

    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');
    const submitBtn = document.getElementById('login-submit');

    if (!loginForm) return;

    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        errorMessage.classList.remove('visible');
        errorMessage.textContent = '';
        submitBtn.disabled = true;
        submitBtn.textContent = 'Ingresando…';

        const email = event.target.email.value.trim();
        const password = event.target.password.value;

        try {
            const authResponse = await loginUser(email, password);
            saveSession(authResponse);
            window.location.href = homeForRole(authResponse.role);
        } catch (error) {
            errorMessage.textContent = 'Correo o contraseña incorrectos.';
            errorMessage.classList.add('visible');
            submitBtn.disabled = false;
            submitBtn.textContent = 'Acceder';
        }
    });
}

document.addEventListener('DOMContentLoaded', init);
