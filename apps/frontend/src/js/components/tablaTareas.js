// src/js/components/tablaTareas.js

// Las funciones de renderLoading y renderError se pueden reutilizar o hacer genéricas
// pero para mantener la claridad, las duplicamos aquí. renderPagination es idéntica.

export function renderLoading(tableBody, paginationWrapper) {
    tableBody.innerHTML = `<tr><td colspan="4">Cargando tareas...</td></tr>`;
    paginationWrapper.innerHTML = "";
}

export function renderError(tableBody) {
    tableBody.innerHTML = `<tr><td colspan="4">No se pudieron cargar las tareas.</td></tr>`;
}

export function renderTable(tableBody, items) {
    tableBody.innerHTML = "";
    // Criterio de Aceptación: Si no hay tareas...
    if (items.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="4">No tienes tareas pendientes.</td></tr>`;
        return;
    }
    // Criterio de Aceptación: Mostrar los campos requeridos
    items.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${item.tipo}</td>
            <td>${item.ubicacion}</td>
            <td>${item.fotoReferencia}</td>
            <td>${item.fechaAsignacion}</td>
        `;
        tableBody.appendChild(row);
    });
}

export function renderPagination(paginationWrapper, totalPages, currentPage, onPageClick) {
    paginationWrapper.innerHTML = "";
    for (let i = 1; i <= totalPages; i++) {
        const button = document.createElement('a');
        button.href = "#";
        button.innerText = i;
        button.classList.add('page-number');
        if (currentPage === i) {
            button.classList.add('active');
        }
        button.addEventListener('click', (event) => {
            event.preventDefault();
            onPageClick(i);
        });
        paginationWrapper.appendChild(button);
    }
}