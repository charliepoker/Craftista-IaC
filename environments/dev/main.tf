# Main Terraform configuration for Development Environment
# Note: Terraform version and provider requirements are defined in provider.tf

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true # Cost optimization for dev

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role  = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group = var.enable_vpc_flow_logs

  tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/elb"                                       = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
    "kubernetes.io/role/internal-elb"                              = "1"
  }
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # EKS Managed Node Groups
  eks_managed_node_groups = var.node_groups

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSReservedSSO_AdministratorAccess_*"
      username = "admin"
      groups   = ["system:masters"]
    },
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
#######################################
# DevOps Tools Integration
#######################################

# Data source for AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Groups for DevOps Tools
module "sonarqube_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-${var.environment}-sonarqube-sg"
  description = "Security group for SonarQube"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 9000
      to_port     = 9000
      protocol    = "tcp"
      description = "SonarQube HTTP"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "sonarqube"
  }
}

module "nexus_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-${var.environment}-nexus-sg"
  description = "Security group for Nexus"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 8081
      to_port     = 8081
      protocol    = "tcp"
      description = "Nexus HTTP"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
    {
      from_port   = 8082
      to_port     = 8082
      protocol    = "tcp"
      description = "Nexus Docker Registry"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "All outbound traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "nexus"
  }
}

# SonarQube EC2 Instance
module "sonarqube_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-sonarqube"

  instance_type               = var.sonarqube_instance_type
  ami                         = data.aws_ami.amazon_linux.id
  key_name                    = var.key_name
  monitoring                  = true
  vpc_security_group_ids      = [module.sonarqube_sg.security_group_id]
  subnet_id                   = module.vpc.private_subnets[0] # Private subnet for security
  associate_public_ip_address = false

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for SonarQube instance"
  iam_role_policies = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    SSMManagedInstanceCore      = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  user_data = base64encode(templatefile("${path.module}/user-data/sonarqube.sh", {
    environment = var.environment
  }))

  root_block_device = [{
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = var.sonarqube_data_volume_size
    encrypted   = true
  }]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "sonarqube"
    Terraform   = "true"
  }

  depends_on = [module.vpc, module.eks]
}

# Nexus EC2 Instance
module "nexus_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name = "${var.project_name}-${var.environment}-nexus"

  instance_type               = var.nexus_instance_type
  ami                         = data.aws_ami.amazon_linux.id
  key_name                    = var.key_name
  monitoring                  = true
  vpc_security_group_ids      = [module.nexus_sg.security_group_id]
  subnet_id                   = module.vpc.private_subnets[0] # Private subnet for security
  associate_public_ip_address = false

  create_iam_instance_profile = true
  iam_role_description        = "IAM role for Nexus instance"
  iam_role_policies = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    SSMManagedInstanceCore      = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  user_data = base64encode(templatefile("${path.module}/user-data/nexus.sh", {
    environment = var.environment
  }))

  root_block_device = [{
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }]

  ebs_block_device = [{
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = var.nexus_data_volume_size
    encrypted   = true
  }]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "nexus"
    Terraform   = "true"
  }

  depends_on = [module.vpc, module.eks]
}

# Application Load Balancer for DevOps Tools
module "devops_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "${var.project_name}-${var.environment}-devops-alb"
  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Security Group
  security_groups = [aws_security_group.devops_alb.id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
      action_type        = "forward"
    }
  ]

  http_tcp_listener_rules = [
    {
      http_tcp_listener_index = 0
      priority                = 100

      actions = [{
        type               = "forward"
        target_group_index = 1
      }]

      conditions = [{
        path_patterns = ["/nexus*"]
      }]
    }
  ]

  target_groups = [
    {
      name             = "${var.project_name}-${var.environment}-sonarqube-tg"
      backend_protocol = "HTTP"
      backend_port     = 9000
      target_type      = "instance"
      targets = [
        {
          target_id = module.sonarqube_instance.id
          port      = 9000
        }
      ]
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/api/system/status"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    },
    {
      name             = "${var.project_name}-${var.environment}-nexus-tg"
      backend_protocol = "HTTP"
      backend_port     = 8081
      target_type      = "instance"
      targets = [
        {
          target_id = module.nexus_instance.id
          port      = 8081
        }
      ]
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/nexus/service/rest/v1/status"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }
  ]

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "devops-tools"
  }

  depends_on = [module.vpc]
}

# Security Group for ALB
resource "aws_security_group" "devops_alb" {
  name        = "${var.project_name}-${var.environment}-devops-alb-sg"
  description = "Security group for DevOps ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "devops-alb"
  }
}
