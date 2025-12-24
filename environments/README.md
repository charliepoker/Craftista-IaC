# Environment Configurations

This directory contains the Terraform configurations for each deployment environment. Each environment is completely isolated with its own state file, VPC, and resources.

## Available Environments

### Development (`dev/`)

The development environment is optimized for rapid iteration and cost savings. It uses smaller instance types and SPOT instances where possible.

**Key Characteristics:**

- 2 availability zones
- SPOT instances for EKS nodes (t3.small)
- Single-AZ databases
- Single NAT gateway
- Minimal backup retention
- VPC CIDR: 10.1.0.0/16

**What's Running:**

- EKS cluster with 1-2 worker nodes
- RDS PostgreSQL (db.t3.micro)
- DocumentDB (db.t3.medium, 1 instance)
- ElastiCache Redis (cache.t3.micro)
- SonarQube and Nexus on t3.medium instances

### Staging (`staging/`)

Staging mirrors production architecture but with scaled-down resources. Use this to validate changes before they hit production.

**Key Characteristics:**

- 3 availability zones (production-like)
- SPOT instances for cost savings
- Single-AZ databases (can enable Multi-AZ for testing)
- Single NAT gateway
- Moderate backup retention
- VPC CIDR: 10.2.0.0/16

**What's Running:**

- EKS cluster with 1-2 worker nodes
- RDS PostgreSQL (db.t4g.micro)
- DocumentDB (db.t3.medium, 1 instance)
- ElastiCache Redis (cache.t3.micro)
- SonarQube and Nexus on t3.medium instances

### Production (`prod/`)

Production environment with high availability, enhanced monitoring, and proper redundancy.

**Key Characteristics:**

- 3 availability zones
- ON_DEMAND instances for stability
- Multi-AZ RDS deployment
- NAT gateway per AZ
- Extended backup retention
- Deletion protection enabled
- Container Insights enabled
- VPC CIDR: 10.0.0.0/16

**What's Running:**

- EKS cluster with 2-4 worker nodes
- RDS PostgreSQL Multi-AZ (db.t4g.micro)
- DocumentDB (db.t3.medium, 2 instances)
- ElastiCache Redis (2 nodes with failover)
- SonarQube and Nexus on t3.large instances

## Quick Start

### 1. Set Up Backend State

Before deploying any environment, initialize the Terraform backend:

```bash
cd ../bootstrap
terraform init
terraform apply
```

This creates the S3 bucket and DynamoDB table for remote state management.

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cd dev  # or staging, or prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values. **Important:** Never commit this file - it's gitignored for security reasons.

### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Network Architecture

All environments follow the same network pattern:

```
VPC
├── Public Subnets (one per AZ)
│   ├── NAT Gateways
│   ├── Application Load Balancers
│   └── Bastion hosts (if needed)
├── Private Subnets (one per AZ)
│   ├── EKS Worker Nodes
│   ├── SonarQube
│   └── Nexus
└── Database Subnets (one per AZ)
    ├── RDS PostgreSQL
    ├── DocumentDB
    └── ElastiCache Redis
```

## Accessing Resources

### EKS Cluster

```bash
aws eks update-kubeconfig --name craftista-{env} --region us-east-1
kubectl get nodes
```

### EC2 Instances (SonarQube/Nexus)

We use SSM Session Manager instead of SSH keys:

```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Service,Values=sonarqube"

# Connect via SSM
aws ssm start-session --target i-1234567890abcdef0
```

### Databases

All databases are in private subnets. Connect through:

- EKS pods (preferred)
- SSM port forwarding
- Bastion host if you need one

## State Management

Each environment maintains its own Terraform state in S3:

- Dev: `s3://craftista-terraform-state-{account-id}/dev/terraform.tfstate`
- Staging: `s3://craftista-terraform-state-{account-id}/staging/terraform.tfstate`
- Prod: `s3://craftista-terraform-state-{account-id}/prod/terraform.tfstate`

State locking uses DynamoDB to prevent concurrent modifications.
