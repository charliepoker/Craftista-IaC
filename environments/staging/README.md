# Craftista Staging Environment

This directory contains the Terraform infrastructure code for the **Staging** environment of the Craftista application.

## Overview

The staging environment is a **production-like** setup designed for:

- Pre-production testing and validation
- Performance and load testing
- Integration testing with production-like resources
- Staging application releases before production deployment
- Testing infrastructure changes before applying to production

**Key Principle**: Mirrors production architecture with scaled-down resources to balance cost and production parity. This environment validates both application and infrastructure changes before they reach production.

## 🏗️ Infrastructure Components

### Networking

- **VPC CIDR**: `10.2.0.0/16`
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **Subnets**:
  - Public: 3 subnets
  - Private: 3 subnets
  - Database: 3 subnets
- **NAT Gateway**: Single (cost optimization)
- **VPC Flow Logs**: Enabled (CloudWatch)
- **VPC Endpoints**: Essential only (S3, ECR, Logs)

### Cost Optimizations for Staging

- Single NAT Gateway (production uses 3)
- SPOT instances for EKS nodes
- Single-AZ database deployments
- Container Insights disabled by default
- Shorter backup retention periods

### Compute

- **EKS Cluster**: Kubernetes 1.30
- **Node Group**:
  - 1-2 nodes (can scale up for testing)
  - Instance: t3.small SPOT
  - 20 GB disk
  - IRSA enabled for pod-level IAM permissions

### Databases

- **PostgreSQL**: db.t4g.micro, Single-AZ (can enable Multi-AZ for testing)
- **Redis**: cache.t3.micro, Single node
- **DocumentDB**: db.t3.medium, Single instance

### DevOps Tools

- **SonarQube**: t3.medium instance
- **Nexus**: t3.medium instance
- Access via SSM Session Manager (no SSH keys)

## 📁 Files

```
staging/
├── provider.tf          # Terraform and AWS provider configuration
├── locals.tf            # Local values and tags
├── variables.tf         # Variable definitions with staging defaults
├── terraform.tfvars     # Actual values for staging environment
├── main.tf              # Main infrastructure resources
├── outputs.tf           # Output values
└── README.md            # This file
```

## 🚀 Getting Started

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.5.0
3. **kubectl** for Kubernetes management
4. **Backend setup**: S3 bucket and DynamoDB table for state

### Initialize Terraform

```bash
cd environments/staging
terraform init
```

### Review the Plan

```bash
terraform plan
```

### Apply the Infrastructure

```bash
terraform apply
```

This will take approximately **15-20 minutes** to complete.

## 🔐 Accessing the Cluster

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig \
  --name craftista-staging \
  --region us-east-1

# Verify access
kubectl get nodes
```

## 📤 Getting Outputs

### View all outputs:

```bash
terraform output
```

### Get specific outputs:

```bash
# VPC and network info
terraform output vpc_id
terraform output private_subnets

# EKS cluster
terraform output eks_cluster_endpoint
terraform output eks_cluster_name

# Database endpoints (if configured)
terraform output rds_endpoint
terraform output redis_primary_endpoint
terraform output docdb_cluster_endpoint
```

## 🔄 Common Operations

### Update the Infrastructure

```bash
terraform plan
terraform apply
```

### Scale the Node Group

Edit `terraform.tfvars`:

```hcl
node_groups = {
  main = {
    instance_types = ["t3.small"]
    min_size       = 1
    max_size       = 4      # Increase for load testing
    desired_size   = 2      # Scale up for testing
    capacity_type  = "SPOT"
    disk_size      = 20
    taints         = []
  }
}
```

Then apply:

```bash
terraform apply
```

### Testing Multi-AZ RDS

To test database failover, enable Multi-AZ in `terraform.tfvars`:

```hcl
rds_multi_az = true
```

Then apply the changes:

```bash
terraform apply
```

### Destroy the Environment

⚠️ **Warning**: This will delete all resources and data.

```bash
terraform destroy
```

Destruction takes approximately **10-15 minutes**.

## 📝 Variables Reference

### Key Variables to Modify:

| Variable                        | Default        | Description                 |
| ------------------------------- | -------------- | --------------------------- |
| `aws_region`                    | us-east-1      | AWS region                  |
| `environment`                   | staging        | Environment name            |
| `node_groups.main.desired_size` | 1              | Number of nodes             |
| `rds_instance_class`            | db.t4g.micro   | RDS instance size           |
| `redis_node_type`               | cache.t3.micro | Redis instance size         |
| `docdb_instance_class`          | db.t3.medium   | DocumentDB instance size    |
| `rds_multi_az`                  | false          | Enable Multi-AZ for testing |
| `budget_amount`                 | 50             | Monthly budget alert (USD)  |

See `variables.tf` for complete list.

---
