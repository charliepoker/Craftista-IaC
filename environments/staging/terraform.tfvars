# Staging Environment - Variables
# General Configuration
aws_region   = "us-east-1"
project_name = "craftista"
environment  = "staging"

# Network Configuration - Staging CIDR range
vpc_cidr              = "10.2.0.0/16"
availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs   = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs  = ["10.2.10.0/24", "10.2.20.0/24", "10.2.30.0/24"]
database_subnet_cidrs = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]

# EKS Configuration - Production-like setup for testing
kubernetes_version = "1.30"
node_ami_type      = "AL2_x86_64"
enable_irsa        = true
enable_ssm         = true # Enable SSM Session Manager for secure node access

# Node Groups Configuration - Production-like for staging
node_groups = {
  main = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 4
    desired_size   = 2
    capacity_type  = "SPOT"
    disk_size      = 20
    taints         = []
  }
}

# Database Configuration - Production-like for testing
rds_instance_class          = "db.t4g.small"
rds_allocated_storage       = 50
rds_max_allocated_storage   = 100
rds_backup_retention_period = 3
rds_multi_az                = false
rds_skip_final_snapshot     = true

# Redis Configuration - Minimal setup
redis_node_type                  = "cache.t4g.micro"
redis_num_cache_nodes            = 1
redis_automatic_failover_enabled = false
redis_multi_az_enabled           = false
redis_snapshot_retention_limit   = 1

# DocumentDB Configuration - Single instance
docdb_instance_class          = "db.t3.medium"
docdb_instance_count          = 1
docdb_backup_retention_period = 1
docdb_skip_final_snapshot     = true
docdb_deletion_protection     = false

# Monitoring & Cost Management
enable_container_insights = false
enable_vpc_flow_logs      = true
enable_automated_backups  = true
budget_amount             = 50
