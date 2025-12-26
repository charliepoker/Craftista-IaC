variable "aws_region" {
  description = "AWS region for dev environment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "craftista"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.1.101.0/24", "10.1.102.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.1.201.0/24", "10.1.202.0/24"]
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "node_groups" {
  description = "EKS node groups configuration"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
  }))
  default = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 4
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
    }
  }
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "RDS PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
  default     = "craftista_admin"
  sensitive   = true
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "rds_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover for Redis"
  type        = bool
  default     = false
}

variable "docdb_engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "docdb_instance_class" {
  description = "DocumentDB instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "docdb_num_instances" {
  description = "Number of DocumentDB instances"
  type        = number
  default     = 1
}

variable "docdb_master_username" {
  description = "DocumentDB master username"
  type        = string
  default     = "craftista_admin"
  sensitive   = true
}

variable "docdb_master_password" {
  description = "DocumentDB master password"
  type        = string
  sensitive   = true
}

variable "docdb_backup_retention_period" {
  description = "DocumentDB backup retention period"
  type        = number
  default     = 7
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 5
}

variable "budget_email" {
  description = "Email for budget notifications"
  type        = string
  default     = "admin@example.com"
}

variable "owner_email" {
  description = "Owner email"
  type        = string
  default     = "iheanachocharlie@gmail.com"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "craftista"
    ManagedBy   = "terraform"
  }
}

#######################################
# DevOps Tools Variables
#######################################

variable "key_name" {
  description = "EC2 Key Pair name for SSH access to DevOps tools"
  type        = string
  default     = "craftista-dev-key"
}

variable "sonarqube_instance_type" {
  description = "Instance type for SonarQube"
  type        = string
  default     = "t3.medium"
}

variable "nexus_instance_type" {
  description = "Instance type for Nexus"
  type        = string
  default     = "t3.medium"
}

variable "sonarqube_data_volume_size" {
  description = "Size of SonarQube data volume in GB"
  type        = number
  default     = 50
}

variable "nexus_data_volume_size" {
  description = "Size of Nexus data volume in GB"
  type        = number
  default     = 100
}
