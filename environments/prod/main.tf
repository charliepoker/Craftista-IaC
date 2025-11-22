#######################################
# Data Sources
#######################################
data "http" "user_ip" {
  url = "https://api.ipify.org"

  retry {
    attempts     = 3
    min_delay_ms = 500
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


########################################
# VPC Configuration
#######################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  # NAT Gateway - single for dev, but with proper monitoring
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs to S3 (This is a cheaper option to CloudWatch)
  enable_flow_log             = var.enable_vpc_flow_logs
  flow_log_destination_type   = "s3"
  flow_log_destination_arn    = var.enable_vpc_flow_logs ? aws_s3_bucket.flow_logs[0].arn : null
  flow_log_file_format        = "parquet"
  flow_log_per_hour_partition = true
  vpc_flow_log_tags = {
    Name = "${var.project_name}-${var.environment}-flow-logs"
  }

  # Subnet tags for EKS and load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "Type"                                            = "public"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "Type"                                            = "private"
  }

  database_subnet_tags = {
    "Type" = "database"
  }

  # Database subnet configuration
  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false

  tags = local.common_tags
}

#######################################
# S3 Bucket for VPC Flow Logs
#######################################
resource "aws_s3_bucket" "flow_logs" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  bucket        = "${var.project_name}-${var.environment}-vpc-flow-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # Allow bucket deletion even with objects inside.  This shouldn't be used in production without careful consideration.

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-flow-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.flow_logs[0].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    filter {}

    id     = "delete-old-logs"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  count  = var.enable_vpc_flow_logs ? 1 : 0
  bucket = aws_s3_bucket.flow_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


#######################################
# Launch Template for EKS Nodes
#######################################
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${local.eks_cluster_name}-node-"
  description = "Launch template for EKS managed node group"

  # Block device mappings for EBS volumes
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_groups.main.disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Monitoring configuration
  monitoring {
    enabled = true
  }

  # Network interfaces configuration
  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups             = [module.eks.node_security_group_id]
  }

  # Custom user data for node initialization
  user_data = base64encode(templatefile("${path.module}/templates/node-userdata.sh", {
    cluster_name        = local.eks_cluster_name
    cluster_endpoint    = module.eks.cluster_endpoint
    cluster_ca          = module.eks.cluster_certificate_authority_data
    node_labels         = "Environment=${var.environment},NodeGroup=main"
    bootstrap_arguments = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=normal'"
  }))

  # Metadata options for IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name        = "${local.eks_cluster_name}-node"
      Environment = var.environment
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.eks_cluster_name}-node-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.eks_cluster_name}-launch-template"
  })
}

#######################################
# EKS Cluster
#######################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.eks_cluster_name
  cluster_version = var.kubernetes_version

  # Network Configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster endpoint configuration - multiple CIDR blocks for access
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = concat(
    ["${local.user_ip}/32"],
    var.additional_allowed_cidrs
  )
  cluster_endpoint_private_access = true

  # Enhanced cluster logging
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 30

  # EKS Managed Node Groups with AZ distribution
  eks_managed_node_groups = {
    main = {
      # Scaling configuration with enhanced values
      min_size     = 2
      max_size     = 10
      desired_size = 3

      # Instance configuration
      instance_types = var.node_groups.main.instance_types
      capacity_type  = var.node_groups.main.capacity_type

      # Use custom launch template
      use_custom_launch_template = true
      launch_template_id         = aws_launch_template.eks_nodes.id
      launch_template_version    = aws_launch_template.eks_nodes.latest_version

      # Ensure multi-AZ distribution
      subnet_ids = module.vpc.private_subnets

      # Use cluster security group
      create_security_group = false

      # IAM permissions
      iam_role_additional_policies = merge(
        {
          AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        },
        var.enable_ssm ? {
          AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        } : {}
      )

      # Labels for workload placement
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
        managed-by  = "terraform"
      }

      # Taints for specialized workloads
      taints = var.node_groups.main.taints

      # Cluster Autoscaler tags - CRITICAL for auto-scaling
      tags = merge(local.common_tags, {
        Name      = "${local.eks_cluster_name}-node"
        NodeGroup = "main"
        # Cluster Autoscaler discovery tags
        "k8s.io/cluster-autoscaler/${local.eks_cluster_name}" = "owned"
        "k8s.io/cluster-autoscaler/enabled"                   = "true"
        # Node lifecycle management
        "k8s.io/cluster-autoscaler/node-template/label/Environment" = var.environment
        "k8s.io/cluster-autoscaler/node-template/label/NodeGroup"   = "main"
      })

      # Instance refresh configuration for rolling updates
      update_config = {
        max_unavailable_percentage = 33 # Update 33% of nodes at a time
      }

      # Force update version when launch template changes
      force_update_version = true
    }
  }

  # Cluster add-ons with flexible versioning
  cluster_addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      most_recent                 = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
      most_recent              = true
    }
  }

  # Enable IRSA
  enable_irsa = true

  # Cluster encryption with KMS
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all traffic"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_alb = {
      description              = "Allow traffic from ALB"
      protocol                 = "tcp"
      from_port                = 1025
      to_port                  = 65535
      type                     = "ingress"
      source_security_group_id = aws_security_group.alb.id
    }
    ingress_vault = {
      description              = "Allow Vault API access from Vault security group"
      protocol                 = "tcp"
      from_port                = 8200
      to_port                  = 8201
      type                     = "ingress"
      source_security_group_id = aws_security_group.vault.id
    }
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = local.common_tags
}

