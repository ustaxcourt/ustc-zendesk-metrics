# Terraform Backend Bootstrap

This directory contains the Terraform configuration to bootstrap the S3 backend and DynamoDB table for state management.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Install Terraform matching the constraint in bootstrap/main.tf
- Permissions to create S3 buckets, DynamoDB tables, and IAM policies

## Bootstrap Process

### 1. Initialize and Apply Bootstrap Configuration

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

This will create:

- S3 bucket: `zendesk-metrics-dev-terraform-state`
- DynamoDB table: `zendesk-metrics-terraform-locks`
- Make sure to change the default values for state bucket name and lock table name in bootstrap/variables.tf before making this change for staging or Prod.
- IAM policy for backend access

### 2. Initialize Environment Configurations

After the backend infrastructure is created, initialize each environment:

#### Environment Deploy

cd ../environments
terraform init -backend-config=backend.hcl
terraform plan (Should show 0 Changes)
terraform apply

## Verify the backend

Confirm Terraform is now using remote backend:
jq '.backend | {type: .type, config: .config}' .terraform/terraform.tfstate

# type should be "s3", config.bucket/key should match above

or Go to the bucket in the AWS Account and there should be a .tfstate object created

## Remove local tfstate

Remove the .terraform/ and .tfstate in bootstrap/ once you can verify Terraform is using remote backend.
