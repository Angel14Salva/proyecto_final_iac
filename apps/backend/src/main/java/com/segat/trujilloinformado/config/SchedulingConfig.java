
package com.segat.trujilloinformado.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Habilita la ejecucion de metodos @Scheduled -- lo necesita
 * SqsNotificacionConsumer para hacer polling periodico de la cola.
 * Separado de AsyncConfig (que habilita @Async) para no mezclar
 * responsabilidades en un mismo archivo.
 */
@Configuration
@EnableScheduling
public class SchedulingConfig {
}

