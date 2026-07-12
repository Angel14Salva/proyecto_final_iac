import { fetchReportes } from '../utils/api/apiService.js';
import { renderLoading, renderError, renderTable, renderPagination } from '../components/reportesView.js';

const FILAS_POR_PAGINA = 5;
let paginaActual = 1;

const tableBody = document.getElementById('report-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');

async function cargarYMostrarReportes(page) {
    paginaActual = page;
    renderLoading(tableBody, paginationWrapper);
    try {
        const data = await fetchReportes(page, FILAS_POR_PAGINA);
        renderTable(tableBody, data.content);
        renderPagination(paginationWrapper, data.totalPages, data.currentPage, cargarYMostrarReportes);
    } catch (error) {
        renderError(tableBody);
    }
}

function init() {
    document.addEventListener('DOMContentLoaded', () => {
        if(tableBody) {
            cargarYMostrarReportes(paginaActual);
        }
    });
}

init();