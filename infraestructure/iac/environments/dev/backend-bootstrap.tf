# =============================================================================
# Bootstrap del backend remoto de Terraform (bucket S3 + tabla DynamoDB de lock)
#
# Estos recursos YA EXISTEN en AWS y estan fuera del control de Terraform a
# proposito (ver mas abajo el motivo). El backend "s3" en versions.tf los usa
# directamente por nombre -- no hace falta que Terraform los "posea" para que
# el backend funcione.
#
# Motivo de dejarlos sin gestionar: durante una limpieza de infraestructura
# (terraform destroy) estos dos recursos tambien se destruyeron (estaban
# declarados aqui como resources normales). Se recrearon a mano por CLI para
# no perder el backend remoto en pleno destroy. Si se vuelven a declarar como
# resource en este archivo, el proximo "terraform apply" intenta CREARLOS de
# nuevo y falla (BucketAlreadyExists / ResourceInUseException), porque ya
# existen con esos nombres exactos. Si en algun momento se quiere volver a
# gestionarlos con Terraform, hay que importarlos primero:
#
#   terraform import aws_s3_bucket.terraform_state segat-terraform-state-production-<ACCOUNT_ID>
#   terraform import aws_dynamodb_table.terraform_locks segat-terraform-locks
#
# Bucket S3 (state):
#   nombre:     segat-terraform-state-production-<ACCOUNT_ID>
#   versioning: Enabled
#   encryption: SSE-KMS (aws:kms, bucket_key_enabled=true)
#   acceso publico bloqueado
#
# Tabla DynamoDB (locks):
#   nombre:       segat-terraform-locks
#   billing_mode: PAY_PER_REQUEST
#   hash_key:     LockID (string)
# =============================================================================

data "aws_caller_identity" "current" {}