#######################################
# KMS Key for S3 Flow Logs Bucket Encryption
#######################################
resource "aws_kms_key" "flow_logs" {
  count                   = var.enable_vpc_flow_logs ? 1 : 0
  description             = "KMS key for VPC Flow Logs S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-flow-logs-key"
  })
}

resource "aws_kms_alias" "flow_logs" {
  count         = var.enable_vpc_flow_logs ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-flow-logs"
  target_key_id = aws_kms_key.flow_logs[0].key_id
}

#######################################
# VPC Endpoints for AWS Services
#######################################
# S3 Gateway Endpoint (no cost, routes via VPC)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  })
}

# DynamoDB Gateway Endpoint (no cost)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-dynamodb-endpoint"
  })
}

# ECR API Interface Endpoint (for pulling Docker images)
# Commented out - using Docker Hub instead of ECR
# Uncomment and set enable_ecr_endpoints=true if you switch to ECR
# resource "aws_vpc_endpoint" "ecr_api" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = merge(local.common_tags, {
#     Name = "${var.project_name}-${var.environment}-ecr-api-endpoint"
#   })
# }

# ECR Docker Interface Endpoint (for pulling Docker layers)
# Commented out - using Docker Hub instead of ECR
# Uncomment and set enable_ecr_endpoints=true if you switch to ECR
# resource "aws_vpc_endpoint" "ecr_dkr" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.vpc_endpoints.id]
#   private_dns_enabled = true
#
#   tags = merge(local.common_tags, {
#     Name = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
#   })
# }

# EC2 Interface Endpoint (for EKS API calls)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-endpoint"
  })
}

# ELB Interface Endpoint (for load balancer API calls)
resource "aws_vpc_endpoint" "elasticloadbalancing" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-elb-endpoint"
  })
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-logs-endpoint"
  })
}

# STS Interface Endpoint (for IAM role assumption)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-sts-endpoint"
  })
}

# Autoscaling Interface Endpoint (for EKS cluster autoscaler)
resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.autoscaling"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-autoscaling-endpoint"
  })
}

# KMS Interface Endpoint (for encryption operations)
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-kms-endpoint"
  })
}

#######################################
# SSM VPC Endpoints for Session Manager
#######################################
resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_ssm ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_ssm ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_ssm ? 1 : 0
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2messages-endpoint"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# Network ACLs for Additional Security
#######################################
# Public Subnet Network ACL
resource "aws_network_acl" "public" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Inbound Rules
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound Rules
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-nacl"
  })
}

# Private Subnet Network ACL
resource "aws_network_acl" "private" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Inbound Rules - Allow from VPC
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Inbound Rules - Allow ephemeral ports from internet (for responses)
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound Rules - Allow all to VPC
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Outbound Rules - Allow HTTPS to internet
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound Rules - Allow HTTP to internet
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Outbound Rules - Allow ephemeral ports
  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-nacl"
  })
}

# Database Subnet Network ACL
resource "aws_network_acl" "database" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnets

  # Inbound Rules - Allow PostgreSQL from private subnets
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 5432
    to_port    = 5432
  }

  # Inbound Rules - Allow Redis from private subnets
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 6379
    to_port    = 6379
  }

  # Inbound Rules - Allow MongoDB/DocumentDB from private subnets
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 27017
    to_port    = 27017
  }

  # Inbound Rules - Allow ephemeral ports for responses
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound Rules - Allow all to VPC
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = module.vpc.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }

  # Outbound Rules - Allow ephemeral ports
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-nacl"
  })
}

