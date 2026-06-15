package com.segat.trujilloinformado.service.impl;

import com.lowagie.text.*;
import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.service.IPdfService;
import org.springframework.stereotype.Service;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
public class PdfServiceImpl implements IPdfService {

    @Override
    public ByteArrayInputStream generateReportsPdf(List<Reporte> reportes) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();

        try {
            Document document = new Document(PageSize.A4.rotate()); // Página horizontal para más columnas
            PdfWriter.getInstance(document, out);
            document.open();

            // Título
            Font titleFont = FontFactory.getFont(FontFactory.HELVETICA, 18, Font.BOLD);
            Paragraph title = new Paragraph("Reportes Ciudadanos", titleFont);
            title.setAlignment(Element.ALIGN_CENTER);
            title.setSpacingAfter(10f);
            document.add(title);

            document.add(new Paragraph(" ")); // Espacio

            // Crear tabla
            // El número 9 corresponde a las columnas que definiste en los criterios
            PdfPTable table = new PdfPTable(9);
            table.setWidthPercentage(100);

            // Encabezados de la tabla
            String[] headers = {"Código", "Fecha", "Tipo", "Estado", "Ubicación", "Comentario", "Asignado a", "Foto Reporte", "Foto Evidencia"};
            for (String header : headers) {
                table.addCell(header);
            }

            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss")
                    .withZone(ZoneId.systemDefault());

            // Llenar la tabla con los datos de los reportes
            for (Reporte reporte : reportes) {
                table.addCell(String.valueOf(reporte.getId()));
                Instant createdAt = reporte.getCreatedAt();
                String formattedDate = createdAt != null ? formatter.format(createdAt) : "";
                table.addCell(formattedDate);
                table.addCell(reporte.getType().name());
                table.addCell(reporte.getStatus().name());
                table.addCell(reporte.getAddress());
                table.addCell(reporte.getDescription());

                String assignedWorker = (reporte.getAssignedTo() != null)
                        ? reporte.getAssignedTo().getFirstname() + " " + reporte.getAssignedTo().getLastname()
                        : "No asignado";
                table.addCell(assignedWorker);

                // Para las fotos, podrías poner "Sí" o "No", o la URL
                String firstPhoto = (reporte.getPhotos() != null && !reporte.getPhotos().isEmpty()) ? "Sí" : "No";
                table.addCell(firstPhoto);

                // Asumiendo que la evidencia está en una tarea relacionada
                String evidencePhoto = (reporte.getEvidence() != null) ? "Sí" : "No";
                table.addCell(evidencePhoto);
            }

            document.add(table);
            document.close();

        } catch (Exception e) {
            // Manejar la excepción
            e.printStackTrace();
        }

        return new ByteArrayInputStream(out.toByteArray());
    }
}
