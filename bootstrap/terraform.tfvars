# Bootstrap infrastructure variables
# S3 bucket name for Terraform state (must be globally unique)
state_bucket_name = "craftista-infra-state-bucket"

# DynamoDB table name for state locking
dynamodb_table_name = "craftista-infra-state-locks"

# IAM policy name for Terraform state access
iam_policy_name = "TerraformStatePolicy"

# AWS region for bootstrap resources
aws_region = "us-east-1"

# Additional tags for all resources
tags = {
  Project     = "craftista"
  Environment = "bootstrap"
  Owner       = "Obinna Iheanacho"
  Department  = "devops"
  Backup      = "required"
  Monitoring  = "enabled"
}