data "aws_ssm_parameter" "al2023_ami" {
  provider = aws.a
  name     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "jenkins" {
  provider                    = aws.a
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  user_data = <<-BASH
    #!/bin/bash
    set -euxo pipefail
    systemctl enable --now amazon-ssm-agent || true
    mkdir -p /opt/jenkins-legacy
    cat >/opt/jenkins-legacy/README.txt <<'TXT'
Legacy shared Jenkins worker used for CI/CD artifacts.
This instance intentionally represents accumulated permissions in a long-lived workload.
TXT
  BASH

  tags = {
    Name        = "ue1-shared-jenkins-agent-legacy-01"
    Owner       = "DevOps"
    Application = "Jenkins"
    Environment = "SHARED"
  }
}

resource "aws_instance" "ssrf_app" {
  provider                    = aws.a
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ssrf_app.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.initial.name

  # Intentionally vulnerable default: optional => IMDSv1 + IMDSv2.
  # Change var.app_imds_http_tokens to "required" to demonstrate remediation.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.app_imds_http_tokens
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  user_data = templatefile("${path.module}/user_data/ssrf_app.sh", {
    app_port = var.app_port
  })

  # Keep the demo application reproducible when its bootstrap code changes.
  user_data_replace_on_change = true

  tags = {
    Name        = "ue1-cloudops-inventory-app-01"
    Owner       = "CloudOps"
    Application = "Inventory"
    Environment = "SHARED"
    Vulnerable  = "SSRF-IMDSv1-Lab"
  }
}
