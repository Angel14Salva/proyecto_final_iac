// src/js/pages/listarTareas.js
import { isAuthenticated } from '../utils/auth/auth.js';
import { fetchTareasAsignadas } from '../utils/api/apiService.js';
import { renderLoading, renderError, renderTable, renderPagination } from '../components/tablaTareas.js';

// --- GUARDIA DE RUTA ---
// Protegemos la página para que solo usuarios logueados puedan verla
if (!isAuthenticated()) {
    // Si no hay token, lo redirigimos a la página de login
    window.location.href = '../../../index.html';
}

// --- LÓGICA DE LA PÁGINA ---
const TAREAS_POR_PAGINA = 10;
let paginaActual = 1;

// Obtenemos los elementos del DOM de esta página
const tableBody = document.getElementById('tasks-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');
const refreshButton = document.getElementById('refresh-btn');

async function cargarYMostrarTareas(page) {
    paginaActual = page;
    renderLoading(tableBody, paginationWrapper);
    try {
        const data = await fetchTareasAsignadas(page, TAREAS_POR_PAGINA);
        renderTable(tableBody, data.content);
        renderPagination(paginationWrapper, data.totalPages, data.currentPage, cargarYMostrarTareas);
    } catch (error) {
        console.error("Error al cargar tareas:", error);
        renderError(tableBody);
    }
}

// --- EVENT LISTENERS E INICIALIZACIÓN ---
document.addEventListener('DOMContentLoaded', () => {
    // Carga inicial de tareas
    cargarYMostrarTareas(paginaActual);

    // Criterio de Aceptación: Poder actualizar la vista
    refreshButton.addEventListener('click', () => {
        cargarYMostrarTareas(paginaActual);
    });
});