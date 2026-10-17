output "ssrf_app_url" {
  description = "URL of the intentionally vulnerable application."
  value       = "http://${aws_instance.ssrf_app.public_ip}:${var.app_port}/"
}

output "ssrf_fetch_endpoint" {
  description = "Fetcher endpoint used by the SSRF demo."
  value       = "http://${aws_instance.ssrf_app.public_ip}:${var.app_port}/fetch?url="
}

output "initial_role_arn" {
  value = aws_iam_role.initial.arn
}

output "inventory_bucket" {
  value = aws_s3_bucket.inventory.bucket
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins.arn
}

output "terraform_state_bucket" {
  value = aws_s3_bucket.tfstate.bucket
}

output "prod_role_arn" {
  value = aws_iam_role.prod_deploy.arn
}

output "prod_data_bucket" {
  description = "Synthetic production-data bucket in Account B."
  value       = aws_s3_bucket.prod_data.bucket
}

output "legacy_recovery_user" {
  description = "Account B IAM user reserved for the additional-access-key persistence demo."
  value       = aws_iam_user.operations_recovery.name
}

output "account_validation" {
  value = {
    account_a_authenticated = data.aws_caller_identity.account_a.account_id
    account_b_authenticated = data.aws_caller_identity.account_b.account_id
  }
}
