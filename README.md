<p align="center">
  <img src="https://d1.awsstatic.com/onedam/marketing-channels/website/aws/en_US/events/approved/images/2e9f6709613d7d4cfba0294fdca12e6f.92ecbefc04808c0b3828938dfb7c15c3bc1b1bc3.png" alt="AWS Community Day" width="900" />
</p>

<h1 align="center">AWS Organization Security Lab</h1>

<p align="center">
  A CTF-style AWS security lab: investigate a shared workload, follow the trust relationships, and explain the impact.
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

## The challenge

You have been asked to assess **CloudOps Fleet Health**, an endpoint-monitoring application used by a shared operations team. Start at the deployed application URL and investigate how a seemingly limited workload might reach beyond its intended boundary.

This is a CTF-style investigation with evidence-based milestones. There are no flag strings, scoreboard, or automatic submissions in this version. Complete the challenge by explaining the path you found, the permissions that enabled it, and how to break that path.

| Milestone | Evidence to collect privately |
|---|---|
| Identify the starting workload | Explain which AWS identity the application uses and how you established that. |
| Find a workload boundary crossing | Show how the starting identity can reach another workload despite its apparent limitations. |
| Discover a second account | Identify the artifact and trust relationship that reveal the next boundary. |
| Validate the production impact | Confirm the resulting identity and explain the permissions and synthetic data at risk. |
| Propose and verify a fix | Describe a remediation, repeat the relevant check, and explain any remaining paths. |

Keep credentials, account IDs, IPs, and resource identifiers out of public write-ups. Redact your evidence before sharing it. Reading the synthetic production dataset is an optional impact exercise; the guided runner stops at identity and permission checks and recovery-user inspection.

### Choose your experience

- **Independent challenge:** deploy the lab, open `ssrf_app_url`, and investigate. Save the helper scripts and Terraform source for later if you want to avoid spoilers. The deployment instructions below also disclose implementation details.
- **Hints:** open one panel at a time in the section below when you get stuck.
- **Guided walkthrough:** use [`scripts/demo_runner_sanitized.py`](scripts/demo_runner_sanitized.py) after the credential-loading step. Its [script guide](scripts/README.md) explains configuration, controls, and limitations. The script source reveals the intended path.

### Optional hints — reveal only when needed

<details>
<summary>Hint 1 — Where does the health check run?</summary>

The application makes requests on your behalf. Compare what your browser can reach with what the application's host might reach. Look for a difference between the intended endpoint catalog and the destinations accepted by the fetcher.

</details>

<details>
<summary>Hint 2 — What identity belongs to the host?</summary>

Consider EC2 instance metadata and the application's request behavior. What changes when metadata requires a session token? The initial goal is to identify the workload role; treat any credentials returned during the exercise as secrets.

</details>

<details>
<summary>Hint 3 — A denied IAM request is not the end</summary>

Being unable to inspect your own IAM policies does not describe everything you can do. Explore the EC2 and Systems Manager visibility available to the workload. Compare tags and management status across shared instances.

</details>

<details>
<summary>Hint 4 — Shared management can cross workload boundaries</summary>

Look at the legacy Jenkins node and the scope of Systems Manager Run Command permissions. Start with an innocuous command, then compare the AWS identity on that node with the application's identity.

</details>

<details>
<summary>Hint 5 — Infrastructure artifacts can reveal trust relationships</summary>

Investigate what the Jenkins identity can read in S3. A synthetic Terraform state artifact describes accounts and roles. It contains useful topology even without embedded passwords or access keys.

</details>

<details>
<summary>Hint 6 — Cross-account access has two sides</summary>

Use the discovered role information to reason about both the caller's permission to assume a role and the target role's trust policy. Validate the resulting identity before assessing its permissions in Account B.

</details>

<details>
<summary>Hint 7 — Impact, persistence, and remediation</summary>

