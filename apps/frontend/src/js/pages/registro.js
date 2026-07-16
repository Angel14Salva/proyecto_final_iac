// src/js/pages/registro.js
import { registerCitizen } from '../utils/api/apiService.js';
import { saveSession, homeForRole } from '../utils/auth/auth.js';

const form = document.getElementById('register-form');
const errorMessage = document.getElementById('error-message');
const submitBtn = document.getElementById('register-submit');

form.addEventListener('submit', async (event) => {
    event.preventDefault();
    errorMessage.classList.remove('visible');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Creando cuenta…';

    const f = event.target;
    try {
        const authResponse = await registerCitizen({
            firstname: f.firstname.value.trim(),
            lastname: f.lastname.value.trim(),
            email: f.email.value.trim(),
            phone: f.phone.value.trim(),
            birthdate: f.birthdate.value,
            password: f.password.value,
        });
        saveSession(authResponse);
        window.location.href = homeForRole(authResponse.role);
    } catch (error) {
        errorMessage.textContent = error.message || 'No se pudo crear la cuenta. Verifica los datos.';
        errorMessage.classList.add('visible');
        submitBtn.disabled = false;
        submitBtn.textContent = 'Crear cuenta';
    }
});
