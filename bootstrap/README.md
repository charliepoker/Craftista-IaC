# Terraform Bootstrap Infrastructure

This directory contains the bootstrap infrastructure needed to set up remote state management for the Craftista's eks infrastructure Terraform configurations.

## Purpose

The bootstrap infrastructure creates:

- S3 bucket for storing Terraform state files
- DynamoDB table for state locking
- IAM policy for secure access to state resources

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0 installed
- Sufficient AWS permissions to create S3, DynamoDB, and IAM resources

## Usage

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

- `state_bucket_name`: Must be globally unique across all AWS accounts
- `aws_region`: AWS region where you want to create the resources
- Other variables as needed

### 2. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 3. Note the Outputs

After successful deployment, note the outputs:

- `state_bucket_name`: Use this in your environment backend configurations
- `dynamodb_table_name`: Use this for state locking
- `backend_config`: Template configuration for environment setups

## Resources Created

### S3 Bucket

- **Purpose**: Store Terraform state files
- **Features**:
  - Versioning enabled
  - Server-side encryption (AES256)
  - Public access blocked
  - Proper tagging

### DynamoDB Table

- **Purpose**: State locking to prevent concurrent modifications
- **Configuration**:
  - Pay-per-request billing
  - Hash key: `LockID`
  - Proper tagging

### IAM Policy

- **Purpose**: Define permissions for accessing state resources
- **Permissions**:
  - S3 bucket list and versioning access
  - S3 object read/write/delete
  - DynamoDB item operations for locking

## Security Considerations

- The S3 bucket has public access completely blocked
- Server-side encryption is enabled on the bucket
- IAM policy follows least-privilege principles
- All resources are properly tagged for governance

## Next Steps

After running the bootstrap:

1. Use the output values to configure backend settings in your environment configurations
2. The `backend_config` output provides a template for your environment `backend.tf` files
3. Attach the created IAM policy to users/roles that need to manage Terraform state

## Cleanup

To destroy the bootstrap infrastructure:

```bash
terraform destroy
```

**Warning**: Only destroy this infrastructure if you're sure no environments are using the state bucket and DynamoDB table.

## Troubleshooting

### Bucket Name Already Exists

If you get an error about the bucket name already existing, change the `state_bucket_name` variable to something unique.

### Insufficient Permissions

Ensure your AWS credentials have permissions to create:

- S3 buckets and bucket policies
- DynamoDB tables
- IAM policies

### Region Considerations

Make sure to use the same region for bootstrap and your main infrastructure to minimize latency and costs.