Review the production role's permissions, the synthetic production-data bucket, and the recovery user's permissions. Creating an access key is optional and manual; it is not required to complete the milestones. If you create one, remove it during cleanup. For remediation, consider metadata token requirements, Run Command scope, S3 access, and cross-account trust separately.

</details>

The panels start collapsed on GitHub, but their contents remain readable in the Markdown source. They are spoiler controls, not a way to hide sensitive information. Finish with the [cleanup procedure](#cleanup), including when you stop early.

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

Interactive walkthrough of the intended challenge path. It uses locally supplied account IDs, masks those IDs in its sanitized output, and asks before each step. Read the [script guide](scripts/README.md) for its inputs, scope, and output limitations. Use it after attempting the challenge if you want to preserve discovery.

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

- Two dedicated AWS sandbox accounts: Account A (CloudOps/DEV) and Account B (PROD).
- AWS CLI with a deployment profile for each account, matching `account_a_profile` and `account_b_profile` in `terraform.tfvars`.
- Terraform installed locally.
- Python installed if you plan to use the scripts under `scripts/`.
- Git installed if you are cloning the repository from GitHub.
- Bash or Git Bash for the credential-loading commands below. The loader emits Bash `export` statements; do not run them with PowerShell `Invoke-Expression`.

Verify your AWS identity before deploying:

```bash
aws sts get-caller-identity --profile lab-account-a
aws sts get-caller-identity --profile lab-account-b
```

Replace the example profile names with your deployment profiles. Keep these credentials separate from the temporary application credentials used during the demo. Identity and Terraform output commands reveal environment identifiers; keep their output out of public logs and screenshots.

Verify the tools in the terminal you will use:

```bash
terraform version
aws --version
python --version
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

Set both account IDs and deployment profile names, restrict `app_ingress_cidr` to your public IP with `/32`, and review the role and user names. The included account IDs and public CIDR are documentation examples. The demo runner currently uses `us-east-1`, `CloudOpsInventoryRole`, `ProdDeployRole`, `OperationsRecoveryUser`, and the default bucket naming scheme; keep the corresponding Terraform settings aligned with the script.

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

Run the following commands from the repository root in a dedicated **Bash or Git Bash** terminal after deployment. Use `python3` throughout if that is your working interpreter command. On Windows, confirm that the command starts an installed interpreter rather than a Microsoft Store alias.

### 1. Supply the account IDs locally

Enter the same 12-digit IDs used in `terraform.tfvars`. Reading them interactively keeps the literal values out of the shell command history:

```bash
read -r -s -p "Account A ID: " LAB_ACCOUNT_A_ID; printf '\n'
read -r -s -p "Account B ID: " LAB_ACCOUNT_B_ID; printf '\n'
export LAB_ACCOUNT_A_ID LAB_ACCOUNT_B_ID
```

The runner requires both variables and rejects missing or malformed IDs. It uses them to build the tfstate bucket name and production role ARN, and replaces those two IDs with `ACCOUNT_A` and `ACCOUNT_B` in its sanitized output. Other resource identifiers, IP addresses, names, and command results can remain visible; review output before sharing it.

### 2. Load the temporary application credentials

Keep the deployment terminal separate. In the dedicated demo terminal, disable shell tracing and remove any existing session credentials before loading the application identity:

```bash
set +x
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
read -r -p "Lab application public IP: " LAB_APP_PUBLIC_IP

if LAB_CREDENTIAL_EXPORTS="$(python scripts/load-cloudops-creds.py "$LAB_APP_PUBLIC_IP")"; then
  eval "$LAB_CREDENTIAL_EXPORTS"
  unset LAB_CREDENTIAL_EXPORTS
else
  unset LAB_CREDENTIAL_EXPORTS
  printf 'Credential loading failed. Stop here and check the lab application.\n' >&2
fi
```

Use the public IP from the deployed `ssrf_app_url` output, without the URL scheme, port, or path. The loader detects the application port and exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, and `AWS_DEFAULT_REGION` into this shell. It prints progress messages to stderr.

The loader's stdout contains credentials. Capture it as shown; running the loader directly, enabling shell tracing, or redirecting its stdout to a file exposes them. Run only the reviewed loader from this repository with `eval`.

### 3. Run the guided demonstration

After successful credential loading:

```bash
python scripts/demo_runner_sanitized.py
```

Use `y` to execute the next step, `n` to skip it, and `q` to exit. The runner checks for the three temporary credential variables and warns when they are absent. The additional access-key persistence demonstration is manual and is not automated by the runner. Follow the cleanup steps even if you stop the demonstration early.

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
9. Clear demo credentials and use deployment profiles for teardown
        |
        v
10. terraform destroy, verify both accounts, and clear local variables
```

---

## Resetting the lab

Follow the cleanup procedure below first, using the original deployment profiles and Terraform state. Then deploy again with:

```bash
terraform apply
```

---

## Cleanup

### 1. Remove credentials from the demo shell

Run this in every Bash or Git Bash terminal where you loaded or copied demo credentials:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
unset LAB_CREDENTIAL_EXPORTS
```

`unset` removes values from the current shell; it does not revoke credentials already issued by AWS or remove credentials copied to other processes, files, or terminals. If needed, follow AWS guidance on [revoking role sessions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html). AWS CLI can fall back to configured profiles after these variables are removed, so a successful CLI call does not mean the demo credentials remain loaded. See [AWS CLI credential configuration](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html).

### 2. Remove manually created persistence

If you created an additional IAM access key during the manual persistence demonstration, use the trusted Account B deployment identity to deactivate and delete that specific demo key. Check the intended user and key carefully, and preserve unrelated credentials. Follow [AWS access-key management guidance](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html). Terraform does not create or track that manual key; it can also prevent deletion of its IAM user during teardown.

Remove any other resources created manually during the demonstration. If you saved demo credentials in a dedicated AWS CLI profile, remove that profile's entries from your local AWS config and credentials files without deleting unrelated profiles.

### 3. Destroy the Terraform-managed resources

Use the deployment terminal with the original `terraform.tfvars`, state, and authenticated deployment profiles for both accounts. Clear any demo session credentials from that terminal too. Confirm the identities, substituting your profile names:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
aws sts get-caller-identity --profile lab-account-a
aws sts get-caller-identity --profile lab-account-b
terraform plan -destroy
terraform destroy
```

Review the destroy plan before confirming. The lab buckets have `force_destroy = true`, so teardown deletes their objects too. Keep only disposable lab data in them. If destroy fails, resolve the reported dependency and rerun it; retain the local state until teardown succeeds.

Verify in **both accounts** that the lab EC2 instances, networking, IAM identities, and S3 buckets are gone, and check for manually created resources outside Terraform's state. Terraform teardown does not automatically remove all service-generated records such as SSM command history or CloudTrail events; treat those records as environment-specific information.

### 4. Clear remaining local demo settings

In the dedicated demo shell:

```bash
unset LAB_ACCOUNT_A_ID LAB_ACCOUNT_B_ID LAB_APP_PUBLIC_IP LAB_CREDENTIAL_EXPORTS
unset AWS_REGION AWS_DEFAULT_REGION
```

If you set `AWS_PROFILE` or `AWS_DEFAULT_PROFILE` specifically for this session, clear them as well:

```bash
unset AWS_PROFILE AWS_DEFAULT_PROFILE
```

Close the dedicated demo terminal. Review any terminal recordings, screenshots, downloaded data, and captured output before sharing them. Remove local credential copies that you created. Keep `terraform.tfvars`, state, plans, and environment files private; only remove local state after successful teardown and verification. Do not commit these artifacts or upload them with presentation material.

---

## Security notes

- Use only AWS accounts and resources that you are authorized to test.
- Keep the lab isolated from production workloads.
- Do not commit AWS credentials, temporary tokens, private keys, or other secrets.
- Keep environment-specific values outside the repository when they are sensitive.
- The runner masks the two configured account IDs in its sanitized output; it does not provide complete redaction of AWS responses or terminal recordings.
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
