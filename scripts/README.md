# Guided challenge scripts

These scripts support the AWS Organization Security Lab presented at Community Day 2026. For an independent CTF-style attempt, start with the [challenge and optional hints](../README.md#the-challenge) before reading or running the scripts: their source contains the intended solution path.

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

The current sequence assumes `us-east-1`, the default Terraform bucket names, `CloudOpsInventoryRole`, `ProdDeployRole`, and `OperationsRecoveryUser`. Keep these settings aligned with the deployed lab. One S3 enumeration step intentionally uses `us-east-2`; this is a visibility discussion, not a change to the deployment region.

### Controls

```bash
python scripts/demo_runner_sanitized.py
```

- `y`: reveal and execute the next step.
- `n`: skip that step; skipping prerequisites can make later steps fail.
- `q`: exit. Resources and credentials still need cleanup.

The sequence covers starting-identity validation, a denied IAM inspection, EC2 and SSM discovery, harmless commands on Jenkins, the Jenkins identity, S3 enumeration, a synthetic state artifact, cross-account role assumption, and production role and recovery-user inspection. It sends real SSM commands to your lab instances. It does not create a persistence access key, download the synthetic customer export, or perform teardown.

### What “sanitized” means

The configured account IDs are replaced with `ACCOUNT_A` and `ACCOUNT_B` in command displays and captured output passed through `sanitize()`. Resource names used by the commands are built from the actual environment variables; masking affects displayed text only.

This is limited redaction. IPs, instance IDs, usernames, bucket names without those account strings, command IDs, other account IDs, and unexpected secrets may remain visible. The script does not modify AWS records, files, or terminal recordings. Review and redact output before sharing it.

## `load-cloudops-creds.py`

The helper takes the deployed application public IP, detects its HTTP port, and uses the lab's intentionally vulnerable fetcher to obtain the starting instance-role credentials. It emits Bash `export` statements on stdout and progress messages on stderr.

Its stdout contains secrets. Use the capture-and-evaluate procedure in the [main README](../README.md#running-the-demo-scripts), with shell tracing disabled, in a dedicated Bash or Git Bash terminal. Running it directly displays the credentials. Its output is not PowerShell syntax.

## Finish every session

Follow the [full cleanup procedure](../README.md#cleanup): unset temporary credentials in each demo shell, remove any manually created persistence key, destroy the lab using the original deployment profiles and state, and clear the remaining lab variables. Quitting the runner does not perform any of these actions. Unsetting local variables does not revoke credentials issued by AWS.
