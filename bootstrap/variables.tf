# Variables for bootstrap infrastructure

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state storage"
  type        = string
  default     = "craftista-infra-state-bucket"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be lowercase, contain only letters, numbers, and hyphens, and not start or end with a hyphen."
  }

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "Bucket name must be between 3 and 63 characters long."
  }
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "craftista-infra-state-locks"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]+$", var.dynamodb_table_name))
    error_message = "DynamoDB table name can only contain letters, numbers, underscores, periods, and hyphens."
  }

  validation {
    condition     = length(var.dynamodb_table_name) >= 3 && length(var.dynamodb_table_name) <= 255
    error_message = "DynamoDB table name must be between 3 and 255 characters long."
  }
}

variable "iam_policy_name" {
  description = "Name of the IAM policy for Terraform state access"
  type        = string
  default     = "TerraformStatePolicy"

  validation {
    condition     = can(regex("^[a-zA-Z0-9+=,.@_-]+$", var.iam_policy_name))
    error_message = "IAM policy name can only contain alphanumeric characters and the following: +=,.@_-"
  }

  validation {
    condition     = length(var.iam_policy_name) >= 1 && length(var.iam_policy_name) <= 128
    error_message = "IAM policy name must be between 1 and 128 characters long."
  }
}

variable "aws_region" {
  description = "AWS region for the bootstrap resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources. Recommended tags: Project, Environment, Owner, CostCenter, Department, Backup, Monitoring"
  type        = map(string)
  default     = {}

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Cannot specify more than 50 tags (AWS limit)."
  }

  validation {
    condition = alltrue([
      for key, value in var.tags : length(key) <= 128 && length(value) <= 256
    ])
    error_message = "Tag keys must be 128 characters or less, and values must be 256 characters or less."
  }
}


