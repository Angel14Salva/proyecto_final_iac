package com.segat.trujilloinformado.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.Executor;

@Configuration
@EnableAsync // Habilita la ejecución de métodos @Async
public class AsyncConfig {

    @Bean(name = "asyncExecutor")
    public Executor asyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();

        // Número de hilos principales que el pool mantendrá listos
        executor.setCorePoolSize(5);

        // Número máximo de hilos que el pool puede crear
        executor.setMaxPoolSize(10);

        // Tamaño de la cola para tareas en espera antes de crear más hilos
        executor.setQueueCapacity(25);

        // Prefijo para los nombres de los hilos (muy útil para debugging y logs)
        executor.setThreadNamePrefix("AsyncThread-");

        executor.initialize();
        return executor;
    }
}
