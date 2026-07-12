// src/js/index.js
import { loginUser } from './utils/api/apiService.js';

function init() {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');

    if (loginForm) {
        loginForm.addEventListener('submit', async (event) => {
            event.preventDefault(); // Evita que la página se recargue
            errorMessage.textContent = ''; // Limpia errores previos

            // 1. Obtenemos los valores del formulario
            const email = event.target.email.value;
            const password = event.target.password.value;

            try {
                // 2. Llamamos a la función de la API
                const data = await loginUser(email, password);

                // 3. Si todo sale bien, por ahora solo mostramos el token en la consola
                console.log('Login exitoso. El backend devolvió:', data);
                alert('¡Login exitoso! Revisa la consola (F12) para ver la respuesta.');

                // En el siguiente paso, aquí guardaremos el token y redirigiremos.

            } catch (error) {
                // 4. Si algo sale mal (ej: contraseña incorrecta), mostramos un error
                console.error('Error de login:', error);
                errorMessage.textContent = 'Correo o contraseña incorrectos.';
            }
        });
    }
}

document.addEventListener('DOMContentLoaded', init);