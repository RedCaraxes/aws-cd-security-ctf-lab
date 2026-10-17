locals {
  inventory_bucket_name = "orgsec-inventory-${var.account_a_id}-${var.region}"
  tfstate_bucket_name   = "orgsec-tfstate-${var.account_a_id}-${var.region}"
}

resource "aws_s3_bucket" "inventory" {
  provider      = aws.a
  bucket        = local.inventory_bucket_name
  force_destroy = true

  tags = {
    Name    = local.inventory_bucket_name
    Purpose = "CloudOps inventory"
  }
}

resource "aws_s3_bucket_public_access_block" "inventory" {
  provider = aws.a
  bucket   = aws_s3_bucket.inventory.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "inventory" {
  provider = aws.a
  bucket   = aws_s3_bucket.inventory.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "tfstate" {
  provider      = aws.a
  bucket        = local.tfstate_bucket_name
  force_destroy = true

  tags = {
    Name    = local.tfstate_bucket_name
    Purpose = "Synthetic Terraform backend for security lab"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  provider = aws.a
  bucket   = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  provider = aws.a
  bucket   = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "ec2_inventory" {
  provider     = aws.a
  bucket       = aws_s3_bucket.inventory.id
  key          = "ec2/latest/ec2_inventory.csv"
  content_type = "text/csv"
  content = <<-CSV
account_id,region,instance_id,name,state,private_ip,owner,application,environment,launch_note
${var.account_a_id},${var.region},${aws_instance.ssrf_app.id},ue1-cloudops-inventory-app-01,running,${aws_instance.ssrf_app.private_ip},CloudOps,Inventory,SHARED,current
${var.account_a_id},${var.region},${aws_instance.jenkins.id},ue1-shared-jenkins-agent-legacy-01,running,${aws_instance.jenkins.private_ip},DevOps,Jenkins,SHARED,legacy
CSV
}

resource "aws_s3_object" "ssm_inventory" {
  provider     = aws.a
  bucket       = aws_s3_bucket.inventory.id
  key          = "ssm/latest/managed_instances.csv"
  content_type = "text/csv"
  content = <<-CSV
instance_id,ping_status,platform_name,platform_version,owner,application
${aws_instance.jenkins.id},Online,Amazon Linux,2023,DevOps,Jenkins
CSV
}

resource "aws_s3_object" "synthetic_tfstate" {
  provider     = aws.a
  bucket       = aws_s3_bucket.tfstate.id
  key          = "account-factory/terraform.tfstate"
  content_type = "application/json"

  content = jsonencode({
    version           = 4
    terraform_version = "1.9.8"
    serial            = 42
    lineage           = "aws-org-security-lab-synthetic-state"
    outputs = {
      accounts = {
        value = {
          development = {
            account_id = var.account_a_id
            role_name  = var.jenkins_role_name
          }
          production = {
            account_id = var.account_b_id
            role_name  = var.prod_role_name
          }
        }
        type = [
          "object",
          {
            development = ["object", { account_id = "string", role_name = "string" }]
            production  = ["object", { account_id = "string", role_name = "string" }]
          }
        ]
      }
    }
    resources = []
  })
}

# -----------------------------------------------------------------------------
# Account B - Synthetic production data used for the impact/exfiltration stage
# -----------------------------------------------------------------------------
locals {
  prod_data_bucket_name = "orgsec-prod-data-${var.account_b_id}-${var.region}"
}

resource "aws_s3_bucket" "prod_data" {
  provider      = aws.b
  bucket        = local.prod_data_bucket_name
  force_destroy = true

  tags = {
    Name               = local.prod_data_bucket_name
    Environment        = "PROD"
    DataClassification = "Confidential"
    Purpose            = "Synthetic production data for security lab"
  }
}

resource "aws_s3_bucket_public_access_block" "prod_data" {
  provider = aws.b
  bucket   = aws_s3_bucket.prod_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod_data" {
  provider = aws.b
  bucket   = aws_s3_bucket.prod_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "prod_customers" {
  provider     = aws.b
  bucket       = aws_s3_bucket.prod_data.id
  key          = "exports/customers.csv"
  content_type = "text/csv"
  content = <<-CSV
customer_id,name,email,plan
CUST-1001,Ana Torres,ana.torres@example.test,enterprise
CUST-1002,Carlos Vega,carlos.vega@example.test,business
CUST-1003,Lucia Ramos,lucia.ramos@example.test,enterprise
CSV
}
