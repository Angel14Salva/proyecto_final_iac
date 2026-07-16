// src/js/components/statusBadge.js

const STATUS_LABEL = {
    PENDIENTE: 'Pendiente',
    EN_PROGRESO: 'En progreso',
    RESUELTO: 'Resuelto',
};

const TYPE_LABEL = {
    RESIDUOS_SOLIDOS: 'Residuos sólidos',
    MALEZA: 'Maleza',
    BARRIDO: 'Barrido',
};

const PRIORITY_LABEL = {
    BAJA: 'Baja',
    MEDIA: 'Media',
    ALTA: 'Alta',
};

export function statusStampHtml(status) {
    if (!status) return '';
    const cls = status.toLowerCase();
    const label = STATUS_LABEL[status] || status;
    return `<span class="stamp ${cls}">${label}</span>`;
}

export function priorityPillHtml(priority) {
    if (!priority) return '';
    const cls = priority.toLowerCase();
    const label = PRIORITY_LABEL[priority] || priority;
    return `<span class="priority-pill ${cls}">${label}</span>`;
}

export function typeLabel(type) {
    return TYPE_LABEL[type] || type || '—';
}

export function formatDate(instantStr) {
    if (!instantStr) return '—';
    const d = new Date(instantStr);
    if (Number.isNaN(d.getTime())) return '—';
    return d.toLocaleDateString('es-PE', { day: '2-digit', month: 'short', year: 'numeric' }) +
        ' · ' + d.toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' });
}
