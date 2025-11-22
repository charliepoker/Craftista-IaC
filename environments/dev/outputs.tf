# Development Environment - Outputs

#######################################
# VPC Outputs
#######################################
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

#######################################
# EKS Cluster Outputs
#######################################
output "eks_cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = module.eks.cluster_version
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = module.eks.oidc_provider_arn
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}

#######################################
# EKS Node Group Outputs
#######################################
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
}

#######################################
# Launch Template Outputs
#######################################
output "launch_template_id" {
  description = "ID of the launch template for EKS nodes"
  value       = aws_launch_template.eks_nodes.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.eks_nodes.latest_version
}

#######################################
# Kubectl Configuration Output
#######################################
output "kubectl_access" {
  value = <<-EOT
  Configure kubectl with these commands:
  
  aws eks update-kubeconfig \\
    --name ${module.eks.cluster_name} \\
    --region ${var.aws_region}
    
  Test cluster access:
  kubectl get nodes
  EOT
}

output "current_user_ip" {
  value       = "${chomp(data.http.user_ip.response_body)}/32"
  description = "IP address used for cluster access"
}

#######################################
# RDS PostgreSQL Outputs
#######################################
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL address (hostname)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS PostgreSQL database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_master_username" {
  description = "RDS PostgreSQL master username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

output "rds_master_password" {
  description = "RDS master password (sensitive - store securely)"
  value       = random_password.rds_master_password.result
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.postgres.id
}

#######################################
# ElastiCache Redis Outputs
#######################################
output "redis_primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_token" {
  description = "Redis AUTH token (sensitive - store securely)"
  value       = random_password.redis_auth_token.result
  sensitive   = true
}

output "redis_replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

#######################################
# DocumentDB Outputs
#######################################
output "docdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "docdb_cluster_reader_endpoint" {
  description = "DocumentDB cluster reader endpoint"
  value       = aws_docdb_cluster.main.reader_endpoint
}

output "docdb_cluster_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.main.port
}

output "docdb_cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.main.cluster_identifier
}

output "docdb_master_username" {
  description = "DocumentDB master username"
  value       = aws_docdb_cluster.main.master_username
  sensitive   = true
}

output "docdb_master_password" {
  description = "DocumentDB master password (sensitive - store securely)"
  value       = random_password.docdb_master_password.result
  sensitive   = true
}

output "docdb_instance_endpoints" {
  description = "List of DocumentDB instance endpoints"
  value       = aws_docdb_cluster_instance.main[*].endpoint
}

#######################################
# VPC Endpoints Outputs
#######################################
output "vpc_endpoint_s3_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

# output "vpc_endpoint_ecr_api_id" {
#   description = "ECR API VPC Endpoint ID"
#   value       = aws_vpc_endpoint.ecr_api.id
# }

# output "vpc_endpoint_ecr_dkr_id" {
#   description = "ECR Docker VPC Endpoint ID"
#   value       = aws_vpc_endpoint.ecr_dkr.id
# }

output "vpc_endpoint_logs_id" {
  description = "CloudWatch Logs VPC Endpoint ID"
  value       = aws_vpc_endpoint.logs.id
}

output "vpc_endpoint_ssm_id" {
  description = "SSM VPC Endpoint ID"
  value       = var.enable_ssm ? aws_vpc_endpoint.ssm[0].id : null
}

output "vpc_endpoint_ssmmessages_id" {
  description = "SSM Messages VPC Endpoint ID"
  value       = var.enable_ssm ? aws_vpc_endpoint.ssmmessages[0].id : null
}

output "vpc_endpoint_ec2messages_id" {
  description = "EC2 Messages VPC Endpoint ID"
  value       = var.enable_ssm ? aws_vpc_endpoint.ec2messages[0].id : null
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

#######################################
# Database Security Group Output
#######################################
output "database_security_group_id" {
  description = "Security group ID for database resources (RDS, Redis, DocumentDB)"
  value       = aws_security_group.database.id
}

#######################################
# Connection Information
#######################################
output "connection_info" {
  description = "Database connection information summary"
  value       = <<-EOT
  
  ===========================================
  CRAFTISTA DEVELOPMENT ENVIRONMENT
  ===========================================
  
  PostgreSQL:
    Host: ${aws_db_instance.postgres.address}
    Port: ${aws_db_instance.postgres.port}
    Database: ${aws_db_instance.postgres.db_name}
    Username: ${aws_db_instance.postgres.username}
    
  Redis:
    Host: ${aws_elasticache_replication_group.redis.primary_endpoint_address}
    Port: ${aws_elasticache_replication_group.redis.port}
    Auth: Required (see redis_auth_token output)
    
  DocumentDB:
    Host: ${aws_docdb_cluster.main.endpoint}
    Port: ${aws_docdb_cluster.main.port}
    Username: ${aws_docdb_cluster.main.master_username}
    
  EKS Cluster:
    Name: ${module.eks.cluster_name}
    Endpoint: ${module.eks.cluster_endpoint}
    Version: ${module.eks.cluster_version}
  
  ===========================================
  Use 'terraform output -json' to get sensitive values
  ===========================================
  EOT
}
