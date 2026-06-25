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

```bash
# Validar seguridad del código
ansible-playbook validate.yml

# Desplegar infraestructura
ansible-playbook deploy.yml

# Destruir infraestructura
ansible-playbook destroy.yml
```

## Requisitos
- Ansible >= 2.9
- Terraform >= 1.5
- AWS CLI configurado
- Docker (para Checkov)
