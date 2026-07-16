// src/js/pages/trabajador.js
import { requireSession } from '../utils/auth/auth.js';
import { renderNav } from '../components/nav.js';
import { statusStampHtml, typeLabel, formatDate } from '../components/statusBadge.js';
import { toastError, toastSuccess } from '../utils/ui/toast.js';
import { fetchMisTareas, completarTarea, subirFotoTarea } from '../utils/api/apiService.js';

const user = requireSession(['TRABAJADOR']);
if (user) renderNav('Panel del trabajador');

const PAGE_SIZE = 8;
let currentPage = 0;
let currentEstado = '';
let pendingEvidenceUrl = null;

const tableBody = document.getElementById('tasks-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');
const filterEstado = document.getElementById('filter-estado');
const refreshBtn = document.getElementById('refresh-btn');

async function loadTasks(page = 0) {
    currentPage = page;
    tableBody.innerHTML = `<tr><td colspan="6" class="table-loading">Cargando tareas…</td></tr>`;
    paginationWrapper.innerHTML = '';
    try {
        const data = await fetchMisTareas(page, PAGE_SIZE, currentEstado || undefined);
        renderTable(data.content || []);
        renderPagination(data.totalPages || 0, data.number ?? page);
    } catch (error) {
        tableBody.innerHTML = `<tr><td colspan="6" class="table-error">No se pudieron cargar tus tareas. ${error.message}</td></tr>`;
    }
}

function renderTable(items) {
    if (!items.length) {
        tableBody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><div class="empty-title">No tienes tareas por ahora</div>Cuando tu supervisor te asigne una, aparecerá aquí.</div></td></tr>`;
        return;
    }
    tableBody.innerHTML = items.map((t) => {
        const report = t.report || {};
        const photo = (report.photos && report.photos[0]) ? report.photos[0] : null;
        const canComplete = t.status !== 'RESUELTO';
        return `
        <tr>
            <td>${typeLabel(report.type)}</td>
            <td>${(report.location && report.location.address) || '—'}</td>
            <td>${photo ? `<img class="thumb" src="${photo}" alt="Foto de referencia">` : '<span class="text-muted">—</span>'}</td>
            <td>${formatDate(t.assignedAt)}</td>
            <td>${statusStampHtml(t.status)}</td>
            <td>${canComplete ? `<button class="btn btn-secondary btn-sm" data-complete="${t.id}">Completar</button>` : ''}</td>
        </tr>`;
    }).join('');

    tableBody.querySelectorAll('[data-complete]').forEach((btn) => {
        btn.addEventListener('click', () => openCompleteModal(btn.dataset.complete));
    });
}

function renderPagination(totalPages, current) {
    paginationWrapper.innerHTML = '';
    for (let i = 0; i < totalPages; i++) {
        const btn = document.createElement('a');
        btn.href = '#';
        btn.textContent = i + 1;
        btn.className = 'page-number' + (i === current ? ' active' : '');
        btn.addEventListener('click', (e) => { e.preventDefault(); loadTasks(i); });
        paginationWrapper.appendChild(btn);
    }
}

filterEstado.addEventListener('change', () => { currentEstado = filterEstado.value; loadTasks(0); });
refreshBtn.addEventListener('click', () => loadTasks(currentPage));

/* ---------------- Modal completar tarea ---------------- */

const modal = document.getElementById('complete-modal');
const closeBtn = document.getElementById('close-complete-modal');
const form = document.getElementById('complete-form');
const formError = document.getElementById('complete-form-error');
const photoInput = document.getElementById('complete-photo');
const photoPreview = document.getElementById('complete-photo-preview');
const submitBtn = document.getElementById('complete-submit-btn');
const taskIdInput = document.getElementById('complete-task-id');

function openCompleteModal(taskId) {
    taskIdInput.value = taskId;
    modal.style.display = 'flex';
}
function closeCompleteModal() {
    modal.style.display = 'none';
    form.reset();
    pendingEvidenceUrl = null;
    photoPreview.innerHTML = '';
    formError.classList.remove('visible');
}

closeBtn.addEventListener('click', closeCompleteModal);
modal.addEventListener('click', (e) => { if (e.target === modal) closeCompleteModal(); });

photoInput.addEventListener('change', async () => {
    const file = photoInput.files[0];
    if (!file) return;
    photoPreview.innerHTML = 'Subiendo foto…';
    try {
        pendingEvidenceUrl = await subirFotoTarea(file);
        photoPreview.innerHTML = `<img src="${pendingEvidenceUrl}" alt="Evidencia">`;
    } catch (error) {
        photoPreview.innerHTML = '';
        toastError('No se pudo subir la foto: ' + error.message);
    }
});

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    formError.classList.remove('visible');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Guardando…';
    try {
        await completarTarea(
            taskIdInput.value,
            document.getElementById('complete-notes').value.trim(),
            pendingEvidenceUrl ? [pendingEvidenceUrl] : []
        );
        toastSuccess('Tarea marcada como resuelta');
        closeCompleteModal();
        loadTasks(currentPage);
    } catch (error) {
        formError.textContent = error.message;
        formError.classList.add('visible');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Marcar como resuelta';
    }
});

if (user) loadTasks(0);
