# Terraform describing where the demo app *would* be deployed on AWS.
# This is never applied. It exists so Checkov (step 6) can scan it.
# Intentionally sloppy: each VULN comment marks a misconfiguration.

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

# Bucket for prescription PDFs.
resource "aws_s3_bucket" "prescription_files" {
  bucket = "gifthealth-demo-prescription-files"
  # VULN: no server-side encryption, versioning, logging, or public-access block
  # is configured. For PHI this would be a HIPAA problem, not just a best-practice miss.
}

# VULN: bucket is world-readable.
resource "aws_s3_bucket_acl" "prescription_files_acl" {
  bucket = aws_s3_bucket.prescription_files.id
  acl    = "public-read"
}

# Firewall rules for the web server.
resource "aws_security_group" "web" {
  name        = "gifthealth-demo-web"
  description = "Web server security group"

  # VULN: SSH open to the entire internet.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
  # VULN: hardcoded database password (secret scanners should catch this too).
  password            = "Sup3rS3cretDbPassw0rd!"
  # VULN: database reachable from the public internet.
  publicly_accessible = true
  # VULN: data at rest is not encrypted.
  storage_encrypted   = false
  # VULN: no backups, no deletion protection.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
}
