// src/js/utils/ui/toast.js

let wrap;

function ensureWrap() {
    if (!wrap) {
        wrap = document.createElement('div');
        wrap.className = 'toast-wrap';
        document.body.appendChild(wrap);
    }
    return wrap;
}

export function toast(message, type = 'default', durationMs = 3800) {
    const container = ensureWrap();
    const el = document.createElement('div');
    el.className = `toast${type !== 'default' ? ' ' + type : ''}`;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(() => el.remove(), durationMs);
}

export const toastSuccess = (msg) => toast(msg, 'success');
export const toastError = (msg) => toast(msg, 'error');
