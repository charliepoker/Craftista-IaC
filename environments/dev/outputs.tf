# Outputs for Development Environment

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

# EKS Outputs
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name/id of the EKS cluster"
  value       = module.eks.cluster_name
}

# DevOps Tools Outputs
output "sonarqube_instance_id" {
  description = "ID of the SonarQube instance"
  value       = module.sonarqube_instance.id
}

output "sonarqube_private_ip" {
  description = "Private IP of SonarQube instance"
  value       = module.sonarqube_instance.private_ip
}

output "nexus_instance_id" {
  description = "ID of the Nexus instance"
  value       = module.nexus_instance.id
}

output "nexus_private_ip" {
  description = "Private IP of Nexus instance"
  value       = module.nexus_instance.private_ip
}

output "devops_alb_dns_name" {
  description = "DNS name of the DevOps tools ALB"
  value       = module.devops_alb.lb_dns_name
}

output "devops_tools_access" {
  description = "Access information for DevOps tools"
  value = {
    sonarqube_url = "http://${module.devops_alb.lb_dns_name}"
    nexus_url     = "http://${module.devops_alb.lb_dns_name}/nexus"
    alb_dns_name  = module.devops_alb.lb_dns_name

    # Internal access (from within VPC)
    sonarqube_internal    = "http://${module.sonarqube_instance.private_ip}:9000"
    nexus_internal        = "http://${module.nexus_instance.private_ip}:8081"
    nexus_docker_internal = "http://${module.nexus_instance.private_ip}:8082"
  }
}
