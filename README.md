# Craftista Infrastructure as Code (IaC)

> **GitOps-Ready Terraform Infrastructure for the Craftista Application**

This repository contains the complete infrastructure as code (IaC) for deploying the Craftista application on AWS using Terraform. Designed following GitOps principles, this infrastructure supports multi-environment deployments with best practices for security, scalability, and cost optimization.

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Environment Configurations](#environment-configurations)
- [Security Features](#security-features)
- [Cost Management](#cost-management)
- [GitOps Workflow](#gitops-workflow)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## 🎯 Overview

This infrastructure repository provides:

- **Multi-Environment Setup**: Separate configurations for Dev, Staging, and Production
- **AWS EKS Kubernetes Clusters**: Container orchestration for microservices
- **Managed Databases**: RDS PostgreSQL, ElastiCache Redis, and DocumentDB
- **Network Security**: VPC with private/public subnets, security groups, and VPC endpoints
- **SSM Session Manager**: Secure, keyless access to EC2 nodes
- **Remote State Management**: S3 backend with DynamoDB state locking
- **Infrastructure as Code**: 100% Terraform with modular, reusable components
- **GitOps Ready**: Designed for automated deployments via CI/CD pipelines

### Why This Architecture?

- **Microservices-First**: Built specifically for the Craftista polyglot application
- **Cloud-Native**: Leverages AWS managed services for reduced operational overhead
- **Security-Focused**: Implements AWS security best practices including SSM, encryption, and least-privilege IAM
- **Cost-Optimized**: Different resource sizing per environment with budget controls
- **Production-Ready**: High availability, automated backups, and monitoring

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.x.0.0/16)                     │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │   Public     │  │   Public     │  │   Public     │  │   │
│  │  │   Subnet     │  │   Subnet     │  │   Subnet     │  │   │
│  │  │   AZ-1       │  │   AZ-2       │  │   AZ-3       │  │   │
│  │  │  (ALB, NAT)  │  │  (ALB, NAT)  │  │  (ALB, NAT)  │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │   Private    │  │   Private    │  │   Private    │  │   │
│  │  │   Subnet     │  │   Subnet     │  │   Subnet     │  │   │
│  │  │   AZ-1       │  │   AZ-2       │  │   AZ-3       │  │   │
│  │  │  EKS Nodes   │  │  EKS Nodes   │  │  EKS Nodes   │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  │                                                           │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │   Database   │  │   Database   │  │   Database   │  │   │
│  │  │   Subnet     │  │   Subnet     │  │   Subnet     │  │   │
│  │  │   AZ-1       │  │   AZ-2       │  │   AZ-3       │  │   │
│  │  │  RDS, Redis  │  │  RDS, Redis  │  │  RDS, Redis  │  │   │
│  │  │  DocumentDB   │  │  DocumentDB   │  │  DocumentDB   │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │           AWS EKS Cluster (Kubernetes 1.30)        │ │   │
│  │  │  • Control Plane (Managed by AWS)                  │ │   │
│  │  │  • Managed Node Groups                             │ │   │
│  │  │  • EBS CSI Driver, CoreDNS, kube-proxy, VPC CNI    │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                                                           │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │         VPC Endpoints (PrivateLink)                │ │   │
│  │  │  • SSM, SSM Messages, EC2 Messages                 │ │   │
│  │  │  • S3 Gateway Endpoint                             │ │   │
│  │  │  • CloudWatch Logs                                 │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Supporting Services                         │   │
│  │  • CloudWatch (Monitoring & Logs)                       │   │
│  │  • AWS Budgets (Cost Control)                           │   │
│  │  • KMS (Encryption Keys)                                │   │
│  │  • IAM Roles & Policies                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Components

#### Compute

- **AWS EKS** (Kubernetes 1.30): Managed Kubernetes clusters
- **EC2 Managed Node Groups**: Auto-scaling worker nodes (t3.small - t3.medium)
- **SSM Session Manager**: Secure shell access without SSH keys

#### Networking

- **VPC**: Isolated network per environment
- **3-Tier Subnet Design**: Public, Private, Database subnets across 3 AZs
- **NAT Gateways**: Outbound internet for private subnets
- **VPC Endpoints**: Private connectivity to AWS services
- **Security Groups**: Granular network access control

#### Data Layer

- **RDS PostgreSQL 16.3**: Relational database for voting service
- **ElastiCache Redis 7.1**: In-memory cache and session storage
- **DocumentDB 5.0**: MongoDB-compatible database for catalogue service

#### Security & Compliance

- **IAM Roles**: Least-privilege access with IRSA (IAM Roles for Service Accounts)
- **KMS Encryption**: EKS cluster encryption at rest
- **VPC Flow Logs**: Network traffic monitoring (Staging/Prod)
- **Enhanced Monitoring**: RDS performance insights and CloudWatch integration

#### Operations

- **Terraform Remote State**: S3 + DynamoDB for state management
- **AWS Budgets**: Cost monitoring with email alerts
- **CloudWatch Logs**: Centralized logging for all services
- **Automated Backups**: Scheduled snapshots for all databases

---

## 📁 Repository Structure

```
terraform/
├── README.md                          # This file
├── .gitignore                         # Git ignore patterns for Terraform
│
├── bootstrap/                         # Bootstrap infrastructure
│   ├── README.md                      # Bootstrap setup guide
│   ├── main.tf                        # S3 bucket + DynamoDB for state
│   ├── variables.tf                   # Bootstrap variables
│   ├── outputs.tf                     # Backend configuration outputs
│   ├── providers.tf                   # AWS provider config
│   ├── terraform.tfvars.example       # Example configuration
│   └── .terraform.lock.hcl           # Provider version locks
│
├── shared/                            # Shared modules/resources
│   └── versions.tf                    # Terraform version constraints
│
└── environments/                      # Environment-specific configs
    │
    ├── dev/                          # Development Environment
    │   ├── README.md                 # Dev environment documentation
    │   ├── main.tf                   # Main infrastructure (804 lines)
    │   ├── variables.tf              # Variable definitions (478 lines)
    │   ├── terraform.tfvars          # Dev-specific values
    │   ├── locals.tf                 # Local variables and computed values
    │   ├── provider.tf               # AWS provider + S3 backend
    │   └── outputs.tf                # Resource outputs (339 lines)
    │
    ├── staging/                      # Staging Environment
    │   ├── README.md                 # Staging environment documentation
    │   ├── main.tf                   # Main infrastructure (890 lines)
    │   ├── variables.tf              # Variable definitions (478 lines)
    │   ├── terraform.tfvars          # Staging-specific values
    │   ├── locals.tf                 # Local variables
    │   ├── provider.tf               # AWS provider + S3 backend
    │   └── outputs.tf                # Resource outputs (339 lines)
    │
    ├── prod/                         # Production Environment
        ├── README.md                 # Prod environment documentation
        ├── main.tf                   # Main infrastructure (804 lines)
        ├── variables.tf              # Variable definitions (483 lines)
        ├── terraform.tfvars          # Production-specific values
        ├── locals.tf                 # Local variables
        ├── provider.tf               # AWS provider + S3 backend
        └── outputs.tf                # Resource outputs (339 lines)

```

### File Descriptions

- **`main.tf`**: Core infrastructure resources (VPC, EKS, databases, security)
- **`variables.tf`**: Input variable definitions with validation rules
- **`terraform.tfvars`**: Environment-specific variable values (not committed to Git in real scenarios)
- **`locals.tf`**: Computed values and common tags
- **`provider.tf`**: Terraform and AWS provider configuration with backend settings
- **`outputs.tf`**: Exported values for use by other systems or documentation

---

## 🔧 Prerequisites

### Required Tools

1. **Terraform** >= 1.5.0

   ```bash
   # Install via Homebrew (macOS)
   brew install terraform

   # Verify installation
   terraform version
   ```

2. **AWS CLI** >= 2.0

   ```bash
   # Install via Homebrew (macOS)
   brew install awscli

   # Configure credentials
   aws configure
   ```

3. **kubectl** >= 1.30

   ```bash
   # Install via Homebrew (macOS)
   brew install kubectl
   ```

4. **Git**
   ```bash
   brew install git
   ```

### AWS Requirements

- **AWS Account** with administrator access (or specific IAM permissions)
- **AWS Credentials** configured locally
- **IAM Permissions** to create:
  - VPC, Subnets, Route Tables, NAT Gateways
  - EKS Clusters and Node Groups
  - RDS, ElastiCache, DocumentDB instances
  - S3 buckets, DynamoDB tables
  - IAM roles and policies
  - CloudWatch resources

### Recommended Knowledge

- Basic understanding of Terraform
- Familiarity with AWS services (VPC, EKS, RDS)
- Kubernetes fundamentals
- GitOps concepts

---

## 🚀 Quick Start

### Step 1: Bootstrap Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform/bootstrap

# Copy and edit the variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Set your unique bucket name

# Initialize and apply
terraform init
terraform plan
terraform apply
```

**Important**: Save the outputs! You'll need the bucket name and DynamoDB table name.

### Step 2: Choose Your Environment

Navigate to your target environment:

```bash
# For development
cd ../environments/dev

# For staging
cd ../environments/staging

# For production
cd ../environments/prod
```

### Step 3: Configure Variables

Review and customize the `terraform.tfvars` file:

```bash
# View current configuration
cat terraform.tfvars

# Edit if needed
nano terraform.tfvars
```

**Key variables to review**:

- `aws_region`: AWS region for deployment
- `vpc_cidr`: Network CIDR (already configured per environment)
- `kubernetes_version`: EKS version
- `node_groups`: EC2 instance types and sizing
- `budget_amount`: Monthly cost alert threshold

### Step 4: Initialize Terraform

```bash
terraform init
```

This will:

- Download required provider plugins
- Configure the S3 backend
- Initialize the working directory

### Step 5: Plan the Deployment

```bash
terraform plan
```

Review the execution plan carefully. You should see:

- **Dev**: ~80 resources to create
- **Staging**: ~100 resources to create
- **Prod**: ~100 resources to create

### Step 6: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment Time**:

- Dev: ~15-20 minutes
- Staging: ~20-25 minutes
- Prod: ~25-30 minutes

### Step 7: Configure kubectl

After successful deployment:

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name craftista-{env}-eks \
  --region us-east-1

# Verify connectivity
kubectl get nodes
kubectl get pods -A
```

### Step 8: Retrieve Database Credentials

```bash
# Get sensitive outputs
terraform output -raw rds_master_password
terraform output -raw redis_auth_token
terraform output -raw docdb_master_password

# Or all outputs as JSON
terraform output -json
```

---

## 🌍 Environment Configurations

### Development Environment

**Purpose**: Feature development, testing, and experimentation

**Specifications**:

- **VPC CIDR**: `10.1.0.0/16`
- **Availability Zones**: 2 (us-east-1a, us-east-1b)
- **EKS Nodes**: 1x t3.small (SPOT)
- **RDS**: db.t4g.micro, 20GB, single-AZ
- **Redis**: cache.t4g.micro, single node
- **DocumentDB**: db.t3.medium, single instance
- **High Availability**: No (cost-optimized)
- **Backups**: 1 day retention
- **Monitoring**: Basic CloudWatch logs
- **Estimated Monthly Cost**: ~$130-150 USD

**Use Cases**:

- Local feature testing
- CI/CD pipeline validation
- Learning and experimentation

### Staging Environment

**Purpose**: Pre-production testing and quality assurance

**Specifications**:

- **VPC CIDR**: `10.2.0.0/16`
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **EKS Nodes**: 2x t3.medium (SPOT), auto-scale 2-4
- **RDS**: db.t4g.small, 50GB, single-AZ, enhanced monitoring
- **Redis**: cache.t4g.micro, single node
- **DocumentDB**: db.t3.medium, single instance
- **High Availability**: Partial (production-like setup)
- **Backups**: 3 day retention
- **Monitoring**: VPC Flow Logs, enhanced RDS monitoring
- **SSM Session Manager**: Enabled for secure access
- **Estimated Monthly Cost**: ~$200-250 USD

**Use Cases**:

- Integration testing
- UAT (User Acceptance Testing)
- Performance testing
- Production simulation

### Production Environment

**Purpose**: Live application serving end users

**Specifications**:

- **VPC CIDR**: `10.0.0.0/16`
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **EKS Nodes**: 2x t3.small (ON_DEMAND), auto-scale 2-4
- **RDS**: db.t4g.small, 100GB, multi-AZ, enhanced monitoring
- **Redis**: cache.t4g.small, 2 nodes, multi-AZ with failover
- **DocumentDB**: db.t3.medium, 2 instances with automated failover
- **High Availability**: Yes (multi-AZ across all services)
- **Backups**: 7 day retention
- **Monitoring**: Full observability with Container Insights, VPC Flow Logs
- **SSM Session Manager**: Enabled for secure access
- **Deletion Protection**: Enabled on DocumentDB
- **Estimated Monthly Cost**: ~$400-500 USD

**Use Cases**:

- Production workloads
- Customer-facing services
- Business-critical operations

### Environment Comparison Matrix

| Feature               | Dev          | Staging      | Production   |
| --------------------- | ------------ | ------------ | ------------ |
| **Network**           |              |              |              |
| VPC CIDR              | 10.1.0.0/16  | 10.2.0.0/16  | 10.0.0.0/16  |
| Availability Zones    | 2            | 3            | 3            |
| NAT Gateways          | 1            | 1            | 3            |
| VPC Flow Logs         | ❌           | ✅           | ✅           |
| **Compute**           |              |              |              |
| EKS Version           | 1.30         | 1.30         | 1.30         |
| Node Instance Type    | t3.small     | t3.medium    | t3.small     |
| Node Count            | 1            | 2-4          | 2-4          |
| Capacity Type         | SPOT         | SPOT         | ON_DEMAND    |
| SSM Access            | ✅           | ✅           | ✅           |
| **Databases**         |              |              |              |
| RDS Instance          | db.t4g.micro | db.t4g.small | db.t4g.small |
| RDS Multi-AZ          | ❌           | ❌           | ✅           |
| RDS Storage           | 20GB         | 50GB         | 100GB        |
| RDS Backups           | 1 day        | 3 days       | 7 days       |
| Redis Instance        | micro        | micro        | small        |
| Redis Multi-AZ        | ❌           | ❌           | ✅           |
| DocumentDB Instances  | 1            | 1            | 2            |
| DocumentDB Protection | ❌           | ❌           | ✅           |
| **Operations**        |              |              |              |
| Container Insights    | ❌           | ❌           | ✅           |
| Enhanced Monitoring   | ❌           | ✅           | ✅           |
| Automated Backups     | ❌           | ✅           | ✅           |
| **Cost**              |              |              |              |
| Monthly Budget        | $5           | $50          | $200         |
| Estimated Actual      | $130-150     | $200-250     | $400-500     |

---

## 🔒 Security Features

### Network Security

1. **VPC Isolation**: Each environment has its own isolated VPC
2. **Private Subnets**: EKS nodes run in private subnets with no direct internet access
3. **Security Groups**: Least-privilege firewall rules
4. **NACL**: Default network ACLs for additional protection

### Access Control

1. **SSM Session Manager**:

   - Keyless access to EC2 nodes
   - All sessions logged to CloudWatch
   - No need to open SSH port 22
   - IAM-based authentication

2. **IAM Roles for Service Accounts (IRSA)**:

   - Fine-grained pod-level permissions
   - No long-lived credentials
   - AWS service integration without keys

3. **EKS API Security**:
   - Endpoint access controlled by security groups
   - Current user IP automatically whitelisted
   - Private endpoint available

### Data Protection

1. **Encryption at Rest**:

   - EKS cluster encryption with KMS
   - RDS storage encryption enabled
   - S3 state bucket encrypted (AES256)

2. **Encryption in Transit**:

   - TLS/SSL for all service communication
   - VPC endpoints for private AWS service access

3. **Secret Management**:
   - Terraform random passwords for databases
   - Sensitive outputs marked as sensitive
   - State file encrypted in S3

### Compliance

1. **Audit Logging**:

   - EKS control plane logs to CloudWatch
   - VPC Flow Logs (Staging/Prod)
   - RDS enhanced monitoring

2. **Backup & Recovery**:
   - Automated RDS snapshots
   - Redis snapshot retention
   - DocumentDB automated backups

---

## 💰 Cost Management

### Budget Controls

Each environment has AWS Budget configured with email alerts:

```hcl
# Alert thresholds
- 80% of budget: Warning
- 100% of budget: Alert
- 120% of budget: Critical
```

**Budget Allocations**:

- Dev: $5/month
- Staging: $50/month
- Production: $200/month

### Cost Optimization Strategies

#### Development

- Single availability zone NAT Gateway
- SPOT instances for EKS nodes
- Smallest database instance sizes
- No Container Insights
- Minimal backup retention

#### Staging

- Shared resources where possible
- SPOT instances for cost savings
- Moderate backup retention
- Enhanced monitoring for production simulation

#### Production

- ON_DEMAND instances for reliability
- Multi-AZ for high availability
- Right-sized instances
- Automated scaling policies
- Long-term backup retention

### Monthly Cost Breakdown

#### Development (~$130-150)

```
EKS Control Plane:        $73
EC2 Nodes (t3.small):     $8
NAT Gateway:              $32
RDS (db.t4g.micro):       $13
Redis (micro):            $12
DocumentDB (medium):      $55
VPC Endpoints:            $22
Misc (logs, transfer):    $7
──────────────────────────────
TOTAL:                    ~$130
```

#### Staging (~$200-250)

```
EKS Control Plane:        $73
EC2 Nodes (2x t3.medium): $30
NAT Gateway:              $32
RDS (db.t4g.small):       $26
Redis (micro):            $12
DocumentDB (medium):      $55
VPC Endpoints:            $22
Flow Logs:                $15
Misc:                     $15
──────────────────────────────
TOTAL:                    ~$230
```

#### Production (~$400-500)

```
EKS Control Plane:        $73
EC2 Nodes (2x t3.medium):  $30
NAT Gateway (3 AZs):      $96
RDS Multi-AZ (small):     $52
Redis Multi-AZ:           $48
DocumentDB (2 instances): $110
VPC Endpoints:            $22
Flow Logs:                $20
Container Insights:       $25
Backups & Monitoring:     $30
Misc:                     $20
──────────────────────────────
TOTAL:                    ~$450
```

### Cost Reduction Tips

1. **Use SPOT instances** where appropriate (non-prod)
2. **Scheduled scaling**: Scale down during off-hours
3. **Reserved instances**: For predictable production workloads
4. **S3 lifecycle policies**: Archive old Terraform state versions
5. **CloudWatch log retention**: Set appropriate retention periods
6. **Remove unused resources**: Regular cleanup of test resources

---

## 🔄 GitOps Workflow

This infrastructure is designed for GitOps practices:

### Recommended Workflow

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Feature   │      │    Pull     │      │   Merge to  │
│   Branch    │─────>│   Request   │─────>│    Main     │
└─────────────┘      └─────────────┘      └─────────────┘
       │                    │                     │
       │                    │                     │
       ▼                    ▼                     ▼
  Manual Test      Terraform Plan      Terraform Apply
   (terraform       (automated in        (automated in
    plan)                CI)                  CD)
```

### Git Branch Strategy

- **`main`**: Production-ready code
- **`develop`**: Integration branch for features
- **`feature/*`**: Individual feature branches
- **`hotfix/*`**: Emergency production fixes

### CI/CD Integration

#### Recommended Pipeline (GitHub Actions Example)

```yaml
name: Terraform Infrastructure

on:
  pull_request:
    paths:
      - "terraform/**"
  push:
    branches:
      - main
    paths:
      - "terraform/**"

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init
        working-directory: terraform/environments/${{ matrix.env }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: terraform/environments/${{ matrix.env }}

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: terraform/environments/${{ matrix.env }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Terraform Apply (on main branch)
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
        working-directory: terraform/environments/${{ matrix.env }}

    strategy:
      matrix:
        env: [dev, staging, prod]
```

### State Management

- **Backend**: S3 + DynamoDB
- **State Locking**: Prevents concurrent modifications
- **State Versioning**: S3 versioning enabled for rollback
- **Encryption**: State files encrypted at rest

### Best Practices

1. **Never commit** `terraform.tfvars` with sensitive data
2. **Always review** `terraform plan` output before applying
3. **Use pull requests** for all infrastructure changes
4. **Tag releases** for production deployments
5. **Document changes** in commit messages
6. **Test in dev first**, then promote to staging/prod
7. **Use semantic versioning** for infrastructure releases

---

## 🧪 Testing & Validation

### Pre-Deployment Checks

```bash
# Format check
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Security scanning (optional)
tfsec .

# Cost estimation (optional)
infracost breakdown --path .
```

### Post-Deployment Validation

```bash
# Verify EKS cluster
aws eks describe-cluster --name craftista-{env}-eks

# Check node status
kubectl get nodes

# Verify databases
aws rds describe-db-instances --db-instance-identifier craftista-{env}-postgres
aws elasticache describe-replication-groups --replication-group-id craftista-{env}-redis

# Test SSM access
aws ssm start-session --target <instance-id>

# Check VPC configuration
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values={env}"
```

---

## 🆘 Troubleshooting

### Common Issues

#### 1. Backend Configuration Errors

**Problem**: `Error initializing backend: NoSuchBucket`

**Solution**:

```bash
cd terraform/bootstrap
terraform apply  # Create the state bucket first
```

#### 2. State Lock Conflicts

**Problem**: `Error acquiring the state lock`

**Solution**:

```bash
# List locks
aws dynamodb scan --table-name craftista-infra-state-locks

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

#### 3. EKS Cluster Timeout

**Problem**: Cluster creation exceeds timeout

**Solution**:

- Check VPC and subnet configurations
- Verify IAM roles and policies
- Review CloudFormation stack events in AWS Console

#### 4. Database Connection Failures

**Problem**: Cannot connect to RDS/Redis/DocumentDB

**Solution**:

```bash
# Check security groups
terraform output database_security_group_id

# Verify subnets
terraform output database_subnets

# Test from EKS pod
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
apk add postgresql-client
psql -h <rds_endpoint> -U craftista_admin -d craftista
```

#### 5. Node Registration Issues

**Problem**: EKS nodes not joining cluster

**Solution**:

- Verify IAM role has required policies
- Check node security group rules
- Review node group launch template
- Check EKS cluster security group

### Getting Help

1. **Check logs**:

   ```bash
   # EKS control plane logs
   aws logs tail /aws/eks/craftista-{env}-eks/cluster --follow

   # Node logs via SSM
   aws ssm start-session --target <instance-id>
   sudo journalctl -u kubelet -f
   ```

2. **Terraform debug mode**:

   ```bash
   TF_LOG=DEBUG terraform apply
   ```

3. **AWS Support**: For infrastructure issues
4. **GitHub Issues**: Report bugs in this repository

---

## 📚 Additional Resources

### Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

### Related Repositories

- **Application Code**: [github.com/charliepoker/craftista](https://github.com/charliepoker/craftista)
- **Kubernetes Manifests**: (Link to your K8s manifests repo)
- **Helm Charts**: (Link to your Helm charts repo if applicable)

### Terraform Modules Used

- [terraform-aws-modules/vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [terraform-aws-modules/eks](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [terraform-aws-modules/kms](https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/latest)

---

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Contribution Workflow

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-new-feature`
3. **Make your changes** with clear commit messages
4. **Test your changes**: Run `terraform plan` in all environments
5. **Submit a pull request** with detailed description

### Code Standards

- Use consistent formatting: `terraform fmt`
- Add comments for complex logic
- Update documentation for new features
- Follow AWS and Terraform best practices
- Include variable descriptions and validation

### Pull Request Template

```markdown
## Description

Brief description of changes

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Environments Tested

- [ ] Dev
- [ ] Staging
- [ ] Prod

## Checklist

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex areas
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Terraform plan succeeds
```

---

## 📄 License

This infrastructure code is licensed under the **Apache License 2.0**.

```
Copyright 2025 Craftista Infrastructure Team

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## 🙏 Acknowledgments

- **School of DevOps**: For the Craftista application
- **HashiCorp**: For Terraform
- **AWS**: For cloud infrastructure
- **Terraform AWS Modules**: For reusable module components
- **Community Contributors**: For feedback and improvements

---

## 📞 Support

- **Email**: iheanachocharlie@example.com
- **GitHub Issues**: [Create an issue](https://github.com/charliepoker/craftista-infrastructure/issues)
- **Documentation**: See environment-specific READMEs in each directory

---

## 🗺️ Roadmap

### Planned Features

- [ ] ArgoCD integration for GitOps
- [ ] Terraform Cloud/Enterprise workspace configuration
- [ ] Multi-region support
- [ ] Disaster recovery automation
- [ ] Cost optimization recommendations
- [ ] Compliance scanning (CIS benchmarks)
- [ ] Infrastructure drift detection
- [ ] Automated testing with Terratest
- [ ] Service mesh integration (Istio/Linkerd)
- [ ] Observability stack (Prometheus, Grafana)

### Version History

- **v1.0.0** (2025-11-22): Initial release with Dev, Staging, Prod environments
  - AWS EKS 1.30
  - SSM Session Manager integration
  - Multi-environment support
  - Complete database layer

---

<div align="center">

**Built with ❤️ for the DevOps Community**

[⬆ Back to Top](#craftista-infrastructure-as-code-iac)

</div>
