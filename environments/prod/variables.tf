# Production Environment - Variable Definitions

#######################################
# Project Configuration
#######################################
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(us|eu|ap|sa|ca|me|af)-(north|south|east|west|central)-[1-3]$", var.aws_region))
    error_message = "AWS region must be a valid region name (e.g. us-east-1, eu-west-1)."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "craftista"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "owner_email" {
  description = "Email of the resource owner for tagging and billing alerts"
  type        = string
  default     = "iheanachocharlie@example.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Owner email must be a valid email address."
  }
}

#######################################
# Network Configuration
#######################################
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

# Additional CIDRs for EKS cluster access (e.g., corporate VPN, bastion hosts)
# Default empty is intentional - access controlled via IAM authentication and security groups
# GitHub Actions authenticate via OIDC/IRSA, not IP-based whitelisting
variable "additional_allowed_cidrs" {
  description = "Additional CIDR blocks allowed to access EKS cluster (e.g., office IPs, CI/CD)"
  type        = list(string)
  default     = []
  # Example: ["203.0.113.0/24"] for corporate VPN access
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to S3"
  type        = bool
  default     = true
}

variable "enable_ecr_endpoints" {
  description = "Enable ECR VPC endpoints (set to false if using Docker Hub instead of ECR)"
  type        = bool
  default     = false
}

#######################################
# EKS Configuration
#######################################
variable "kubernetes_version" {
  description = "Kubernetes version to use for EKS cluster"
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^1\\.(2[6-9]|[3-9][0-9])$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.26 or higher."
  }
}

variable "node_ami_type" {
  description = "Type of AMI for EKS nodes"
  type        = string
  default     = "AL2_x86_64"

  validation {
    condition     = contains(["AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64", "BOTTLEROCKET_x86_64", "BOTTLEROCKET_ARM_64"], var.node_ami_type)
    error_message = "Invalid AMI type specified."
  }
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "enable_ssm" {
  description = "Enable AWS Systems Manager Session Manager for secure node access without SSH keys"
  type        = bool
  default     = true
}

#######################################
# Node Groups Configuration
#######################################
variable "node_groups" {
  description = "EKS managed node group configurations"
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = string
    disk_size      = number
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))

  default = {
    main = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      taints         = []
    }
  }

  validation {
    condition     = alltrue([for ng in var.node_groups : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size])
    error_message = "Node group sizes must satisfy: min_size <= desired_size <= max_size."
  }

  validation {
    condition     = alltrue([for ng in var.node_groups : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}



#######################################
# Monitoring Configuration
#######################################
variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms (leave empty to disable notifications)"
  type        = string
  default     = ""
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for EKS"
  type        = bool
  default     = true
}

#######################################
# Cost Management
#######################################
variable "budget_amount" {
  description = "Monthly budget amount in USD for cost alerts"
  type        = number
  default     = 10

  validation {
    condition     = var.budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "budget_email" {
  description = "Email address for budget alerts"
  type        = string
  default     = "iheanachocharlie@gmail.com"
}

#######################################
# Backup Configuration
#######################################
variable "enable_automated_backups" {
  description = "Enable automated EBS snapshots for node volumes"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention must be between 1 and 35 days."
  }
}

#######################################
# RDS PostgreSQL Configuration
#######################################
variable "rds_instance_class" {
  description = "RDS instance class for PostgreSQL"
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.(t3|t4g|r5|r6g|m5|m6g)\\.(micro|small|medium|large|xlarge|2xlarge)$", var.rds_instance_class))
    error_message = "RDS instance class must be a valid instance type."
  }
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.rds_allocated_storage >= 20 && var.rds_allocated_storage <= 65536
    error_message = "RDS allocated storage must be between 20 and 65536 GB."
  }
}

variable "rds_max_allocated_storage" {
  description = "Maximum storage for RDS autoscaling in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.rds_max_allocated_storage >= 20
    error_message = "Max allocated storage must be at least 20 GB."
  }
}