#######################################
# KMS Keys
#######################################
# KMS key for EKS
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-eks-kms"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.eks_cluster_name}-encryption"
  target_key_id = aws_kms_key.eks.key_id
}

#######################################
# KMS Key for Vault Auto-Unseal
#######################################
# HashiCorp Vault can use AWS KMS for automatic unsealing, which eliminates
# the need to manually enter unseal keys when Vault restarts. This key is used
# to encrypt/decrypt Vault's master key.
#
# Benefits:
# - Automatic unsealing after restarts
# - No need to store unseal keys manually
# - Enhanced security with AWS KMS key management
# - Key rotation support
#######################################
resource "aws_kms_key" "vault" {
  description             = "KMS key for HashiCorp Vault auto-unseal"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-vault-unseal"
    Purpose = "vault-auto-unseal"
  })
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.project_name}-${var.environment}-vault-unseal"
  target_key_id = aws_kms_key.vault.key_id
}

#######################################
# S3 Bucket for Vault Storage Backend
#######################################
resource "aws_s3_bucket" "vault_storage" {
  bucket        = "${var.project_name}-${var.environment}-vault-storage-${data.aws_caller_identity.current.account_id}"
  force_destroy = false # Protect Vault data from accidental deletion

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${var.environment}-vault-storage"
    Purpose = "vault-backend-storage"
  })
}

resource "aws_s3_bucket_versioning" "vault_storage" {
  bucket = aws_s3_bucket.vault_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vault_storage" {
  bucket = aws_s3_bucket.vault_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.vault.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "vault_storage" {
  bucket = aws_s3_bucket.vault_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "vault_storage" {
  bucket = aws_s3_bucket.vault_storage.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

#######################################
# Application Load Balancer Security Group
#######################################
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  # HTTP from anywhere
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic to EKS nodes
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# Database Security Group
#######################################
resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-${var.environment}-database-"
  description = "Security group for database resources"
  vpc_id      = module.vpc.vpc_id

  # PostgreSQL from EKS nodes
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  # MongoDB/DocumentDB from EKS nodes
  ingress {
    description     = "MongoDB from EKS nodes"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  # Redis from EKS nodes
  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-database-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# Security Group for HashiCorp Vault
#######################################
# Vault requires specific ports for:
# - API/UI access (8200) - HTTPS
# - Cluster communication (8201) - for HA setups
#
# This security group allows:
# - Vault pods to communicate with each other
# - Applications (EKS nodes) to access Vault API
# - Optional: ALB to route traffic to Vault UI
#######################################
resource "aws_security_group" "vault" {
  name_prefix = "${var.project_name}-${var.environment}-vault-"
  description = "Security group for HashiCorp Vault"
  vpc_id      = module.vpc.vpc_id

  # Vault API/UI port - HTTPS (from EKS nodes)
  ingress {
    description     = "Vault API from EKS nodes"
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  # Vault API/UI port - HTTPS (from ALB for external access)
  ingress {
    description     = "Vault API from ALB"
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Vault cluster port (for HA communication between Vault pods)
  ingress {
    description = "Vault cluster communication"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    self        = true
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vault-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#######################################
# IAM Role for EBS CSI Driver
#######################################
# The EBS CSI (Container Storage Interface) Driver allows Kubernetes to manage
# Amazon EBS volumes for persistent storage. This IAM role enables the driver
# to create, attach, detach, and delete EBS volumes on behalf of the cluster.
#
# Uses IRSA (IAM Roles for Service Accounts) for secure, credential-free access.
# The role is assumed by the ebs-csi-controller-sa service account in kube-system.
#
# Required for:
# - Dynamic provisioning of EBS volumes via StorageClasses
# - Volume snapshots and cloning
# - Volume resizing operations
#######################################
data "aws_iam_policy_document" "ebs_csi_driver_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name_prefix        = "${local.eks_cluster_name}-ebs-csi-"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.eks_cluster_name}-ebs-csi-driver"
  })
}

# Attach AWS managed policy that provides permissions for EBS operations
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

#######################################
# IAM Role for Cluster Autoscaler
#######################################
# The Cluster Autoscaler automatically adjusts the number of nodes in the cluster
# based on pod resource requests and node utilization. This role grants permissions
# to scale Auto Scaling Groups up or down.
#
# Uses IRSA for secure authentication via the cluster-autoscaler service account.
#
# Permissions include:
# - Describe ASG configurations and activities
# - Modify desired capacity of ASGs
# - Terminate instances in ASGs
# - Describe EC2 launch templates and instance types
#
# Works in conjunction with cluster autoscaler tags on node groups:
# - k8s.io/cluster-autoscaler/${cluster_name}=owned
# - k8s.io/cluster-autoscaler/enabled=true
#######################################
data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name_prefix        = "${local.eks_cluster_name}-cluster-autoscaler-"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.eks_cluster_name}-cluster-autoscaler"
  })
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "${local.eks_cluster_name}-cluster-autoscaler-"
  description = "IAM policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

#######################################
# IAM Role for AWS Load Balancer Controller
#######################################
# The AWS Load Balancer Controller manages Elastic Load Balancers for Kubernetes
# services. It provisions ALB (Application Load Balancer) for Ingress resources
# and NLB (Network Load Balancer) for LoadBalancer services.
#
# Uses IRSA for secure authentication via the aws-load-balancer-controller service account.
#
# Key capabilities:
# - Creates and manages ALBs for Ingress resources
# - Creates and manages NLBs for LoadBalancer services
# - Configures target groups and health checks
# - Manages security groups and load balancer attributes
# - Supports advanced features like WAF integration and SSL certificates
#
# The policy grants permissions for:
# - EC2 operations (security groups, subnets, VPCs)
# - Elastic Load Balancing v2 operations
# - ACM certificate discovery
# - WAF and Shield integration
# - Tag-based resource management
#######################################
data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name_prefix        = "${local.eks_cluster_name}-alb-"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.eks_cluster_name}-aws-load-balancer-controller"
  })

}

