const tableBody = document.getElementById('report-table-body');
const paginationWrapper = document.getElementById('pagination-wrapper');

export function renderLoading() {
    tableBody.innerHTML = `<tr><td colspan="3">Cargando reportes...</td></tr>`;
    paginationWrapper.innerHTML = "";
}

export function renderError() {
    tableBody.innerHTML = `<tr><td colspan="3">No se pudieron cargar los reportes. Inténtalo de nuevo.</td></tr>`;
}

export function renderTable(items) {
    tableBody.innerHTML = "";

    if (items.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="3">No hay reportes para mostrar.</td></tr>`;
        return;
    }

    items.forEach(item => {
        const row = document.createElement('tr');
        const estadoClass = item.estado === 'Pendiente' ? 'pendiente' : 'resuelto';
        row.innerHTML = `
            <td>${item.fecha}</td>
            <td>${item.tipo}</td>
            <td><span class="status ${estadoClass}">${item.estado}</span></td>
        `;
        tableBody.appendChild(row);
    });
}

export function renderPagination(totalPages, currentPage, onPageClick) {
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