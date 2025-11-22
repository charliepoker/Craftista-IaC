# Production Environment - Outputs

######################################
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

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "database_subnets" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_cidrs" {
  description = "List of database subnet CIDR blocks"
  value       = module.vpc.database_subnets_cidr_blocks
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

output "eks_cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = module.eks.cluster_platform_version
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

output "eks_cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by the EKS cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}


output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
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

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
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

output "launch_template_name" {
  description = "Name of the launch template"
  value       = aws_launch_template.eks_nodes.name
}

#######################################
# Auto-scaling Configuration Outputs
#######################################
output "node_group_scaling_config" {
  description = "Auto-scaling configuration for the main node group"
  value = {
    min_size     = 2
    max_size     = 10
    desired_size = 3
  }
}

output "cluster_autoscaler_enabled" {
  description = "Whether cluster autoscaler is enabled via tags"
  value       = true
}

#######################################
# EKS Add-ons Outputs
#######################################
output "eks_cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value       = module.eks.cluster_addons
}

#######################################
# IP Kubectl Configuration Output
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

#######################################
# IP Adress Output
#######################################
output "current_user_ip" {
  value       = "${chomp(data.http.user_ip.response_body)}/32"
  description = "IP address used for cluster access"
}

#######################################
# IAM Role Outputs
#######################################
output "eks_cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

#######################################
# KMS Key Outputs
#######################################
output "flow_logs_kms_key_id" {
  description = "KMS key ID for VPC Flow Logs S3 bucket encryption"
  value       = var.enable_vpc_flow_logs ? aws_kms_key.flow_logs[0].key_id : null
}

output "flow_logs_kms_key_arn" {
  description = "KMS key ARN for VPC Flow Logs S3 bucket encryption"
  value       = var.enable_vpc_flow_logs ? aws_kms_key.flow_logs[0].arn : null
}

output "eks_kms_key_id" {
  description = "KMS key ID for EKS cluster encryption"
  value       = aws_kms_key.eks.key_id
}

output "eks_kms_key_arn" {
  description = "KMS key ARN for EKS cluster encryption"
  value       = aws_kms_key.eks.arn
}

#######################################
# Vault Infrastructure Outputs
#######################################
output "vault_kms_key_id" {
  description = "KMS key ID for Vault auto-unseal"
  value       = aws_kms_key.vault.key_id
}

output "vault_kms_key_arn" {
  description = "KMS key ARN for Vault auto-unseal"
  value       = aws_kms_key.vault.arn
}

output "vault_iam_role_arn" {
  description = "IAM role ARN for HashiCorp Vault (for IRSA)"
  value       = aws_iam_role.vault.arn
}

output "vault_security_group_id" {
  description = "Security group ID for HashiCorp Vault"
  value       = aws_security_group.vault.id
}

output "vault_storage_bucket_name" {
  description = "S3 bucket name for Vault storage backend"
  value       = aws_s3_bucket.vault_storage.id
}

output "vault_storage_bucket_arn" {
  description = "S3 bucket ARN for Vault storage backend"
  value       = aws_s3_bucket.vault_storage.arn
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

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.postgres.id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.postgres.arn
}

output "rds_master_password" {
  description = "RDS master password (sensitive - store securely)"
  value       = random_password.rds_master_password.result
  sensitive   = true
}

output "rds_kms_key_id" {
  description = "KMS key ID for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "rds_kms_key_arn" {
  description = "KMS key ARN for RDS encryption"
  value       = aws_kms_key.rds.arn
}

#######################################
# ElastiCache Redis Outputs
#######################################
output "redis_primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint address"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_configuration_endpoint" {
  description = "Redis configuration endpoint (for cluster mode)"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "redis_member_clusters" {
  description = "List of Redis cluster member IDs"
  value       = aws_elasticache_replication_group.redis.member_clusters
}

output "redis_replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

output "redis_replication_group_arn" {
  description = "Redis replication group ARN"
  value       = aws_elasticache_replication_group.redis.arn
}

output "redis_auth_token" {
  description = "Redis AUTH token (sensitive - store securely)"
  value       = random_password.redis_auth_token.result
  sensitive   = true
}

output "redis_kms_key_id" {
  description = "KMS key ID for Redis encryption"
  value       = aws_kms_key.redis.key_id
}

output "redis_kms_key_arn" {
  description = "KMS key ARN for Redis encryption"
  value       = aws_kms_key.redis.arn
}

#######################################
# DocumentDB (MongoDB-compatible) Outputs
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

output "docdb_cluster_arn" {
  description = "DocumentDB cluster ARN"
  value       = aws_docdb_cluster.main.arn
}

output "docdb_cluster_resource_id" {
  description = "DocumentDB cluster resource ID"
  value       = aws_docdb_cluster.main.cluster_resource_id
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

output "docdb_instance_identifiers" {
  description = "List of DocumentDB instance identifiers"
  value       = aws_docdb_cluster_instance.main[*].identifier
}

output "docdb_kms_key_id" {
  description = "KMS key ID for DocumentDB encryption"
  value       = aws_kms_key.docdb.key_id
}

output "docdb_kms_key_arn" {
  description = "DocumentDB KMS key ARN"
  value       = aws_kms_key.docdb.arn
}

#######################################
# VPC Endpoints Outputs
#######################################
output "vpc_endpoint_s3_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoint_dynamodb_id" {
  description = "DynamoDB VPC Endpoint ID"
  value       = aws_vpc_endpoint.dynamodb.id
}

# output "vpc_endpoint_ecr_api_id" {
#   description = "ECR API VPC Endpoint ID"
#   value       = aws_vpc_endpoint.ecr_api.id
# }

# output "vpc_endpoint_ecr_dkr_id" {
#   description = "ECR Docker VPC Endpoint ID"
#   value       = aws_vpc_endpoint.ecr_dkr.id
# }

output "vpc_endpoint_ec2_id" {
  description = "EC2 VPC Endpoint ID"
  value       = aws_vpc_endpoint.ec2.id
}

output "vpc_endpoint_elb_id" {
  description = "ELB VPC Endpoint ID"
  value       = aws_vpc_endpoint.elasticloadbalancing.id
}

output "vpc_endpoint_logs_id" {
  description = "CloudWatch Logs VPC Endpoint ID"
  value       = aws_vpc_endpoint.logs.id
}

output "vpc_endpoint_sts_id" {
  description = "STS VPC Endpoint ID"
  value       = aws_vpc_endpoint.sts.id
}

output "vpc_endpoint_autoscaling_id" {
  description = "Autoscaling VPC Endpoint ID"
  value       = aws_vpc_endpoint.autoscaling.id
}

output "vpc_endpoint_kms_id" {
  description = "KMS VPC Endpoint ID"
  value       = aws_vpc_endpoint.kms.id
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
# Network ACLs Outputs
#######################################
output "public_nacl_id" {
  description = "Public subnet Network ACL ID"
  value       = aws_network_acl.public.id
}

output "private_nacl_id" {
  description = "Private subnet Network ACL ID"
  value       = aws_network_acl.private.id
}

output "database_nacl_id" {
  description = "Database subnet Network ACL ID"
  value       = aws_network_acl.database.id
}

#######################################
# Database Security Group Output
#######################################
output "database_security_group_id" {
  description = "Security group ID for database resources (RDS, Redis, DocumentDB)"
  value       = aws_security_group.database.id
}