# AWS managed policy loaded from official AWS documentation
# Policy file contains the required permissions for ALB/NLB management
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name_prefix = "${local.eks_cluster_name}-alb-"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-policy.json")

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

#######################################
# IAM Role for HashiCorp Vault
#######################################
# This IAM role grants Vault the necessary permissions to:
# 1. Use KMS for auto-unseal operations
# 2. Access S3 for storage backend
# 3. Describe EC2 instances for auto-discovery in HA mode
#
# Uses IRSA (IAM Roles for Service Accounts) for secure authentication.
# The role will be assumed by the vault service account in the vault namespace.
#######################################
data "aws_iam_policy_document" "vault_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:vault:vault"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault" {
  name_prefix        = "${local.eks_cluster_name}-vault-"
  assume_role_policy = data.aws_iam_policy_document.vault_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.eks_cluster_name}-vault"
  })
}

# IAM Policy for Vault KMS auto-unseal
resource "aws_iam_policy" "vault_kms" {
  name_prefix = "${local.eks_cluster_name}-vault-kms-"
  description = "IAM policy for Vault KMS auto-unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "vault_kms" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault_kms.arn
}

# IAM Policy for Vault S3 storage backend
resource "aws_iam_policy" "vault_s3" {
  name_prefix = "${local.eks_cluster_name}-vault-s3-"
  description = "IAM policy for Vault S3 storage backend"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.vault_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.vault_storage.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "vault_s3" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault_s3.arn
}

# IAM Policy for Vault EC2 auto-discovery in HA mode
resource "aws_iam_policy" "vault_ec2" {
  name_prefix = "${local.eks_cluster_name}-vault-ec2-"
  description = "IAM policy for Vault EC2 auto-discovery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "vault_ec2" {
  role       = aws_iam_role.vault.name
  policy_arn = aws_iam_policy.vault_ec2.arn
}

#######################################
# RDS PostgreSQL
#######################################
# Random password for RDS master user
resource "random_password" "rds_master_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS Parameter Group for PostgreSQL optimization
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.project_name}-${var.environment}-postgres-v2-"
  family      = "postgres16"
  description = "Custom parameter group for PostgreSQL 16"

  # Only dynamic parameters (static parameters removed)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking longer than 1 second
  }

  # parameter {
  #   name  = "max_connections"
  #   value = "100"
  #   apply_method = "immediate"
  # }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier     = "${var.project_name}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = var.rds_engine_version

  # Instance configuration
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  # Database configuration
  db_name  = var.rds_database_name
  username = var.rds_master_username
  password = random_password.rds_master_password.result
  port     = 5432

  # Network configuration
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false

  # High availability and backups
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"         # 3-4 AM UTC
  maintenance_window      = "mon:04:00-mon:05:00" # Monday 4-5 AM UTC
  skip_final_snapshot     = true                  # This is not a good practice for production. Set to false if you want final snapshots.
  # skip_final_snapshot       = var.rds_skip_final_snapshot
  final_snapshot_identifier = var.rds_skip_final_snapshot ? null : "${var.project_name}-${var.environment}-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  copy_tags_to_snapshot     = true

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.postgres.name

  # Monitoring and logging
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Security and maintenance
  auto_minor_version_upgrade = true
  deletion_protection        = true
  apply_immediately          = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-postgres"
  })

  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name_prefix = "${var.project_name}-${var.environment}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

