# Ansible — Orquestación de Infraestructura SEGAT

## Descripción
Playbooks de Ansible para orquestar el ciclo de vida completo de la
infraestructura SEGAT en AWS usando Terraform y Checkov.

## Playbooks disponibles

| Playbook | Descripción |
|----------|-------------|
| `deploy.yml` | Despliega la infraestructura en AWS |
| `validate.yml` | Ejecuta análisis de seguridad con Checkov |
| `destroy.yml` | Destruye la infraestructura de forma segura |
| `site.yml` | Orquesta todo el ciclo de vida |

## Uso

Por defecto todos los playbooks operan sobre `infraestructure/iac/environments/dev`.
Para apuntar a otro entorno, pasa `target_env`:

```bash
# Validar seguridad del código (entorno dev por defecto)
ansible-playbook validate.yml

# Desplegar infraestructura de un entorno especifico
ansible-playbook deploy.yml -e target_env=qa
ansible-playbook deploy.yml -e target_env=prod

# Destruir infraestructura de un entorno especifico
ansible-playbook destroy.yml -e target_env=qa
```

## Requisitos
- Ansible >= 2.9
- Terraform >= 1.5
- AWS CLI configurado
- Docker (para Checkov)
