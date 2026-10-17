<p align="center">
  <img src="https://d1.awsstatic.com/onedam/marketing-channels/website/aws/en_US/events/approved/images/2e9f6709613d7d4cfba0294fdca12e6f.92ecbefc04808c0b3828938dfb7c15c3bc1b1bc3.png" alt="AWS Community Day" width="900" />
</p>

<h1 align="center">AWS Organization Security Lab</h1>

<p align="center">
  Terraform lab for demonstrating an AWS security scenario in a controlled environment.
</p>

<p align="center">
  <a href="https://aws.amazon.com/events/community-day/">
    <img src="https://img.shields.io/badge/AWS-Community%20Day-FF9900?logo=amazonaws&logoColor=white" alt="AWS Community Day" />
  </a>
  <img src="https://img.shields.io/badge/IaC-Terraform-844FBA?logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/Cloud-AWS-232F3E?logo=amazonaws&logoColor=white" alt="AWS" />
  <img src="https://img.shields.io/badge/Lab-Security-red" alt="Security Lab" />
</p>

> [!WARNING]
> This repository is a **security lab**. It contains infrastructure and application components intentionally prepared for a controlled demonstration. Deploy it only in a dedicated AWS account or sandbox that you are authorized to use. Do not deploy it in production or in shared environments.

---

## Overview

This repository contains the Terraform code and supporting scripts used to deploy and run the AWS security lab.

The project is intentionally split into three areas:

- **Terraform files in the repository root**: create the AWS infrastructure used by the lab.
- **`scripts/`**: contains the Python scripts used during the demonstration.
- **`user_data/`**: contains the EC2 bootstrap script used by the lab instance.

The objective is to keep the infrastructure, demo automation, and instance initialization clearly separated so the complete scenario can be reproduced and reset easily.

---

## Repository structure

```text
.
├── README.md
├── .gitignore
├── versions.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars.example
├── network.tf
├── compute.tf
├── iam.tf
├── s3.tf
├── outputs.tf
│
├── scripts/
│   ├── demo_runner_sanitized.py
│   └── load-cloudops-creds.py
│
└── user_data/
    └── ssrf_app.sh
```

### Terraform files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider version requirements. |
| `providers.tf` | AWS provider configuration. |
| `variables.tf` | Input variables used by the lab. |
| `terraform.tfvars.example` | Example values for creating your local `terraform.tfvars`. |
| `network.tf` | Networking resources for the lab. |
| `compute.tf` | Compute resources used by the scenario. |
| `iam.tf` | IAM resources and permissions required by the lab. |
| `s3.tf` | Amazon S3 resources used by the scenario. |
| `outputs.tf` | Values exposed after deployment. |

### Demo scripts

The scripts used during the demonstration are located in:

```text
scripts/
```

#### `scripts/demo_runner_sanitized.py`

Main sanitized demo runner used to execute the demonstration flow without embedding sensitive values directly in the repository.

Path:

```text
./scripts/demo_runner_sanitized.py
```

#### `scripts/load-cloudops-creds.py`

Helper script related to loading the CloudOps credentials used by the demo workflow.

Path:

```text
./scripts/load-cloudops-creds.py
```

### EC2 bootstrap script

The EC2 initialization script is located outside `scripts/` because it is consumed as instance user data rather than executed manually as part of the local demo flow.

Path:

```text
./user_data/ssrf_app.sh
```

This keeps the instance bootstrap logic separate from the local Python tooling.

---

## Requirements

Before deploying the lab, make sure you have:

- An AWS account dedicated to the lab or another authorized sandbox account.
- AWS CLI configured with credentials for that account.
- Terraform installed locally.
- Python installed if you plan to use the scripts under `scripts/`.
- Git installed if you are cloning the repository from GitHub.

Verify your AWS identity before deploying:

```bash
aws sts get-caller-identity
```

Verify Terraform:

```bash
terraform version
```

---

## Clone the repository

```bash
git clone <REPOSITORY_URL>
cd aws-org-security-lab-tf
```

Replace `<REPOSITORY_URL>` with the GitHub URL of this repository.

---

## Configure the lab

Create your local Terraform variables file from the included example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

On Windows PowerShell you can use:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Then review and update:

```text
terraform.tfvars
```

Use values appropriate for your dedicated lab environment.

