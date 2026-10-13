# Terraform describing where the demo app *would* be deployed on AWS.
# This is never applied. It exists so Checkov (step 6) can scan it.
# Hardened in step 8c; each fix names the Checkov check it closes.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# Bucket for prescription PDFs (PHI). In the AWS provider v4+, a bucket is a
# bare resource and every setting is its own companion resource, which is why
# one bucket needs five blocks below. Checkov checks for each block.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "prescription_files" {
  bucket = "gifthealth-demo-prescription-files"
}

# Owner-only. "public-read" would have made every PDF a URL away.  (CKV_AWS_20)
resource "aws_s3_bucket_acl" "prescription_files_acl" {
  bucket = aws_s3_bucket.prescription_files.id
  acl    = "private"
}

# Belt and braces: even if someone later sets a public ACL or policy, AWS
# refuses it. Every bucket should have this.                       (CKV2_AWS_6)
resource "aws_s3_bucket_public_access_block" "prescription_files" {
  bucket                  = aws_s3_bucket.prescription_files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keep old versions, so an accidental delete or an attacker's overwrite can
# be undone.                                                        (CKV_AWS_21)
resource "aws_s3_bucket_versioning" "prescription_files" {
  bucket = aws_s3_bucket.prescription_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Customer-managed KMS key, rotated yearly. SSE-S3 would also pass the
# encryption bar; KMS adds an audit trail of every decrypt, which is what
# HIPAA auditors ask for.                                          (CKV_AWS_145)
resource "aws_kms_key" "prescription_files" {
  description         = "Encrypts prescription PDFs at rest"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.prescription_files_key.json
}

# Who may administer and use the key. Without an explicit policy AWS applies
# a permissive default, which Checkov treats as undefined.        (CKV2_AWS_64)
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "prescription_files_key" {
  # In a KMS key policy, Resource "*" means "this key" (AWS docs), and the
  # account-root statement is AWS's documented default. Checkov applies its
  # generic IAM rules here and misreads both. Accepted, not deferred.
  #checkov:skip=CKV_AWS_109:KMS key policy; Resource "*" is scoped to this key by definition.
  #checkov:skip=CKV_AWS_111:KMS key policy; Resource "*" is scoped to this key by definition.
  #checkov:skip=CKV_AWS_356:KMS key policy; Resource "*" is scoped to this key by definition.
  statement {
    sid       = "AccountAdminsManageKey"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prescription_files" {
  bucket = aws_s3_bucket.prescription_files.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.prescription_files.arn
    }
  }
}

# Who read which PDF, when. Logs go to a separate bucket below.   (CKV_AWS_18)
resource "aws_s3_bucket_logging" "prescription_files" {
  bucket        = aws_s3_bucket.prescription_files.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "prescription-files/"
}

# ---------------------------------------------------------------------------
# Bucket that receives the access logs. It gets the same hardening, with two
# documented exceptions. The "#checkov:skip" comments are Checkov's inline
# exception syntax: same rule as brakeman.ignore, every skip needs a reason.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "access_logs" {
  #checkov:skip=CKV_AWS_18:This IS the log bucket; logging it into itself would loop.
  #checkov:skip=CKV_AWS_145:S3 server access logs can only be delivered to SSE-S3 (AES256) targets, not SSE-KMS.
  bucket = "gifthealth-demo-access-logs"
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Firewall rules for the web server.
resource "aws_security_group" "web" {
  name        = "gifthealth-demo-web"
  description = "Web server security group"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed Postgres database.
resource "aws_db_instance" "patients" {
  identifier          = "gifthealth-demo-db"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "gifthealth"
  password            = var.db_password
  publicly_accessible = false
  storage_encrypted   = true
  backup_retention_period = 7
  skip_final_snapshot     = false
  deletion_protection     = true
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  parameter_group_name                = aws_db_parameter_group.patients.name
}

# Postgres settings. Logging every statement is how you answer "who queried
# this patient's record" after an incident.                       (CKV2_AWS_30)
resource "aws_db_parameter_group" "patients" {
  name   = "gifthealth-demo-postgres"
  family = "postgres16"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "0"
  }

  # Refuse unencrypted connections, so PHI never crosses the wire in
  # the clear even inside the VPC.                                 (CKV2_AWS_69)
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

# The database password is supplied at apply time (TF_VAR_db_password env var,
# a CI secret, or a secrets manager). "sensitive" keeps it out of plan output
# and state diffs. The old hardcoded value is still in git history; in a real
# incident that password is rotated first and this edit comes second.
variable "db_password" {
  description = "Master password for the patients database"
  type        = string
  sensitive   = true
}
