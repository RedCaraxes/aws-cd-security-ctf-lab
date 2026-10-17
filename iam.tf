# -----------------------------------------------------------------------------
# Account A - Public application role exposed through IMDSv1
# -----------------------------------------------------------------------------
resource "aws_iam_role" "initial" {
  provider = aws.a
  name     = var.initial_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Purpose = "Intentionally constrained CloudOps inventory role"
  }
}

resource "aws_iam_instance_profile" "initial" {
  provider = aws.a
  name     = "${var.initial_role_name}-profile"
  role     = aws_iam_role.initial.name
}

# Permissions intentionally model an over-privileged inventory workload:
# - Read-only EC2 discovery
# - Access only to the known inventory bucket (no ListAllMyBuckets)
# - SSM discovery + Run Command for SHARED workloads (the misconfiguration)
# - No IAM introspection permissions
resource "aws_iam_role_policy" "initial" {
  provider = aws.a
  name     = "CloudOpsInventoryPermissions"
  role     = aws_iam_role.initial.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InventoryRead"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid      = "InventoryBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = aws_s3_bucket.inventory.arn
      },
      {
        Sid      = "InventoryBucketRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.inventory.arn}/*"
      },
      {
        Sid    = "SSMDiscovery"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      },
      {
        # Legitimate inventory automation, but the scope is too broad: every
        # EC2 instance tagged Environment=SHARED is a valid Run Command target.
        # Jenkins is also SHARED, so this crosses the intended workload boundary.
        Sid      = "InventoryRunCommandTargets"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:${var.region}:${var.account_a_id}:instance/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = "SHARED"
          }
        }
      },
      {
        Sid      = "InventoryRunShellDocument"
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        Sid    = "InventoryCommandResults"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Account A - Legacy Jenkins role
# -----------------------------------------------------------------------------
resource "aws_iam_role" "jenkins" {
  provider = aws.a
  name     = var.jenkins_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Purpose = "Legacy CI/CD artifact role - intentionally overprivileged"
  }
}

resource "aws_iam_instance_profile" "jenkins" {
  provider = aws.a
  name     = "${var.jenkins_role_name}-profile"
  role     = aws_iam_role.jenkins.name
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm_core" {
  provider   = aws.a
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "jenkins_broad_s3_and_pivot" {
  provider = aws.a
  name     = "LegacyJenkinsBroadAccess"
  role     = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LegacyBroadS3Read"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject"
        ]
        Resource = "*"
      },
      {
        Sid      = "CrossAccountDeploy"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${var.account_b_id}:role/${var.prod_role_name}"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Account B - Production deployment role
# Intentionally broad trust to Account A plus AdministratorAccess.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "prod_deploy" {
  provider = aws.b
  name     = var.prod_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.account_a_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Purpose = "Intentionally overprivileged PROD deployment role"
  }
}

resource "aws_iam_role_policy_attachment" "prod_admin" {
  provider   = aws.b
  role       = aws_iam_role.prod_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# Account B - Existing recovery user for the later access-key persistence demo
# Terraform deliberately creates no access keys, so no secret access key is
# written into Terraform state.
# -----------------------------------------------------------------------------
resource "aws_iam_user" "operations_recovery" {
  provider = aws.b
  name     = var.legacy_recovery_user_name

  tags = {
    Purpose = "Legacy operations recovery identity"
  }
}

resource "aws_iam_user_policy_attachment" "operations_recovery_admin" {
  provider   = aws.b
  user       = aws_iam_user.operations_recovery.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
