# =============================================================================
# Bootstrap del backend remoto de Terraform (bucket S3 + tabla DynamoDB de lock)
#
# Estos recursos se aplican primero con el state local (el que ya existe).
# Una vez creados, se configura el bloque `backend "s3"` en versions.tf y se
# corre `terraform init -migrate-state` para mover el state existente aqui.
# =============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "segat-terraform-state-production-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "segat-terraform-state" }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "segat-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "segat-terraform-locks" }
}

data "aws_caller_identity" "current" {}
