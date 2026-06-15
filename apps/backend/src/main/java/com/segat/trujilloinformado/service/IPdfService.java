package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.entity.Reporte;

import java.io.ByteArrayInputStream;
import java.util.List;

public interface IPdfService {
    ByteArrayInputStream generateReportsPdf(List<Reporte> reportes);
}