#######################################
# ElastiCache Redis
#######################################
# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-subnet-group"
  })
}

# ElastiCache Parameter Group for Redis
resource "aws_elasticache_parameter_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-params"
  family      = var.redis_parameter_group_family
  description = "Custom parameter group for Redis"

  # Performance and memory management
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Replication Group (Redis Cluster with replication)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Redis cluster for ${var.project_name} ${var.environment}"

  # Engine configuration
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.database.id]

  # High availability
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = aws_kms_key.redis.arn

  # Backup configuration
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = "03:00-04:00"         # 3-4 AM UTC
  maintenance_window       = "mon:04:00-mon:05:00" # Monday 4-5 AM UTC

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  # Maintenance and upgrades
  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
}

# Random password for Redis AUTH
resource "random_password" "redis_auth_token" {
  length  = 32
  special = true
  # Redis AUTH token has specific requirements
  override_special = "!&#$^<>-"
}

# KMS Key for Redis encryption
resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.project_name}-${var.environment}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

# CloudWatch Log Groups for Redis
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.project_name}-${var.environment}-redis/slow-log"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-slow-log"
  })
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${var.project_name}-${var.environment}-redis/engine-log"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis-engine-log"
  })
}

#######################################
# DocumentDB (MongoDB-compatible)
#######################################
# Random password for DocumentDB master user
resource "random_password" "docdb_master_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-docdb-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-subnet-group"
  })
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-docdb-params"
  family      = "docdb5.0"
  description = "Custom parameter group for DocumentDB"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  parameter {
    name  = "ttl_monitor"
    value = "enabled"
  }

  parameter {
    name  = "audit_logs"
    value = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-params"
  })
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${var.project_name}-${var.environment}-docdb"
  engine                          = "docdb"
  engine_version                  = var.docdb_engine_version
  master_username                 = var.docdb_master_username
  master_password                 = random_password.docdb_master_password.result
  port                            = 27017
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.database.id]

  # Backup configuration
  backup_retention_period      = var.docdb_backup_retention_period
  preferred_backup_window      = var.docdb_preferred_backup_window
  preferred_maintenance_window = var.docdb_preferred_maintenance_window
  # skip_final_snapshot          = var.docdb_skip_final_snapshot
  skip_final_snapshot       = true # This is not a good practice for production. Set to false if you want final snapshots.
  final_snapshot_identifier = var.docdb_skip_final_snapshot ? null : "${var.project_name}-${var.environment}-docdb-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Security
  storage_encrypted   = true
  kms_key_id          = aws_kms_key.docdb.arn
  deletion_protection = var.docdb_deletion_protection

  # Logging
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  # Apply changes immediately or during maintenance window
  apply_immediately = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-cluster"
  })

  depends_on = [aws_cloudwatch_log_group.docdb_audit, aws_cloudwatch_log_group.docdb_profiler]
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "main" {
  count              = var.docdb_instance_count
  identifier         = "${var.project_name}-${var.environment}-docdb-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.docdb_instance_class

  # Monitoring
  enable_performance_insights     = true
  performance_insights_kms_key_id = aws_kms_key.docdb.arn
  auto_minor_version_upgrade      = true
  preferred_maintenance_window    = var.docdb_preferred_maintenance_window

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-instance-${count.index + 1}"
  })
}

# KMS Key for DocumentDB encryption
resource "aws_kms_key" "docdb" {
  description             = "KMS key for DocumentDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb"
  })
}

resource "aws_kms_alias" "docdb" {
  name          = "alias/${var.project_name}-${var.environment}-docdb"
  target_key_id = aws_kms_key.docdb.key_id
}

# CloudWatch Log Groups for DocumentDB
resource "aws_cloudwatch_log_group" "docdb_audit" {
  name              = "/aws/docdb/${var.project_name}-${var.environment}-docdb/audit"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-audit"
  })
}

resource "aws_cloudwatch_log_group" "docdb_profiler" {
  name              = "/aws/docdb/${var.project_name}-${var.environment}-docdb/profiler"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-docdb-profiler"
  })
}

