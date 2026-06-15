package com.segat.trujilloinformado.service;

import com.segat.trujilloinformado.model.entity.Reporte;
import com.segat.trujilloinformado.model.entity.Tarea;

public interface INotificationService {
    void sendNewReportNotification(Reporte reporte);
    void sendNewTaskNotification(Tarea tarea);
}