> [!IMPORTANT]
> Do not commit `terraform.tfvars` if it contains environment-specific or sensitive values.

---

## Deploy the infrastructure

Initialize Terraform:

```bash
terraform init
```

Format and validate the configuration:

```bash
terraform fmt
terraform validate
```

Review the execution plan:

```bash
terraform plan
```

Deploy the lab:

```bash
terraform apply
```

Confirm the apply only after reviewing the resources Terraform plans to create.

---

## Review Terraform outputs

After the deployment completes, inspect the values exported by the lab:

```bash
terraform output
```

The exact outputs are defined in:

```text
outputs.tf
```

You can also request a specific output with:

```bash
terraform output <OUTPUT_NAME>
```

---

## Running the demo scripts

All local demo automation is stored under:

```text
./scripts/
```

The two Python files included in this repository are:

```text
./scripts/demo_runner_sanitized.py
./scripts/load-cloudops-creds.py
```

Before running them, review their configuration and expected inputs in the source files and make sure the Terraform deployment is complete.

For example, from the repository root:

```bash
eval "$(python scripts/load-cloudops-creds.py <PUBLIC_IP>)"
```

and:

```bash
export LAB_ACCOUNT_A_ID="<ACCOUNT_A_ID>"
export LAB_ACCOUNT_B_ID="<ACCOUNT_B_ID>"
python scripts/demo_runner_sanitized.py
```

Depending on your operating system, the Python command may be `python3` instead of `python`.

---

## Instance bootstrap

The file:

```text
./user_data/ssrf_app.sh
```

contains the shell bootstrap logic used by the lab instance.

It is part of the infrastructure deployment and should remain under `user_data/` rather than being treated as a manually executed local demo script.

If you change this file, review the corresponding Terraform resource in `compute.tf` before redeploying the instance.

---

## Recommended lab workflow

```text
1. Clone repository
        |
        v
2. Configure terraform.tfvars
        |
        v
3. terraform init
        |
        v
4. terraform plan
        |
        v
5. terraform apply
        |
        v
6. Review terraform output
        |
        v
7. Use scripts/ for the demo workflow
        |
        v
8. Validate the security observations
        |
        v
9. terraform destroy
```

---

## Resetting the lab

If you want to rebuild the environment from scratch, destroy the existing deployment first:

```bash
terraform destroy
```

Review the destroy plan carefully before confirming it.

Then deploy again with:

```bash
terraform apply
```

---

## Cleanup

When the lab is finished, remove the AWS resources to avoid leaving unnecessary infrastructure running:

```bash
terraform destroy
```

After Terraform finishes, verify that the resources created for the lab are no longer present in the AWS account.

---

## Security notes

- Use only AWS accounts and resources that you are authorized to test.
- Keep the lab isolated from production workloads.
- Do not commit AWS credentials, temporary tokens, private keys, or other secrets.
- Keep environment-specific values outside the repository when they are sensitive.
- The `demo_runner_sanitized.py` filename is intentional: public demo material should remain sanitized before being committed or shared.
- Destroy the environment after the demonstration when it is no longer required.

---

## File location quick reference

| Component | Location |
|---|---|
| Main demo runner | `scripts/demo_runner_sanitized.py` |
| CloudOps credential helper | `scripts/load-cloudops-creds.py` |
| EC2 bootstrap / SSRF app setup | `user_data/ssrf_app.sh` |
| Terraform variable example | `terraform.tfvars.example` |
| Networking | `network.tf` |
| Compute | `compute.tf` |
| IAM | `iam.tf` |
| S3 | `s3.tf` |
| Outputs | `outputs.tf` |

---

## AWS Community Day

This lab was prepared as technical demonstration material around AWS security topics and hands-on cloud security scenarios.

AWS Community Days are community-led events focused on peer-to-peer technical learning, practical sessions, workshops, and real-world AWS experience.

Official AWS Community Day page:

https://aws.amazon.com/events/community-day/

---

## Disclaimer

This repository is provided for **educational and authorized security testing purposes only**.

The author is not responsible for use of this lab outside environments where you have explicit authorization to deploy and test the resources.

---

<p align="center">
  <b>Built for hands-on AWS security learning.</b><br/>
  Infrastructure as Code · AWS · Terraform · Security
</p>
