package com.segat.trujilloinformado.model.dao;

import com.segat.trujilloinformado.model.entity.NotificationLog;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationLogDao extends JpaRepository<NotificationLog, Long> {
}
