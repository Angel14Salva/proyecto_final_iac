// src/js/components/nav.js
import { getCurrentUser, logout } from '../utils/auth/auth.js';

const ROLE_LABEL = {
    CIUDADANO: 'Ciudadano',
    TRABAJADOR: 'Trabajador de campo',
    SUPERVISOR: 'Supervisor de zona',
};

/**
 * Inyecta la barra de navegación al inicio de <body>.
 * @param {string} activeLabel - texto pequeño junto al logo (ej. "Panel del ciudadano")
 */
export function renderNav(activeLabel) {
    const user = getCurrentUser();
    const nav = document.createElement('div');
    nav.className = 'app-nav';
    nav.innerHTML = `
        <div class="app-nav-inner">
            <a href="#" class="app-brand">Trujillo Informado <small>${activeLabel || ''}</small></a>
            <div class="app-nav-user">
                <div class="who">
                    <div class="name">${user ? user.name : ''}</div>
                    <div class="role">${user ? (ROLE_LABEL[user.role] || user.role) : ''}</div>
                </div>
                <button class="btn btn-secondary btn-sm" id="nav-logout-btn" type="button">Salir</button>
            </div>
        </div>
    `;
    document.body.prepend(nav);
    nav.querySelector('#nav-logout-btn').addEventListener('click', logout);
}
