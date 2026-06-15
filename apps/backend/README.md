# TrujilloInformado

**TrujilloInformado** es una aplicación backend desarrollada en Java con Spring Boot para la gestión de reportes ciudadanos y tareas operativas, enfocada en la gestión ambiental (SEGAT). Incorpora funcionalidades geoespaciales para la ubicación de incidencias.

## Tecnologías Utilizadas

*   **Java 21**
*   **Spring Boot 3.5.5**
    *   Spring Web
    *   Spring Data JPA (Hibernate)
    *   Spring Security (JWT)
    *   Spring Validation
*   **Base de Datos:** PostgreSQL con extensión **PostGIS** (Geoespacial)
*   **Almacenamiento de Imágenes:** Cloudinary
*   **Integración:** Webhooks para n8n
*   **Documentación API:** Swagger / OpenAPI
*   **Generación de Documentos:** OpenPDF

## Requisitos Previos

*   Java Development Kit (JDK) 21
*   Docker y Docker Compose
*   Maven (o usar el wrapper `mvnw` incluido)

## Configuración del Entorno

### 1. Base de Datos
El proyecto incluye un archivo `docker-compose.yml` para levantar una instancia de PostgreSQL con PostGIS.

```bash
docker-compose up -d
```

Esto iniciará la base de datos en el puerto **5433** (mapeado internamente al 5432) con las credenciales definidas en el archivo compose (`dev_user` / `dev_pass`) y la base de datos `reportes_db`.

### 2. Variables de Entorno
La aplicación depende de varias variables de entorno para su configuración (ver `src/main/resources/application-prod.yml`). Debes definirlas antes de ejecutar la aplicación, ya sea en tu IDE, en un archivo de configuración local o exportándolas en tu terminal.

**Variables requeridas:**

*   **JWT (Seguridad):**
    *   `JWT_SECRET`: Clave secreta para firmar los tokens.
    *   `JWT_EXPIRATION`: Tiempo de expiración del token en milisegundos (ej. 86400000 para 1 día).
    *   `JWT_REFRESH_EXPIRATION`: Tiempo de expiración del refresh token en milisegundos.

*   **Base de Datos:**
    *   `DATABASE_URL`: URL de conexión JDBC.
        *   Ejemplo para local: `jdbc:postgresql://localhost:5433/reportes_db?user=dev_user&password=dev_pass`

*   **Cloudinary (Imágenes):**
    *   `CLOUDINARY_CLOUD_NAME`: Nombre de tu cloud.
    *   `CLOUDINARY_API_KEY`: Tu API Key.
    *   `CLOUDINARY_API_SECRET`: Tu API Secret.

*   **n8n (Webhooks):**
    *   `N8N_NEW_REPORT`: URL del webhook para el envio de nuevos reportes por WhatsApp.
    *   `N8N_NEW_TASK`: URL del webhook para el envio de nuevas tareas por WhatsApp.

*   **Servidor (Opcional):**
    *   `PORT`: Puerto de la aplicación (por defecto 8080).

## Ejecución

Para ejecutar la aplicación usando el perfil de producción (o asegurándote de que cargue la configuración), puedes usar el wrapper de Maven.

```bash
# Asegúrate de tener las variables de entorno configuradas
./mvnw spring-boot:run -Dspring-boot.run.profiles=prod
```

O si configuras un archivo `application.properties` local en `src/main/resources` con los valores necesarios, simplemente:

```bash
./mvnw spring-boot:run
```

## Estructura del Proyecto

*   `src/main/java/com/segat/trujilloinformado`: Código fuente Java.
    *   `controller`: Controladores REST (`Authentication`, `Reporte`, `Tarea`, `Usuario`).
    *   `model`: Entidades JPA.
    *   `service`: Lógica de negocio.
    *   `security`: Configuración de seguridad y JWT.
*   `src/main/resources`: Archivos de configuración y recursos.
    *   `data/`: Datos iniciales (ej. `zonas.json`).

## Documentación de la API

Una vez iniciada la aplicación, puedes acceder a la documentación interactiva de la API (Swagger UI) en la ruta configurada por defecto (usualmente):

*   `http://localhost:8080/swagger-ui.html`
