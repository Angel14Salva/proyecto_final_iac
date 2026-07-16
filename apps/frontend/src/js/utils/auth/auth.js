// src/js/utils/auth/auth.js
//
// Antes de este archivo, `apiService.js` llamaba a `getToken()` sin definirla
// en ningún lado, y `listarTareas.js` importaba este mismo archivo cuando
// todavía no existía. Ambas cosas rompían esas páginas en tiempo de
// ejecución. Este módulo es la implementación real que faltaba.

const ACCESS_TOKEN_KEY = 'segat_access_token';
const REFRESH_TOKEN_KEY = 'segat_refresh_token';
const ROLE_KEY = 'segat_role';

/** Decodifica el payload de un JWT (sin verificar firma; eso es trabajo del backend). */
function decodeJwtPayload(token) {
    try {
        const base64 = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
        const json = decodeURIComponent(
            atob(base64)
                .split('')
                .map((c) => '%' + c.charCodeAt(0).toString(16).padStart(2, '0'))
                .join('')
        );
        return JSON.parse(json);
    } catch (e) {
        return null;
    }
}

/**
 * Guarda la sesión a partir de la respuesta de /auth/autenticar o /auth/registro,
 * que tiene la forma { accessToken, refreshToken, role }.
 */
export function saveSession(authResponse) {
    localStorage.setItem(ACCESS_TOKEN_KEY, authResponse.accessToken);
    localStorage.setItem(REFRESH_TOKEN_KEY, authResponse.refreshToken);
    localStorage.setItem(ROLE_KEY, authResponse.role);
}

export function getToken() {
    return localStorage.getItem(ACCESS_TOKEN_KEY);
}

export function getRefreshToken() {
    return localStorage.getItem(REFRESH_TOKEN_KEY);
}

export function getRole() {
    return localStorage.getItem(ROLE_KEY);
}

/** El backend mete id/name/phone como claims dentro del access token (ver JwtService). */
export function getCurrentUser() {
    const token = getToken();
    if (!token) return null;
    const payload = decodeJwtPayload(token);
    if (!payload) return null;
    return {
        id: payload.id,
        name: payload.name,
        phone: payload.phone,
        role: getRole(),
        email: payload.sub,
    };
}

export function isAuthenticated() {
    const token = getToken();
    if (!token) return false;
    const payload = decodeJwtPayload(token);
    if (!payload || !payload.exp) return false;
    return payload.exp * 1000 > Date.now();
}

export function logout() {
    localStorage.removeItem(ACCESS_TOKEN_KEY);
    localStorage.removeItem(REFRESH_TOKEN_KEY);
    localStorage.removeItem(ROLE_KEY);
    window.location.href = '/index.html';
}

/**
 * Guardia de ruta: exige sesión activa y, opcionalmente, uno de los roles
 * permitidos para esta página. Redirige si no se cumple.
 * Llamar al inicio de cada página protegida.
 */
export function requireSession(allowedRoles) {
    if (!isAuthenticated()) {
        window.location.href = '/index.html';
        return null;
    }
    const user = getCurrentUser();
    if (allowedRoles && allowedRoles.length > 0 && !allowedRoles.includes(user.role)) {
        window.location.href = homeForRole(user.role);
        return null;
    }
    return user;
}

/** A qué dashboard pertenece cada rol. */
export function homeForRole(role) {
    switch (role) {
        case 'CIUDADANO': return '/pages/ciudadano.html';
        case 'TRABAJADOR': return '/pages/trabajador.html';
        case 'SUPERVISOR': return '/pages/supervisor.html';
        default: return '/index.html';
    }
}
