variable "region" {
  description = "AWS region used by the lab."
  type        = string
  default     = "us-east-1"
}

variable "account_a_profile" {
  description = "Local AWS CLI profile for Account A (CloudOps/DEV)."
  type        = string
}

variable "account_b_profile" {
  description = "Local AWS CLI profile for Account B (PROD)."
  type        = string
}

variable "account_a_id" {
  description = "12-digit AWS Account ID for Account A."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_a_id))
    error_message = "account_a_id must be a 12-digit AWS account ID."
  }
}

variable "account_b_id" {
  description = "12-digit AWS Account ID for Account B."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_b_id))
    error_message = "account_b_id must be a 12-digit AWS account ID."
  }
}

variable "initial_role_name" {
  description = "Instance role exposed through the vulnerable public application."
  type        = string
  default     = "CloudOpsInventoryRole"
}

variable "jenkins_role_name" {
  description = "Instance role attached to the legacy Jenkins EC2 instance."
  type        = string
  default     = "JenkinsArtifactRole"
}

variable "prod_role_name" {
  description = "Cross-account role created in Account B."
  type        = string
  default     = "ProdDeployRole"
}

variable "legacy_recovery_user_name" {
  description = "Existing Account B IAM user used later to demonstrate persistence through an additional long-term access key. Terraform intentionally creates no access keys."
  type        = string
  default     = "OperationsRecoveryUser"
}

variable "app_ingress_cidr" {
  description = "CIDR allowed to reach the intentionally vulnerable SSRF application. Use your public IP/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.app_ingress_cidr, 0)) && var.app_ingress_cidr != "0.0.0.0/0"
    error_message = "Use a valid restricted CIDR (for example 203.0.113.10/32). 0.0.0.0/0 is intentionally rejected."
  }
}

variable "app_port" {
  description = "TCP port for the intentionally vulnerable HTTP fetcher."
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "EC2 instance type used for both lab instances."
  type        = string
  default     = "t3.micro"
}

variable "app_imds_http_tokens" {
  description = "IMDS token mode for the public app EC2. 'optional' enables IMDSv1; 'required' is the remediation state."
  type        = string
  default     = "optional"

  validation {
    condition     = contains(["optional", "required"], var.app_imds_http_tokens)
    error_message = "app_imds_http_tokens must be either optional or required."
  }
}
