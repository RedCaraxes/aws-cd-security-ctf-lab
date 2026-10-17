<p align="center"><img src="docs/assets/redcaraxes.svg" alt="RedCaraxes" width="720"></p>

<h1 align="center">AWS CD Security CTF Lab</h1>

<p align="center">A CTF-style AWS security lab: investigate a shared workload, follow the trust relationships, and explain the impact.</p>

<p align="center"><strong>AWS Community Day Perú 2026 · Terraform · AWS Security</strong></p>

![WARNING — DANGEROUS BY DESIGN — AUTHORIZED SANDBOX ACCOUNTS ONLY](docs/assets/lab-warning.svg)

> [!CAUTION]
> **INTENTIONALLY VULNERABLE LAB — AUTHORIZED USE ONLY**
>
> This repository deliberately deploys a **vulnerable application**, **excessive IAM permissions**, and **cross-account access paths** for an educational security demonstration.
>
> - Use only **dedicated, disposable AWS sandbox accounts** you own or are explicitly authorized to test.
> - **Never deploy in production or shared environments.** Keep real customer data and unrelated credentials outside the lab.
> - Treat temporary credentials, account identifiers, and captured evidence as **sensitive**.
> - Review the [cleanup procedure](#cleanup) after each session; leaving the runner does not destroy resources or revoke credentials.
> - **Deployment incurs AWS usage charges.** Review the [cost estimate](#estimated-deployment-cost) before applying Terraform; Free Tier or credits depend on your account eligibility and remaining benefits.
>
> **Blue Team recommendation:** review available **AWS CloudTrail** evidence after each milestone. Not every action is logged, and some events can take time to appear.

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

### Observe the attack through CloudTrail

After each challenge milestone, review the available **AWS CloudTrail** events. The objective is not only to follow the attack path, but also to understand what a defender can observe and correlate.

- **Identity and origin:** inspect `userIdentity`, `sourceIPAddress`, `userAgent`, and credential context where available.
- **API activity:** look for operations such as `SendCommand`, `AssumeRole`, and relevant IAM API events.
- **Cross-account activity:** correlate the role assumption in Account B with subsequent operations under the assumed role.
- **Sensitive objects:** review S3 object-level activity if the appropriate CloudTrail **data events** have been enabled.

Direct HTTP requests to the vulnerable application and IMDS are not CloudTrail events. CloudTrail Event History covers management events; S3 object-level access requires data event logging. Events may also take time to appear, so return to a step later if its evidence is not yet available.

**Blue Team goal:** explain both the permissions that enabled each step and the evidence available to investigate it.

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
├── .gitattributes
├── versions.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars.example
├── network.tf
├── compute.tf
├── iam.tf
├── s3.tf
├── outputs.tf
├── scripts/
│   ├── README.md
│   ├── demo_runner_sanitized.py
│   └── load-cloudops-creds.py
├── user_data/
│   └── ssrf_app.sh
└── docs/
    ├── Anatomía de un Ataque en AWS - Community Day 2026.pdf
    └── assets/
        ├── redcaraxes.svg
        └── lab-warning.svg
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

- Terraform **1.6 or newer** installed locally; see the [official installation guide](https://developer.hashicorp.com/terraform/install).

- Python installed if you plan to use the scripts under `scripts/`.

- Git installed if you are cloning the repository from GitHub.

- Bash or Git Bash for the credential-loading commands below. The loader emits Bash `export` statements; do not run them with PowerShell `Invoke-Expression`.

Install and verify the local demo tools using the [scripts prerequisite guide](scripts/README.md#install-prerequisites). Use two separate accounts with available EC2 capacity and permissions to manage this lab's EC2/VPC, IAM, and S3 resources and read the public AMI parameter. The application and Jenkins roles created by this project are **demo identities**, not deployment identities. Existing organization policies or permission boundaries can prevent deployment or intentional challenge actions even when a role has `AdministratorAccess`.

### Prepare the deployment profiles

Create or obtain authenticated AWS CLI profiles for both sandbox accounts before running Terraform. If your accounts use IAM Identity Center, configure and sign in with your own start URL, SSO region, and assigned deployment roles:

```bash
aws configure sso --profile lab-account-a
aws configure sso --profile lab-account-b
aws sso login --profile lab-account-a
aws sso login --profile lab-account-b
```

These commands require an existing Identity Center setup; they do not create accounts or grant permissions. If you use another authentication method, follow the [AWS CLI authentication guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) to prepare equivalent named profiles. For Identity Center details, see [AWS's SSO profile guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html).

Use a dedicated **deployment terminal**. Remove inherited demo session credentials from this shell before checking profiles or invoking Terraform:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
```

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
git clone https://github.com/RedCaraxes/aws-cd-security-ctf-lab.git
cd aws-cd-security-ctf-lab
```

If you forked the project, replace the clone URL with **your fork's URL**. Run the remaining commands from the cloned repository root; no files from the original presenter's computer are required.

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

For the first guided run, change only the following values in your local file:

| Setting | Required value |
|---|---|
| `account_a_profile`, `account_b_profile` | Your authenticated deployment profile names. |
| `account_a_id`, `account_b_id` | The two distinct 12-digit account IDs returned by the profile checks above. |
| `app_ingress_cidr` | The public IPv4 address of the computer/network running the demo, followed by `/32`. Replace the documentation address; a private LAN address will not work from the internet. |

Keep `region = "us-east-1"`, the example role/user names, `app_imds_http_tokens = "optional"`, and the default application port (`8080`) for this walkthrough. The credential helper probes ports 80, 8080, 8000, and 5000; an arbitrary custom port is not supported by its autodetection. Use a fresh sandbox without conflicting IAM names or an existing deployment of the same bucket names. Terraform creates the recovery user; you do not need to create it manually.

The account-matching `check` blocks in `providers.tf` [report warnings rather than blocking Terraform operations](https://developer.hashicorp.com/terraform/language/block/check). Compare both identities yourself and resolve any mismatch before applying. Do not continue with a failed account check.

> [!CAUTION]
> **DO NOT COMMIT LOCAL CONFIGURATION:** Keep `terraform.tfvars` private when it contains environment-specific or sensitive values.

---

## Resources deployed

The Terraform configuration uses **two existing AWS accounts** and declares **33 managed resources**: 25 in Account A and 8 in Account B. This count includes policy attachments, S3 settings, and uploaded objects; it is not a count of separate servers or billable services. The default region is `us-east-1`.

This inventory reveals parts of the challenge architecture. Participants who want to avoid spoilers can have a facilitator deploy the environment first.

### Account A — CloudOps/DEV

| Component | What Terraform creates |
|---|---|
| Network | 1 VPC (`10.50.0.0/16`), 1 public subnet (`10.50.1.0/24`) in an Availability Zone offering the configured instance type, 1 Internet Gateway, 1 route table with a default route to the gateway, and 1 subnet route-table association. |
| Network access | 2 security groups. The application accepts traffic on `app_port` (default `8080`) from `app_ingress_cidr`. The Jenkins node has no inbound rules. Both groups allow outbound traffic. |
| Application host | 1 Amazon Linux 2023 EC2 instance, `t3.micro` by default, with an automatically assigned public IPv4 address. User data installs a Python HTTP application and starts it as a systemd service. Metadata tokens are optional by default for the vulnerable scenario. |
| Legacy Jenkins node | 1 Amazon Linux 2023 EC2 instance, also `t3.micro` by default, with an automatically assigned public IPv4 address and required metadata tokens. Its bootstrap enables the SSM agent and creates a lab marker file; it **does not install a Jenkins server or configure a CI/CD pipeline**. |
| Workload identities | 2 IAM roles (`CloudOpsInventoryRole` and `JenkinsArtifactRole` by default), 2 instance profiles, and 2 inline policies. Terraform also attaches the existing AWS-managed `AmazonSSMManagedInstanceCore` policy to the Jenkins role. |
| Storage | 2 S3 buckets: inventory and synthetic Terraform state. Each has S3 Block Public Access enabled and default SSE-S3 (`AES256`) encryption configured. |
| Seed objects | 3 S3 objects: `ec2/latest/ec2_inventory.csv`, `ssm/latest/managed_instances.csv`, and `account-factory/terraform.tfstate`. The inventory includes identifiers of the resources deployed in your lab. |

### Account B — PROD simulation

| Component | What Terraform creates |
|---|---|
| Deployment identity | 1 IAM role (`ProdDeployRole` by default), with trust delegated to Account A and an attachment of the existing AWS-managed `AdministratorAccess` policy. These broad permissions are intentional parts of the challenge. |
| Recovery identity | 1 IAM user (`OperationsRecoveryUser` by default), also attached to `AdministratorAccess`. Terraform creates no access key or console password for this user. |
| Storage and sample data | 1 S3 bucket with S3 Block Public Access and default SSE-S3 encryption, plus `exports/customers.csv` containing synthetic customer records with `example.test` email addresses. |

### Bucket names and Terraform state

Bucket names are generated from the configured account IDs and region:

| Purpose | Name template |
|---|---|
| Inventory — Account A | `orgsec-inventory-<ACCOUNT_A_ID>-<REGION>` |
| Synthetic state — Account A | `orgsec-tfstate-<ACCOUNT_A_ID>-<REGION>` |
| Synthetic production data — Account B | `orgsec-prod-data-<ACCOUNT_B_ID>-<REGION>` |

The uploaded `account-factory/terraform.tfstate` is a **synthetic challenge artifact**, not the state used to manage this deployment. It contains your configured lab account IDs and role names. This configuration declares no remote backend, so Terraform uses local state unless you configure a backend separately. Keep the actual deployment state private and retain it for cleanup.

All three buckets use `force_destroy = true`: destroying the lab also deletes objects stored in those buckets. Use disposable lab data only.

### Prerequisites and services configured separately

Terraform reads the public SSM parameter for the Amazon Linux AMI and queries the authenticated account identities; it does not create those data sources. Supply the two AWS accounts and authenticated deployment profiles before running it.

The configuration does not create AWS Organizations accounts or policies, CloudTrail trails or S3 data-event selectors, GuardDuty detectors, Security Hub configuration, custom SSM documents, or the hardened `TerraformBackendRole` shown in the presentation. Those defensive examples are discussion material and require separate implementation. Manually created persistence access keys are also outside this Terraform configuration and must be removed separately during [cleanup](#cleanup).

---

## Estimated deployment cost

> [!WARNING]
> **THIS DEPLOYMENT IS NOT GUARANTEED TO BE FREE.** With the default configuration, budget approximately **USD 0.033 per hour** for the running lab, plus S3 requests/storage and any additional usage. Leaving it running continuously is approximately **USD 23.76 per 730-hour month** before credits, eligible Free Tier benefits, taxes, and variable charges. Complete the [cleanup procedure](#cleanup) after the exercise.

Prices checked on **2026-10-18** using the official AWS MCP server and AWS Price List API. The estimate assumes `us-east-1` (N. Virginia), two Linux `t3.micro` On-Demand instances, two public IPv4 addresses, and two 8 GiB `gp3` root volumes. Hourly storage figures are planning equivalents obtained by dividing monthly storage cost by 730; actual EBS billing is prorated to provisioned duration.

| Component | Quantity and public rate | Approx. USD/hour for the lab | Approx. USD/month (730 hours) |
|---|---|---:|---:|
| EC2 compute | 2 `t3.micro` at USD 0.0104 per instance-hour | 0.020800 | 15.18 |
| Public IPv4 | 2 addresses at USD 0.005 per address-hour | 0.010000 | 7.30 |
| EBS root storage | 2 × 8 GiB `gp3` at USD 0.08 per GB-month | 0.001753 | 1.28 |
| **Base total** | **Both instances, addresses, and root disks** | **0.032553** | **23.76** |
| S3 storage and requests | Depends on stored data and API activity | Variable | Variable |

The currently resolved Amazon Linux 2023 AMI uses an 8 GiB `gp3` root volume. Terraform does not explicitly pin the AMI version or root-volume settings, so verify them in your deployment plan. The three buckets initially hold only small lab artifacts; S3 charges depend on actual storage and requests, not simply the number of buckets.

| Time with both hosts running | Approximate base cost (USD) |
|---|---:|
| 1 hour | 0.03 |
| 4 hours | 0.13 |
| 8 hours | 0.26 |
| 24 hours | 0.78 |

These examples assume you destroy the lab afterward. They exclude internet and cross-region data transfer, surplus T3 Unlimited CPU credits, taxes, and separately enabled services such as GuardDuty, CloudTrail data events, or additional logging. T3 surplus CPU credits can add charges under sustained load. Stopping an instance does not delete its EBS volume; use the documented Terraform teardown to remove the lab resources.

### Free Tier and credits

Eligible **AWS Free Tier benefits or promotional credits may reduce the amount billed, potentially to nearly zero** for a short lab session. That is account-specific, not a guarantee of this repository. Eligibility, account plan, remaining allowances or credits, expiration dates, and other workloads sharing those benefits affect the final bill. Check the applicable billing and Free Tier/credit balances for both lab accounts before deployment; do not assume that two instances each receive an independent free allowance.

Pricing references: [EC2 T3](https://aws.amazon.com/ec2/instance-types/t3/), [public IPv4](https://aws.amazon.com/vpc/pricing/), [EBS](https://aws.amazon.com/ebs/pricing/), [S3](https://aws.amazon.com/s3/pricing/), and [AWS Free Tier eligibility and credits](https://aws.amazon.com/free/free-tier-faqs/). Recalculate with the [AWS Pricing Calculator](https://calculator.aws/) if you change the region, instance type, storage, or usage pattern.

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

### 0. Wait for the application and managed node

`terraform apply` finishing does not mean instance bootstrap has finished. In the deployment terminal, get the URL and Jenkins instance ID:

```bash
terraform output -raw ssrf_app_url
LAB_JENKINS_INSTANCE_ID="$(terraform output -raw jenkins_instance_id)"
aws ssm describe-instance-information \
  --profile lab-account-a --region us-east-1 \
  --filters "Key=InstanceIds,Values=${LAB_JENKINS_INSTANCE_ID}" \
  --query 'InstanceInformationList[0].PingStatus' --output text
```

Replace `lab-account-a` if your profile name differs. Open the application URL in your browser and wait until **CloudOps Fleet Health** loads. Repeat the SSM check until it returns `Online`; initial boot and registration may take several minutes. Run these checks from the network allowed by `app_ingress_cidr`. Do not run the loader until the application is ready, or the guided SSM steps until Jenkins is online.

Now open the separate **demo terminal** for the remaining steps. Keep the deployment profiles available in the original terminal for teardown.

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
if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && \
   [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && \
   [ -n "${AWS_SESSION_TOKEN:-}" ]; then
  python scripts/demo_runner_sanitized.py
else
  printf 'Load the temporary lab credentials successfully before starting the runner.\n' >&2
fi
```

Use `y` to execute the next step, `n` to skip it, and `q` to exit. The runner checks for the three temporary credential variables and warns when they are absent. The additional access-key persistence demonstration is manual and is not automated by the runner. Follow the cleanup steps even if you stop the demonstration early.

For the complete guided path, choose `y` in order. The IAM policy-inspection step is expected to return **AccessDenied** for `CloudOpsInventoryRole`; this demonstrates limited IAM introspection. That denial does not mean the lab is broken. Later steps should discover Jenkins, execute an innocuous command, read the synthetic state, assume `ProdDeployRole` in Account B, and inspect the recovery user. The runner does not grade these results or automatically stop after every AWS error; inspect each response before proceeding. A final completion message alone is not proof that all steps succeeded.

### Troubleshooting the first run

| Symptom | What to check |
|---|---|
| Profile missing, login expired, or Terraform deployment denied | Verify the two deployment profiles, renew the relevant session, and check deployment permissions and organization restrictions. Do not deploy using the temporary application credentials. |
| Existing bucket or IAM name conflict | Confirm this is a fresh sandbox and that another deployment is not using these names. Do not delete unrelated resources to make the plan succeed. |
| Application timeout or loader cannot find CloudOps | Wait for bootstrap, confirm the current application public IP/port, and compare your current public IPv4 with `app_ingress_cidr`. A VPN or network change can change the allowed source address. |
| Metadata or credential loading fails after remediation | The starting path intentionally requires `app_imds_http_tokens = "optional"`. When set to `required`, failure of this GET-only metadata path is the expected remediation result. |
| Jenkins missing, offline, or SSM command fails | Confirm the `jenkins_instance_id` from Terraform is `Online` in Account A and the expected region. If the issue persists, use the trusted deployment identity to inspect EC2 status, SSM Agent, outbound connectivity, and effective permissions. |
| Expired temporary credentials during the demo | Reload the starting credentials in the demo terminal and rerun the runner. The helper reads fresh credentials; it does not refresh them automatically. |

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
2\. Configure terraform.tfvars
|
        v
3\. terraform init
|
        v
4\. terraform plan
|
        v
5\. terraform apply
|
        v
6\. Review terraform output
|
        v
7\. Use scripts/ for the demo workflow
|
        v
8\. Validate the security observations
|
        v
9\. Clear demo credentials and use deployment profiles for teardown
|
        v
10\. terraform destroy, verify both accounts, and clear local variables
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

In the deployment terminal, also clear the local readiness-check variable:

```bash
unset LAB_JENKINS_INSTANCE_ID
```

If you set `AWS_PROFILE` or `AWS_DEFAULT_PROFILE` specifically for this session, clear them as well:

```bash
unset AWS_PROFILE AWS_DEFAULT_PROFILE
```

Close the dedicated demo terminal. Review any terminal recordings, screenshots, downloaded data, and captured output before sharing them. Remove local credential copies that you created. Keep `terraform.tfvars`, state, plans, and environment files private; only remove local state after successful teardown and verification. Do not commit these artifacts or upload them with presentation material.

---

## Defensive takeaways

The lab demonstrates how excessive permissions and overly broad trust relationships can create a chain across otherwise separate workloads and accounts. The following controls interrupt key parts of that chain without preventing legitimate operations.

| Lab path | Recommended control |
|---|---|
| SSRF → IMDS → workload credentials | Fix the SSRF vulnerability and require **IMDSv2** (`HttpTokens = required`) on EC2 instances. |
| CloudOps → Jenkins through SSM | Limit `CloudOpsInventoryRole` to its intended inventory permissions; scope `ssm:SendCommand` to approved targets and documents, or remove it where unnecessary. |
| Jenkins → Terraform state and other S3 resources | **Keep Jenkins access to the Terraform backend it legitimately needs**, but restrict the role and bucket policy to the specific state bucket, relevant object prefixes, and required actions. Avoid broad S3 read access to unrelated buckets. |
| IaC deployment → production privileges | Use dedicated deployment roles with **least-privilege permissions** for the resources each pipeline manages. Avoid persistent `AdministratorAccess` simply because a pipeline deploys a landing zone or foundational infrastructure. |
| Cross-account role assumption | Restrict the **trust policy** to explicitly authorized principals; align the caller permissions with that trust, and review access using IAM Access Analyzer. |
| Compromised credentials → persistence | Deactivate any exposed access keys, revoke affected role sessions when needed, and investigate subsequent activity and derived access. |

### Detection and response

- **CloudTrail:** correlate identities, API calls, and role sessions. Enable relevant **S3 data events** when investigating object-level access to Terraform state.
- **GuardDuty and Security Hub:** use applicable findings to identify suspicious credential activity and centralize investigation signals.
- **Containment:** detection alone is not remediation. Investigate the blast radius and address affected keys, sessions, permissions, and resources.

These are selected takeaways from the AWS Community Day session, not a complete hardening baseline. An IaC workload should retain the access required to deploy and maintain its own infrastructure; the objective is to avoid privileges beyond that scope.

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

### Conference slides

This lab accompanies **“Anatomía de un Ataque en AWS: De la Intrusión a la Defensa”**, presented at AWS Community Day Perú 2026. The presentation covers the attack chain, MITRE ATT&CK mapping, preventive controls, detection, and incident containment.

[View the conference slides (PDF)](docs/Anatom%C3%ADa%20de%20un%20Ataque%20en%20AWS%20-%20Community%20Day%202026.pdf)

Official AWS Community Day page:

https://aws.amazon.com/events/community-day/

---

## License

Copyright (c) 2026 RedCaraxes. The original code and documentation in this repository are licensed under the [MIT License](LICENSE). You may use, modify, and redistribute them under its terms, including preservation of the copyright and license notices.

AWS names, logos, and other third-party materials remain the property of their respective owners and are not covered by this license. This community-created project is not an official AWS product and does not imply endorsement or sponsorship by Amazon Web Services.

## Disclaimer

This repository is provided for **educational and authorized security testing purposes only**.

The lab intentionally includes a vulnerable application, excessive IAM permissions, and cross-account access paths. Deploy it only in dedicated, disposable AWS sandbox accounts that you own or have explicit permission to test. Keep production workloads, real customer data, and unrelated credentials outside the lab.

Permission to use this code does not grant permission to access or test any AWS account, system, or data. You are responsible for obtaining authorization, defining the test scope, and complying with applicable laws and service terms.

Deploying the lab can incur AWS charges. You are responsible for reviewing the Terraform plan, controlling exposure and access, monitoring costs, and completing the [cleanup procedure](#cleanup), including removal of manually created access keys and local credential copies. Stopping a script or closing a terminal does not destroy the infrastructure.

The software is provided **as is**, without warranty, under the terms of the [MIT License](LICENSE). The demonstrations and suggested remediations are educational examples, not a security assessment or assurance that an environment is secure. Account-ID masking is limited; review all output before publishing recordings or write-ups.

---

<p align="center">

  <b>Built for hands-on AWS security learning.</b><br/>

  Infrastructure as Code · AWS · Terraform · Security

</p>
