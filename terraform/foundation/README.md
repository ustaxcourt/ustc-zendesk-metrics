# Foundation Stack

This directory contains the environment-specific roots for the "foundation" layer.

## Why a separate foundation directory and state key?

- **Faster plans and applies**
  App (Lambdas/API Gateway) iterates frequently. Separating state keeps those plans small and fast.

- **Safer rollbacks**
  App rollbacks (workloads) don’t affect IAM policies.

## State layout (per environment)

- Bucket (dev): `zendesk-metrics-dev-terraform-state`
- Key (foundation): `zendesk-metrics/foundation.tfstate`
- Lock table: `zendesk-metrics-terraform-locks-dev`

You will use analogous buckets/keys for `stg` and `prod`.

## Directory structure here

- `foundation/`
  - `backend.hcl` — points to the dev foundational state key
  - `main.tf` — composes the iam module with explicit values for dev
  - `outputs.tf` — re-exports module outputs for easy consumption by CI or other stacks

## Using foundation/dev (dev)

Prerequisites:

- Terraform initialized with the backend bootstrap (S3 bucket + DynamoDB table created)
- Authenticated to the dev AWS account (e.g., SSO profile)

Steps:

```bash
# Authenticate (example with AWS SSO)
export AWS_PROFILE=zendesk-metrics-dev

aws sso login

# Navigate to the dev foundation root (sets up iam policies)
cd terraform/foundation

# Initialize the backend (uses backend.hcl) and specify bucket that corresponds with environment
terraform init -backend-config=backend.hcl -reconfigure -backend-config="bucket=zendesk-metrics-dev-terraform-state"
```

## What this creates

- Lambda Security Group (permissive for parity; harden later)

## IAM Module

This is needed to grant Lambda permissions to create CloudWatch logs and Permissions.

These will be used later by the workloads stack (Lambdas/API).
