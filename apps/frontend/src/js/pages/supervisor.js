// src/js/pages/supervisor.js
import { requireSession } from '../utils/auth/auth.js';
import { renderNav } from '../components/nav.js';
import { statusStampHtml, priorityPillHtml, typeLabel, formatDate } from '../components/statusBadge.js';
import { toastError, toastSuccess } from '../utils/ui/toast.js';
import {
    fetchIndicadoresZona, fetchReportesZona, exportarReportesPdf,
    fetchTrabajadores, crearTarea,
} from '../utils/api/apiService.js';

const user = requireSession(['SUPERVISOR']);
if (user) renderNav('Panel del supervisor');

const PAGE_SIZE = 8;
let currentPage = 0;
let workersCache = null;

const tableBody = document.getElementById('reports-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');
const statGrid = document.getElementById('stat-grid');

function currentFilters() {
    const estados = Array.from(document.getElementById('f-estados').selectedOptions).map((o) => o.value);
    const tipos = Array.from(document.getElementById('f-tipos').selectedOptions).map((o) => o.value);
    const fechaInicio = document.getElementById('f-inicio').value || undefined;
    const fechaFin = document.getElementById('f-fin').value || undefined;
    return { estados, tipos, fechaInicio, fechaFin };
}

async function loadIndicadores() {
    try {
        const ind = await fetchIndicadoresZona(currentFilters());
        statGrid.innerHTML = `
            <div class="stat-card"><div class="stat-value">${ind.total ?? 0}</div><div class="stat-label">Total</div></div>
            <div class="stat-card accent-ochre"><div class="stat-value">${ind.pending ?? 0}</div><div class="stat-label">Pendientes</div></div>
            <div class="stat-card accent-green"><div class="stat-value">${ind.resolved ?? 0}</div><div class="stat-label">Resueltos</div></div>
        `;
    } catch (error) {
        toastError('No se pudieron cargar los indicadores: ' + error.message);
    }
}

async function loadReports(page = 0) {
    currentPage = page;
    tableBody.innerHTML = `<tr><td colspan="8" class="table-loading">Cargando reportes…</td></tr>`;
    paginationWrapper.innerHTML = '';
    try {
        const data = await fetchReportesZona(page, PAGE_SIZE, currentFilters());
        renderTable(data.content || []);
        renderPagination(data.totalPages || 0, data.number ?? page);
    } catch (error) {
        tableBody.innerHTML = `<tr><td colspan="8" class="table-error">No se pudieron cargar los reportes. ${error.message}</td></tr>`;
    }
}

function renderTable(items) {
    if (!items.length) {
        tableBody.innerHTML = `<tr><td colspan="8"><div class="empty-state"><div class="empty-title">No hay reportes con estos filtros</div>Prueba ampliando el rango de fechas o quitando algún filtro.</div></td></tr>`;
        return;
    }
    tableBody.innerHTML = items.map((r) => `
        <tr>
            <td>${formatDate(r.createdAt)}</td>
            <td>${typeLabel(r.type)}</td>
            <td>${r.citizenName || '—'}</td>
            <td>${(r.location && r.location.address) || '—'}</td>
            <td>${priorityPillHtml(r.priority)}</td>
            <td>${statusStampHtml(r.status)}</td>
            <td>${r.assignedTo || '<span class="text-muted">Sin asignar</span>'}</td>
            <td>${!r.assignedTo ? `<button class="btn btn-secondary btn-sm" data-assign="${r.id}" data-type="${r.type}">Asignar</button>` : ''}</td>
        </tr>
    `).join('');

    tableBody.querySelectorAll('[data-assign]').forEach((btn) => {
        btn.addEventListener('click', () => openAssignModal(btn.dataset.assign, btn.dataset.type));
    });
}

function renderPagination(totalPages, current) {
    paginationWrapper.innerHTML = '';
    for (let i = 0; i < totalPages; i++) {
        const btn = document.createElement('a');
        btn.href = '#';
        btn.textContent = i + 1;
        btn.className = 'page-number' + (i === current ? ' active' : '');
        btn.addEventListener('click', (e) => { e.preventDefault(); loadReports(i); });
        paginationWrapper.appendChild(btn);
    }
}

document.getElementById('apply-filters-btn').addEventListener('click', () => {
    loadIndicadores();
    loadReports(0);
});

document.getElementById('export-pdf-btn').addEventListener('click', async (e) => {
    const btn = e.currentTarget;
    btn.disabled = true;
    btn.textContent = 'Generando…';
    try {
        await exportarReportesPdf(currentFilters());
    } catch (error) {
        toastError('No se pudo exportar el PDF: ' + error.message);
    } finally {
        btn.disabled = false;
        btn.textContent = 'Exportar PDF';
    }
});

/* ---------------- Modal asignar tarea ---------------- */

const modal = document.getElementById('assign-modal');
const closeBtn = document.getElementById('close-assign-modal');
const form = document.getElementById('assign-form');
const formError = document.getElementById('assign-form-error');
const workerSelect = document.getElementById('assign-worker');
const typeSelect = document.getElementById('assign-type');
const reportIdInput = document.getElementById('assign-report-id');
const submitBtn = document.getElementById('assign-submit-btn');

async function openAssignModal(reportId, reportType) {
    reportIdInput.value = reportId;
    if (reportType) typeSelect.value = reportType;
    modal.style.display = 'flex';

    if (!workersCache) {
        workerSelect.innerHTML = '<option>Cargando…</option>';
        try {
            workersCache = await fetchTrabajadores();
            workerSelect.innerHTML = workersCache
                .map((w) => `<option value="${w.id}">${w.name} ${w.lastname}</option>`)
                .join('');
        } catch (error) {
            workerSelect.innerHTML = '';
            toastError('No se pudo cargar la lista de trabajadores: ' + error.message);
        }
    }
}

function closeAssignModal() {
    modal.style.display = 'none';
    form.reset();
    formError.classList.remove('visible');
}

closeBtn.addEventListener('click', closeAssignModal);
modal.addEventListener('click', (e) => { if (e.target === modal) closeAssignModal(); });

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    formError.classList.remove('visible');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Asignando…';
    try {
        await crearTarea({
            reportId: Number(reportIdInput.value),
            workerId: Number(workerSelect.value),
            type: typeSelect.value,
            description: document.getElementById('assign-description').value.trim(),
        });
        toastSuccess('Tarea asignada correctamente');
        closeAssignModal();
        loadReports(currentPage);
    } catch (error) {
        formError.textContent = error.message;
        formError.classList.add('visible');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Asignar';
    }
});

if (user) {
    loadIndicadores();
    loadReports(0);
}
