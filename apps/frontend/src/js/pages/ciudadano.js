// src/js/pages/ciudadano.js
import { requireSession, getCurrentUser } from '../utils/auth/auth.js';
import { renderNav } from '../components/nav.js';
import { statusStampHtml, priorityPillHtml, typeLabel, formatDate } from '../components/statusBadge.js';
import { toastError, toastSuccess } from '../utils/ui/toast.js';
import { fetchMisReportes, crearReporte, calificarReporte, subirFotoReporte } from '../utils/api/apiService.js';

const user = requireSession(['CIUDADANO']);
if (user) {
    renderNav('Panel del ciudadano');
}

const PAGE_SIZE = 8;
let currentPage = 0; // Spring Data pagea desde 0
let currentEstado = '';
let pendingPhotoUrl = null;

const tableBody = document.getElementById('report-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');
const filterEstado = document.getElementById('filter-estado');

async function loadReports(page = 0) {
    currentPage = page;
    tableBody.innerHTML = `<tr><td colspan="6" class="table-loading">Cargando reportes…</td></tr>`;
    paginationWrapper.innerHTML = '';
    try {
        const data = await fetchMisReportes(page, PAGE_SIZE, currentEstado || undefined);
        renderTable(data.content || []);
        renderPagination(data.totalPages || 0, data.number ?? page);
    } catch (error) {
        tableBody.innerHTML = `<tr><td colspan="6" class="table-error">No se pudieron cargar tus reportes. ${error.message}</td></tr>`;
    }
}

function renderTable(items) {
    if (!items.length) {
        tableBody.innerHTML = `<tr><td colspan="6"><div class="empty-state"><div class="empty-title">Todavía no tienes reportes</div>Usa "Nuevo reporte" para registrar tu primera incidencia.</div></td></tr>`;
        return;
    }
    tableBody.innerHTML = items.map((r) => `
        <tr>
            <td>${formatDate(r.createdAt)}</td>
            <td>${typeLabel(r.type)}</td>
            <td>${r.zone || '—'}</td>
            <td>${statusStampHtml(r.status)}</td>
            <td>${priorityPillHtml(r.priority)}</td>
            <td>${ratingCellHtml(r)}</td>
        </tr>
    `).join('');

    tableBody.querySelectorAll('[data-rate]').forEach((btn) => {
        btn.addEventListener('click', async () => {
            const id = btn.dataset.rate;
            const rating = Number(btn.dataset.value);
            try {
                await calificarReporte(id, rating);
                toastSuccess('Gracias por tu calificación');
                loadReports(currentPage);
            } catch (error) {
                toastError(error.message);
            }
        });
    });
}

function ratingCellHtml(r) {
    if (r.status !== 'RESUELTO') return '<span class="text-muted">—</span>';
    if (r.rating) return '★'.repeat(r.rating) + '☆'.repeat(5 - r.rating);
    let stars = '<div class="rating-stars">';
    for (let i = 1; i <= 5; i++) {
        stars += `<button type="button" data-rate="${r.id}" data-value="${i}" title="Calificar ${i}">★</button>`;
    }
    stars += '</div>';
    return stars;
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

filterEstado.addEventListener('change', () => {
    currentEstado = filterEstado.value;
    loadReports(0);
});

/* ---------------- Modal nuevo reporte ---------------- */

const modal = document.getElementById('new-report-modal');
const openBtn = document.getElementById('new-report-btn');
const closeBtn = document.getElementById('close-modal-btn');
const form = document.getElementById('new-report-form');
const formError = document.getElementById('report-form-error');
const useLocationBtn = document.getElementById('use-location-btn');
const locationStatus = document.getElementById('location-status');
const latInput = document.getElementById('report-lat');
const lngInput = document.getElementById('report-lng');
const photoInput = document.getElementById('report-photo');
const photoPreview = document.getElementById('photo-preview');
const submitBtn = document.getElementById('submit-report-btn');

openBtn.addEventListener('click', () => { modal.style.display = 'flex'; });
closeBtn.addEventListener('click', () => { modal.style.display = 'none'; resetForm(); });
modal.addEventListener('click', (e) => { if (e.target === modal) { modal.style.display = 'none'; resetForm(); } });

useLocationBtn.addEventListener('click', () => {
    if (!navigator.geolocation) {
        locationStatus.textContent = 'Tu navegador no soporta geolocalización. Ingresa las coordenadas manualmente.';
        return;
    }
    locationStatus.textContent = 'Obteniendo ubicación…';
    navigator.geolocation.getCurrentPosition(
        (pos) => {
            latInput.value = pos.coords.latitude.toFixed(6);
            lngInput.value = pos.coords.longitude.toFixed(6);
            locationStatus.textContent = 'Ubicación capturada. Puedes ajustarla manualmente si no es exacta.';
        },
        () => { locationStatus.textContent = 'No se pudo obtener tu ubicación. Ingresa las coordenadas manualmente.'; }
    );
});

photoInput.addEventListener('change', async () => {
    const file = photoInput.files[0];
    if (!file) return;
    photoPreview.innerHTML = 'Subiendo foto…';
    try {
        pendingPhotoUrl = await subirFotoReporte(file);
        photoPreview.innerHTML = `<img src="${pendingPhotoUrl}" alt="Foto del reporte">`;
    } catch (error) {
        photoPreview.innerHTML = '';
        toastError('No se pudo subir la foto: ' + error.message);
    }
});

form.addEventListener('submit', async (e) => {
    e.preventDefault();
    formError.classList.remove('visible');

    const lat = parseFloat(latInput.value);
    const lng = parseFloat(lngInput.value);
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
        formError.textContent = 'Ingresa una latitud y longitud válidas, o usa el botón de ubicación.';
        formError.classList.add('visible');
        return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'Enviando…';

    try {
        await crearReporte({
            citizenId: user.id,
            type: document.getElementById('report-type').value,
            description: document.getElementById('report-description').value.trim(),
            lat,
            lng,
            address: document.getElementById('report-address').value.trim(),
            photos: pendingPhotoUrl ? [pendingPhotoUrl] : [],
        });
        toastSuccess('Reporte enviado correctamente');
        modal.style.display = 'none';
        resetForm();
        loadReports(0);
    } catch (error) {
        formError.textContent = error.message.includes('ninguna zona')
            ? 'Esa ubicación no pertenece a ninguna zona registrada. Verifica que estés dentro de Trujillo.'
            : error.message;
        formError.classList.add('visible');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Enviar reporte';
    }
});

function resetForm() {
    form.reset();
    pendingPhotoUrl = null;
    locationStatus.textContent = '';
    photoPreview.innerHTML = '';
    formError.classList.remove('visible');
}

if (user) loadReports(0);
