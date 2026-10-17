provider "aws" {
  alias   = "a"
  region  = var.region
  profile = var.account_a_profile

  default_tags {
    tags = {
      Project   = "aws-org-security-lab"
      Lab       = "vulnerable"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  alias   = "b"
  region  = var.region
  profile = var.account_b_profile

  default_tags {
    tags = {
      Project   = "aws-org-security-lab"
      Lab       = "vulnerable"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_caller_identity" "account_a" {
  provider = aws.a
}

data "aws_caller_identity" "account_b" {
  provider = aws.b
}

check "account_a_matches_profile" {
  assert {
    condition     = data.aws_caller_identity.account_a.account_id == var.account_a_id
    error_message = "account_a_profile is authenticated to a different AWS account than account_a_id."
  }
}

check "account_b_matches_profile" {
  assert {
    condition     = data.aws_caller_identity.account_b.account_id == var.account_b_id
    error_message = "account_b_profile is authenticated to a different AWS account than account_b_id."
  }
}
