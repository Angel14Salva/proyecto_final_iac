# proyecto_final_iac

## Sistema de Gestión de Reportes Medio Ambientales para el SEGAT

### Docente:
- Leturia Rodriguez, Walter Ivan

### Curso:
- Infraestructura como Código

### Integrantes:
- Reyes Figueroa, Brandon
- Salvador Mauricio, Ángel
- Terrones Llamo, Jan
- Vilca Jiménez, Juan Carlos

## Configuración inicial (git hooks)

Este repo trae hooks de Git versionados en `.githooks/` (pre-commit, commit-msg, pre-push).
Después de clonar, cada desarrollador debe activarlos una sola vez:

```bash
git config core.hooksPath .githooks
```

Qué hace cada uno:
- **pre-commit**: si hay cambios en `apps/backend/**/*.java`, compila el backend; si hay cambios en `infraestructure/iac/**/*.tf`, valida `terraform fmt`.
- **commit-msg**: exige [Conventional Commits](https://www.conventionalcommits.org/) (`tipo(scope): descripción`, ej. `fix(CKV2_AWS_46): ...`).
- **pre-push**: corre `mvn test` y **solo avisa** si algo falla (modo advertencia temporal hasta que la Fase 3 del roadmap de CI/CD deje los tests de integración funcionando standalone; después pasará a bloquear el push).

## Análisis de calidad de código (SonarQube self-hosted)

SonarQube corre localmente vía Docker, con su propia base de datos Postgres:

```bash
docker compose -f infraestructure/docker/sonarqube/docker-compose.yml up -d
```

La UI queda en http://localhost:9000 (usuario/clave por defecto `admin`/`admin` — cámbiala al primer login).
Generas un token personal desde tu perfil (o vía API `/api/user_tokens/generate`) y corres el análisis del backend:

```bash
cd apps/backend
./mvnw clean verify sonar:sonar -Dsonar.token=<tu-token>
```

`verify` corre los tests y genera el reporte de cobertura de JaCoCo (`target/site/jacoco/jacoco.xml`), que el plugin de Sonar levanta automáticamente vía `sonar.coverage.jacoco.xmlReportPaths` (configurado en `pom.xml`). El `sonar.host.url` por defecto apunta a `http://localhost:9000`; en CI se sobreescribe con `-Dsonar.host.url=...`.

Para bajar el stack: `docker compose -f infraestructure/docker/sonarqube/docker-compose.yml down` (agrega `-v` si además quieres borrar los datos persistidos).

## Pipeline CI/CD (GitHub Actions)

Dos workflows en `.github/workflows/`:

Ambos corren en push a `main`, `develop` y `feature` (y en PRs a `main`), filtrados por `paths:` para no dispararse de más:

- **backend-ci.yml**: corre `mvn verify` (build + tests unitarios/integración + JaCoCo) en un runner Linux — ahí Testcontainers funciona nativo, sin el problema de named pipes que vimos en Windows. El análisis de Sonar y el build+push de la imagen a ECR son **pasos opcionales**: solo corren si están configuradas las variables/secrets correspondientes (ver abajo); si no existen, el job se salta en vez de romper el pipeline. El build+push a ECR además **solo corre en push a `main`** — nunca desde `develop`/`feature`, aunque el resto del job (build+test) sí valida ahí.
- **terraform-ci.yml**: corre `terraform fmt -check` + `terraform validate` (sin backend remoto, así que no hace `plan`/`apply` — el estado sigue siendo local/manual vía Ansible por ahora) en matrix sobre los 3 entornos (`dev`, `qa`, `prod`) de `infraestructure/iac/environments/`, más un scan de Checkov que sube resultados a GitHub Code Scanning.

## Entornos de infraestructura (dev / qa / prod)

`infraestructure/iac/environments/` trae los 3 entornos, cada uno un root module delgado que llama una sola vez al wiring compartido de los 14 módulos (`infraestructure/iac/modules/stack/`) — así el wiring de módulos nunca puede divergir entre entornos, solo los valores (CIDR, dominio, `environment`). Los tres se despliegan en la misma cuenta de AWS; todos los nombres de recurso llevan el prefijo `${project_name}-${environment}` para no chocar entre sí.

| Entorno | `environment` | VPC CIDR | Dominio |
|---|---|---|---|
| dev  | `dev`  | `10.0.0.0/16` | `dev.segat.com` |
| qa   | `qa`   | `10.1.0.0/16` | `qa.segat.com`  |
| prod | `prod` | `10.2.0.0/16` | `segat.com`     |

Tres recursos son singletons de cuenta (AWS solo permite uno por cuenta/región o por URL, sin importar el nombre): `aws_api_gateway_account`, `aws_config_configuration_recorder` y `aws_iam_openid_connect_provider` (GitHub Actions). Solo `dev` los crea (`manage_apigw_account_settings` / `manage_config_recorder` / `manage_oidc_provider` en `true`); `qa` y `prod` los dejan en `false` para no pisarse entre sí — sus roles IAM igual funcionan porque referencian el ARN predecible del provider en vez de crear uno nuevo. Si `dev` se destruye, hay que pasar esos flags a otro entorno.

```bash
cd infraestructure/iac/environments/dev   # o qa / prod
terraform init
terraform plan -out=tfplan   # pide TF_VAR_db_password
terraform apply tfplan
```

Variables/secrets a configurar en GitHub (`Settings > Secrets and variables > Actions`) para activar los pasos opcionales:

| Nombre | Tipo | Para qué |
|---|---|---|
| `AWS_GHA_ROLE_ARN` | Variable | ARN del rol IAM que GitHub Actions asume vía OIDC para poder hacer push a ECR. Lo genera `infraestructure/iac/modules/oidc` (ver siguiente sección) — **todavía no aplicado**. |

El análisis de calidad de código corre en un workflow aparte (`sonarqube.yml`), contra SonarCloud en vez de un SonarQube self-hosted (self-hosted en `localhost` no es alcanzable por los runners de GitHub). Requiere los secrets `SONAR_TOKEN`, `SONAR_PROJECT_KEY` y `SONAR_ORGANIZATION` (ver sonarcloud.io → tu proyecto).

### OIDC de GitHub Actions hacia AWS (pendiente de aplicar)

[modules/oidc](infraestructure/iac/modules/oidc/main.tf) define el proveedor OIDC + los roles IAM que le darían a GitHub Actions permiso para hacer `docker push` a ECR y desplegar el frontend sin guardar credenciales AWS de larga duración en GitHub, restringido a `repo:Angel14Salva/proyecto_final_iac` en la rama `main`. Se crea automáticamente al aplicar cualquier entorno (forma parte de `modules/stack`) — no es un archivo aparte que se aplique por separado. Ningún entorno se aplicó todavía (no se corrió `terraform apply` real) porque toca infraestructura real de AWS — hay que revisarlo y aplicarlo a propósito:

```bash
cd infraestructure/iac/environments/dev   # o qa / prod
terraform plan   # revisar los recursos antes de aplicar
terraform apply
```

Después de aplicarlo, copia el output `github_actions_role_arn` a la variable `AWS_GHA_ROLE_ARN` en GitHub para que el job `docker-build-push` se active.

**Nota:** el job solo hace `docker build` + `docker push` con el tag = SHA del commit (nunca `:latest`), porque el repositorio ECR tiene `image_tag_mutability = "IMMUTABLE"` (por cumplimiento con Checkov) y la definición de tarea de ECS en `ecs.tf` apunta a `:latest` de forma fija. Conectar el push automático con un despliegue real a ECS requiere parametrizar esa definición de tarea — quedó pendiente como tarea aparte.

### Hallazgos al conectar Checkov al pipeline

Al correr `terraform validate` por primera vez (nunca se había automatizado) apareció un bug real: a `aws_api_gateway_stage.prod` le faltaba el argumento `format` obligatorio en `access_log_settings` — lo corregí, y de paso corregí el desalineamiento de `terraform fmt` en varios archivos (cosmético, sin cambios de comportamiento).

Arreglar ese bug destapó 6 hallazgos de Checkov en `apigateway.tf` que antes eran invisibles porque el parser nunca llegaba a evaluar ese recurso. Corregí los 2 gratuitos (`create_before_destroy`, nivel de logging vía `aws_api_gateway_method_settings`) y reutilicé el WAF que ya protege el ALB externo para también cubrir el API Gateway. Quedan 4 sin resolver, todos con trade-offs reales que no me correspondía decidir unilateralmente:

- `CKV_AWS_120` / `CKV_AWS_225` — habilitar caching de API Gateway implica un cache cluster con costo recurrente.
- `CKV2_AWS_51` — autenticación por certificado de cliente (mTLS) añade gestión de certificados.
- `CKV2_AWS_53` — validación de requests en el proxy necesita definir validadores/schemas por endpoint.

El job de Checkov quedó en `soft_fail: true` mientras el equipo decide qué hacer con estos 4. Detalle completo en la tarea que dejé en background.

## Monitoreo y trazabilidad (Prometheus + Grafana + Loki, solo local)

Stack independiente del backend — Prometheus scrapea `host.docker.internal:8080/actuator/prometheus` (le da igual si el backend corre dockerizado o con `mvnw spring-boot:run` directo en el host), y Promtail descubre los logs de **todos** los contenedores Docker corriendo en la máquina vía el socket de Docker (no requiere que el backend esté dockerizado para que Prometheus lo vea, pero sí para que Promtail/Loki vean sus logs):

```bash
docker compose -f infraestructure/docker/monitoring/docker-compose.yml up -d
```

- Prometheus: http://localhost:9090 (revisa `/targets` para confirmar que el backend aparece `up`)
- Loki: http://localhost:3100 (`/ready` para healthcheck; se consulta normalmente desde Grafana, no directo)
- Grafana: http://localhost:3000 (`admin`/`admin`) — los datasources de Prometheus y Loki, y el dashboard **"TrujilloInformado Backend"**, quedan provisionados automáticamente al arrancar, sin pasos manuales. El dashboard trae uptime, threads, conexiones activas de HikariCP, tasa de errores 5xx, memoria heap, uso de CPU, requests/s, latencia promedio por endpoint, y un panel de logs en vivo del backend al final.

La config vive en `infraestructure/docker/monitoring/`: `prometheus/prometheus.yml` (targets de scrape), `loki/loki-config.yml` (Loki en modo single-binary con storage en filesystem, retención 7 días), `promtail/promtail-config.yml` (descubrimiento de contenedores + extracción del campo `log.level` de los logs JSON del backend como label `level`, para poder filtrar por severidad), `grafana/provisioning/` (datasources + registro del dashboard) y `grafana/dashboards/trujillo-informado-backend.json` (el dashboard en sí, versionado como código).

Para explorar logs libremente (no solo lo que trae el dashboard): en Grafana, `Explore` → datasource `Loki` → `{compose_service="backend"}` (o `{compose_service="backend", level="ERROR"}` para filtrar solo errores).

Para bajar el stack: `docker compose -f infraestructure/docker/monitoring/docker-compose.yml down` (agrega `-v` para borrar los datos históricos de Prometheus/Grafana/Loki).
