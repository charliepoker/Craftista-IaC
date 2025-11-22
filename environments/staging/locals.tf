# Local values for reuse across resources
locals {
  user_ip = replace(chomp(data.http.user_ip.response_body), "\r", "")

  # EKS cluster name
  eks_cluster_name = "${var.project_name}-${var.environment}-eks"

  # Validate cluster name length
  cluster_name_valid = length(local.eks_cluster_name) <= 40

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
    Purpose     = "Pre-Production Testing"
    CostCenter  = "Staging"
  }
}
