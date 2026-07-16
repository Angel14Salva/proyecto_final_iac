// src/js/utils/api/apiService.js
import { API_BASE_URL } from '../../config.js';
import { getToken, logout } from '../auth/auth.js';

/**
 * Wrapper central de fetch: agrega el header Authorization cuando hay sesión,
 * y si el backend responde 401 (token vencido/inválido) cierra la sesión en
 * vez de dejar que cada página maneje ese caso por su cuenta.
 */
async function request(path, { method = 'GET', body, isFormData = false, auth = true, rawResponse = false } = {}) {
    const headers = {};
    if (!isFormData) headers['Content-Type'] = 'application/json';
    if (auth) {
        const token = getToken();
        if (token) headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${API_BASE_URL}${path}`, {
        method,
        headers,
        body: isFormData ? body : (body !== undefined ? JSON.stringify(body) : undefined),
    });

    if (response.status === 401 && auth) {
        logout();
        throw new Error('Sesión expirada');
    }

    if (!response.ok) {
        let message = `Error HTTP ${response.status}`;
        try {
            const errBody = await response.json();
            message = errBody.mensaje || errBody.message || message;
        } catch (_) { /* body no era JSON */ }
        throw new Error(message);
    }

    if (rawResponse) return response;
    if (response.status === 204) return null;
    return response.json();
}

/* ============================= AUTENTICACIÓN ============================= */

export async function loginUser(email, password) {
    return request('/v1/auth/autenticar', { method: 'POST', body: { email, password }, auth: false });
}

export async function registerCitizen({ firstname, lastname, email, phone, birthdate, password }) {
    return request('/v1/auth/registro', {
        method: 'POST',
        auth: false,
        body: { firstname, lastname, email, phone, birthdate, password },
    });
}

/* ============================= REPORTES (ciudadano) ======================= */

export async function fetchMisReportes(page, size, estado) {
    const params = new URLSearchParams({ page, size });
    if (estado) params.set('estado', estado);
    return request(`/v1/reportes/me?${params.toString()}`);
}

export async function crearReporte({ citizenId, type, description, lat, lng, address, photos }) {
    return request('/v1/reporte', {
        method: 'POST',
        body: {
            citizenId: String(citizenId),
            type,
            description,
            location: { lat, lng, address },
            photos: photos || [],
        },
    });
}

export async function calificarReporte(id, rating, comment) {
    return request(`/v1/reporte/${id}/rate`, { method: 'PATCH', body: { rating, comment } });
}

export async function subirFotoReporte(file) {
    const formData = new FormData();
    formData.append('file', file);
    const response = await request('/v1/reporte/cargar', { method: 'POST', body: formData, isFormData: true, rawResponse: true });
    return response.text();
}

/* ============================= TAREAS (trabajador) ========================= */

export async function fetchMisTareas(page, size, estado) {
    const params = new URLSearchParams({ page, size, sort: 'assignedAt,desc' });
    if (estado) params.set('estado', estado);
    return request(`/v1/tareas/me?${params.toString()}`);
}

export async function completarTarea(id, notes, evidences) {
    return request(`/v1/tarea/${id}/completar`, { method: 'PATCH', body: { notes, evidences: evidences || [] } });
}

export async function subirFotoTarea(file) {
    const formData = new FormData();
    formData.append('file', file);
    const response = await request('/v1/tarea/cargar', { method: 'POST', body: formData, isFormData: true, rawResponse: true });
    return response.text();
}

/* ============================= SUPERVISOR =================================== */

export async function fetchIndicadoresZona({ estados, tipos, fechaInicio, fechaFin } = {}) {
    const params = buildFilterParams({ estados, tipos, fechaInicio, fechaFin });
    return request(`/v1/reportes/supervisor/summary?${params.toString()}`);
}

export async function fetchReportesZona(page, size, { estados, tipos, fechaInicio, fechaFin } = {}) {
    const params = buildFilterParams({ estados, tipos, fechaInicio, fechaFin });
    params.set('page', page);
    params.set('size', size);
    return request(`/v1/reportes/supervisor/me?${params.toString()}`);
}

export async function exportarReportesPdf({ estados, tipos, fechaInicio, fechaFin } = {}) {
    const params = buildFilterParams({ estados, tipos, fechaInicio, fechaFin });
    const response = await request(`/v1/reportes/supervisor/export/pdf?${params.toString()}`, { rawResponse: true });
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'historial_reportes.pdf';
    document.body.appendChild(a);
    a.click();
    a.remove();
    window.URL.revokeObjectURL(url);
}

export async function fetchTrabajadores() {
    return request('/v1/trabajadores');
}

export async function crearTarea({ reportId, workerId, type, description }) {
    return request('/v1/tarea', { method: 'POST', body: { reportId, workerId, type, description } });
}

/* ============================= PERFIL (todos los roles) ==================== */

export async function actualizarPerfil({ phone, password }) {
    const body = {};
    if (phone) body.phone = phone;
    if (password) body.password = password;
    return request('/v1/perfil', { method: 'PATCH', body });
}

/* ============================= helpers ====================================== */

function buildFilterParams({ estados, tipos, fechaInicio, fechaFin }) {
    const params = new URLSearchParams();
    (estados || []).forEach((e) => params.append('estados', e));
    (tipos || []).forEach((t) => params.append('tipos', t));
    if (fechaInicio) params.set('fechaInicio', fechaInicio);
    if (fechaFin) params.set('fechaFin', fechaFin);
    return params;
}
