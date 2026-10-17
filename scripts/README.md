# Guided challenge scripts

These scripts support the AWS Organization Security Lab presented at Community Day 2026. For an independent CTF-style attempt, start with the [challenge and optional hints](../README.md#the-challenge) before reading or running the scripts: their source contains the intended solution path.

## Install prerequisites

Install these tools on the computer where you will run the demo:

| Tool | Why it is needed | Installation |
|---|---|---|
| Python 3 | Runs both scripts. The scripts have been checked with Python 3.12. | Use the [official Python downloads](https://www.python.org/downloads/) and make the interpreter available on your terminal's `PATH`. |
| AWS CLI v2 | The runner launches the `aws` executable through Python's `subprocess` module. | Follow the [official AWS CLI installation instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) for your operating system. |
| Bash or Git Bash | Loads the credential helper's Bash `export` statements and runs the documented `read`, `eval`, and `unset` commands. | Use Bash on Linux/macOS, or install [Git for Windows](https://git-scm.com/downloads/win) and open Git Bash on Windows. |

**No Python packages need to be installed with `pip`. Neither script uses `boto3` or `botocore`.** Both use only Python's standard library: `json`, `os`, `re`, `shlex`, `subprocess`, `sys`, `time`, `html`, and `urllib`. Installing `boto3` does not replace the separate AWS CLI installation. A virtual environment is optional; there is no third-party Python dependency list for these scripts.

Open a new Bash or Git Bash terminal after installing the tools, then verify:

```bash
python --version
aws --version
bash --version
command -v python
command -v aws
python -c "import json, os, re, shlex, subprocess, sys, time, html, urllib.parse, urllib.request; print('Python standard-library imports: OK')"
```

Use `python3` consistently instead of `python` if that is your working interpreter command. On Windows, if `python` opens the Microsoft Store or is not found, use your installed interpreter and correct its `PATH` or execution alias before continuing. If `aws` is not found, reopen the terminal and check the AWS CLI installation and `PATH`.

Terraform is required to **deploy and destroy** the lab, not to execute these Python scripts. Complete the [deployment instructions](../README.md#deploy-the-infrastructure) first, using the two configured deployment profiles. The scripts then need the application to be reachable from your allowed public IP and the account/session variables described below. They do not require an AWS MCP server.

## `demo_runner_sanitized.py`

The runner is an interactive walkthrough for participants and presenters. It executes a predefined AWS CLI command sequence rather than discovering a solution automatically. It does not deploy the infrastructure, load the starting credentials, grade milestones, or submit flags.

### Inputs

Run from the repository root with Python 3 and AWS CLI available in the same terminal. Follow the [credential-loading instructions](../README.md#running-the-demo-scripts) first.

| Input | Purpose |
|---|---|
| `LAB_ACCOUNT_A_ID` | Required 12-digit Account A ID; used to build the default tfstate bucket name. |
| `LAB_ACCOUNT_B_ID` | Required 12-digit Account B ID; used to build the production role ARN. |
| `AWS_ACCESS_KEY_ID` | Temporary starting identity loaded by the credential helper. |
| `AWS_SECRET_ACCESS_KEY` | Secret key for that temporary identity. |
| `AWS_SESSION_TOKEN` | Session token for that temporary identity. |

The runner exits when either account ID is missing or malformed. Missing credential variables produce a warning, not a hard stop; load the intended application credentials before continuing so AWS CLI does not use another configured identity.

The current sequence assumes `us-east-1`, the default Terraform bucket names, `CloudOpsInventoryRole`, `ProdDeployRole`, and `OperationsRecoveryUser`. Keep these settings aligned with the deployed lab. Wait for the application to load and the Jenkins managed node to report `Online`, following the [readiness checks](../README.md#0-wait-for-the-application-and-managed-node), before starting. One S3 enumeration step intentionally uses `us-east-2`; this is a visibility discussion, not a change to the deployment region.

### Controls

```bash
python scripts/demo_runner_sanitized.py
```

- `y`: reveal and execute the next step.
- `n`: skip that step; skipping prerequisites can make later steps fail.
- `q`: exit. Resources and credentials still need cleanup.

The sequence covers starting-identity validation, a denied IAM inspection, EC2 and SSM discovery, harmless commands on Jenkins, the Jenkins identity, S3 enumeration, a synthetic state artifact, cross-account role assumption, and production role and recovery-user inspection. It sends real SSM commands to your lab instances. It does not create a persistence access key, download the synthetic customer export, or perform teardown.

Choose `y` in order for the full walkthrough. The denied IAM inspection is expected; inspect later command responses for success. The runner can continue after AWS errors and does not grade the result, so its final completion message is not evidence that the entire path worked. See the [first-run troubleshooting guide](../README.md#troubleshooting-the-first-run) for setup failures and expired sessions.

### What “sanitized” means

The configured account IDs are replaced with `ACCOUNT_A` and `ACCOUNT_B` in command displays and captured output passed through `sanitize()`. Resource names used by the commands are built from the actual environment variables; masking affects displayed text only.

This is limited redaction. IPs, instance IDs, usernames, bucket names without those account strings, command IDs, other account IDs, and unexpected secrets may remain visible. The script does not modify AWS records, files, or terminal recordings. Review and redact output before sharing it.

## `load-cloudops-creds.py`

The helper takes the deployed application public IP, detects its HTTP port, and uses the lab's intentionally vulnerable fetcher to obtain the starting instance-role credentials. It emits Bash `export` statements on stdout and progress messages on stderr.

Pass the public IP only, without `http://`, a port, or a path. Autodetection checks ports 80, 8080, 8000, and 5000; use the default lab port of 8080 for the documented walkthrough. Credential loading is expected to fail after the IMDSv2 remediation (`app_imds_http_tokens = "required"`). Temporary credentials expire; rerun the capture-and-evaluate procedure if needed during a longer session.

Its stdout contains secrets. Use the capture-and-evaluate procedure in the [main README](../README.md#running-the-demo-scripts), with shell tracing disabled, in a dedicated Bash or Git Bash terminal. Running it directly displays the credentials. Its output is not PowerShell syntax.

## Finish every session

Follow the [full cleanup procedure](../README.md#cleanup): unset temporary credentials in each demo shell, remove any manually created persistence key, destroy the lab using the original deployment profiles and state, and clear the remaining lab variables. Quitting the runner does not perform any of these actions. Unsetting local variables does not revoke credentials issued by AWS.