variable "rds_backup_retention_period" {
  description = "Backup retention period for RDS in days"
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_period >= 1 && var.rds_backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

variable "rds_multi_az" {
  description = "Enable multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"

  validation {
    condition     = can(regex("^(14|15|16)\\.[0-9]+$", var.rds_engine_version))
    error_message = "PostgreSQL version must be 14.x, 15.x, or 16.x."
  }
}

variable "rds_database_name" {
  description = "Name of the default database"
  type        = string
  default     = "craftista"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "craftista_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.rds_master_username))
    error_message = "Username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
  default     = false
}

#######################################
# ElastiCache Redis Configuration
#######################################
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t4g.micro"

  validation {
    condition     = can(regex("^cache\\.(t3|t4g|r5|r6g|m5|m6g)\\.(micro|small|medium|large|xlarge|2xlarge)$", var.redis_node_type))
    error_message = "Redis node type must be a valid cache instance type."
  }
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes for Redis cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.redis_num_cache_nodes >= 1 && var.redis_num_cache_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6."
  }
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"

  validation {
    condition     = can(regex("^(6\\.2|7\\.[0-9]+)$", var.redis_engine_version))
    error_message = "Redis version must be 6.2 or 7.x."
  }
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"

  validation {
    condition     = contains(["redis6.x", "redis7"], var.redis_parameter_group_family)
    error_message = "Parameter group family must be redis6.x or redis7."
  }
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover for Redis"
  type        = bool
  default     = true
}

variable "redis_multi_az_enabled" {
  description = "Enable multi-AZ for Redis"
  type        = bool
  default     = true
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain Redis snapshots"
  type        = number
  default     = 5

  validation {
    condition     = var.redis_snapshot_retention_limit >= 0 && var.redis_snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days."
  }
}

#######################################
# DocumentDB (MongoDB-compatible) Configuration
#######################################
variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"

  validation {
    condition     = can(regex("^db\\.(t3|t4g|r5|r6g|r6i)\\.(medium|large|xlarge|2xlarge|4xlarge|8xlarge|12xlarge|16xlarge)$", var.docdb_instance_class))
    error_message = "DocumentDB instance class must be a valid instance type."
  }
}

variable "docdb_instance_count" {
  description = "Number of DocumentDB instances in the cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.docdb_instance_count >= 1 && var.docdb_instance_count <= 16
    error_message = "DocumentDB instance count must be between 1 and 16."
  }
}

variable "docdb_engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"

  validation {
    condition     = can(regex("^(4\\.0\\.0|5\\.0\\.0)$", var.docdb_engine_version))
    error_message = "DocumentDB version must be 4.0.0 or 5.0.0."
  }
}

variable "docdb_master_username" {
  description = "Master username for DocumentDB"
  type        = string
  default     = "craftista_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.docdb_master_username))
    error_message = "Username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "docdb_backup_retention_period" {
  description = "Backup retention period for DocumentDB in days"
  type        = number
  default     = 7

  validation {
    condition     = var.docdb_backup_retention_period >= 1 && var.docdb_backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

variable "docdb_preferred_backup_window" {
  description = "Preferred backup window for DocumentDB"
  type        = string
  default     = "03:00-04:00"
}

variable "docdb_preferred_maintenance_window" {
  description = "Preferred maintenance window for DocumentDB"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "docdb_skip_final_snapshot" {
  description = "Skip final snapshot when destroying DocumentDB cluster"
  type        = bool
  default     = false
}

variable "docdb_deletion_protection" {
  description = "Enable deletion protection for DocumentDB cluster"
  type        = bool
  default     = true
}

#######################################
# DevOps Tools Variables
#######################################

variable "key_name" {
  description = "EC2 Key Pair name for SSH access to DevOps tools"
  type        = string
  default     = "craftista-prod-key"
}

variable "sonarqube_instance_type" {
  description = "Instance type for SonarQube"
  type        = string
  default     = "t3.large"
}

variable "nexus_instance_type" {
  description = "Instance type for Nexus"
  type        = string
  default     = "t3.large"
}

variable "sonarqube_data_volume_size" {
  description = "Size of SonarQube data volume in GB"
  type        = number
  default     = 100
}

variable "nexus_data_volume_size" {
  description = "Size of Nexus data volume in GB"
  type        = number
  default     = 200
}
