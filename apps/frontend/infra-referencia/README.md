
# infra-referencia

Este directorio contenía el Terraform original del repo `Fronted-Segat`
(S3 + CloudFront + WAF propios). Se reemplazó por una integración real
dentro de `infraestructure/iac/` (los archivos listados abajo, de la version
inicial monolitica, hoy viven repartidos en `modules/cdn` y `modules/oidc`):

- `s3-frontend.tf` — bucket S3 privado para los assets del frontend
- `cloudfront.tf` — se agregó el bucket como origen (via OAC) y el comportamiento
  por defecto de la distribución CloudFront existente ahora sirve el frontend;
  `/api/*` sigue enrutando al backend (ALB con failover)
- `github_oidc.tf` — rol OIDC para que el pipeline de GitHub Actions despliegue
  el frontend a S3 e invalide CloudFront, sin credenciales estáticas
- `outputs.tf` — expone `cloudfront_domain_name`, `cloudfront_distribution_id`
  y `s3_frontend_bucket` para configurar el pipeline

No hay Terraform activo aquí a propósito, para no duplicar recursos
(dos CloudFront/WAF/S3) con la infraestructura ya existente.

