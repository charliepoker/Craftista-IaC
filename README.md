# Craftista Infrastructure as Code (IaC)

> **GitOps-Ready Terraform Infrastructure for the Craftista Application**

This repository contains the complete infrastructure as code (IaC) for deploying the Craftista application on AWS using Terraform. Designed following GitOps principles, this infrastructure supports multi-environment deployments with best practices for security, scalability, and cost optimization.

[![Terraform](https://img.shields.io/badge/Terraform-≥1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## 📋 Table of Contents

- [Craftista Infrastructure as Code (IaC)](#craftista-infrastructure-as-code-iac)
  - [📋 Table of Contents](#-table-of-contents)
  - [🎯 Overview](#-overview)
    - [Why This Architecture?](#why-this-architecture)
    - [Deployment Flow](#deployment-flow)
  - [🏗️ Architecture](#️-architecture)
    - [High-Level Architecture](#high-level-architecture)
    - [Components](#components)
      - [Compute](#compute)
      - [Networking](#networking)
      - [Data Layer](#data-layer)
      - [Security \& Compliance](#security--compliance)
      - [Operations](#operations)
  - [📁 Repository Structure](#-repository-structure)
    - [File Descriptions](#file-descriptions)
  - [🔧 Prerequisites](#-prerequisites)
    - [Required Tools](#required-tools)
    - [AWS Requirements](#aws-requirements)
    - [Recommended Knowledge](#recommended-knowledge)
  - [🚀 Quick Start](#-quick-start)
    - [Step 1: Bootstrap Infrastructure](#step-1-bootstrap-infrastructure)
    - [Step 2: Choose Your Environment](#step-2-choose-your-environment)
    - [Step 3: Configure Variables](#step-3-configure-variables)
    - [Step 4: Initialize Terraform](#step-4-initialize-terraform)
    - [Step 5: Plan the Deployment](#step-5-plan-the-deployment)
    - [Step 6: Deploy Infrastructure](#step-6-deploy-infrastructure)

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
- **GitOps Ready**: ArgoCD integration for continuous deployment from Git
- **Secrets Management**: HashiCorp Vault with External Secrets Operator for secure secret handling

### Why This Architecture?

- **Microservices-First**: Built specifically for the Craftista polyglot application
- **Cloud-Native**: Leverages AWS managed services for reduced operational overhead
- **Security-Focused**: Implements AWS security best practices including SSM, encryption, Vault, and least-privilege IAM
- **Cost-Optimized**: Different resource sizing per environment with budget controls
- **Production-Ready**: High availability, automated backups, and monitoring
- **GitOps Native**: Full GitOps workflow with ArgoCD and declarative secret management

### Deployment Flow

```
Infrastructure (Terraform) → GitOps Setup (ArgoCD) → Secrets (Vault + ESO) → Applications
     This Repo              craftista-gitops repo    craftista-gitops repo   Auto-deployed
```

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


