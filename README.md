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
  - [Step 1-6: Infrastructure Deployment](#step-1-bootstrap-infrastructure)
  - [Step 7-10: GitOps & Secrets Setup](#-post-deployment-gitops--secrets-setup)
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
# Get sensitive outputs (save these for Vault setup)
terraform output -raw rds_master_password
terraform output -raw redis_auth_token
terraform output -raw docdb_master_password
terraform output -raw rds_endpoint
terraform output -raw redis_endpoint
terraform output -raw docdb_endpoint

# Or all outputs as JSON
terraform output -json > infrastructure-outputs.json
```

---

## 🔐 Post-Deployment: GitOps & Secrets Setup

After infrastructure deployment, proceed with GitOps and secrets management configuration.

### Step 9: Setup ArgoCD and Vault

The Craftista application uses a GitOps approach with ArgoCD for continuous deployment and HashiCorp Vault with External Secrets Operator for secure secrets management.

#### 9.1 Clone GitOps Repository

```bash
# Clone the GitOps repository
git clone https://github.com/charliepoker/craftista-gitops.git
cd craftista-gitops
```

#### 9.2 Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f argocd/install/argocd-install.yaml

# Apply custom configuration
kubectl apply -n argocd -f argocd/install/argocd-cm.yaml
kubectl apply -n argocd -f argocd/install/argocd-rbac-cm.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Access ArgoCD UI (port forward)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

#### 9.3 Install HashiCorp Vault

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set "server.ha.enabled=true" \
  --set "server.ha.replicas=3" \
  --set "server.ha.raft.enabled=true"

# Wait for Vault pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault \
  -n vault --timeout=300s
```

#### 9.4 Initialize and Unseal Vault

```bash
# Initialize Vault (run once only)
kubectl exec vault-0 -n vault -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-init-keys.json

# IMPORTANT: Backup vault-init-keys.json securely and DO NOT commit to Git

# Unseal Vault on each pod
UNSEAL_KEY_1=$(cat vault-init-keys.json | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat vault-init-keys.json | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat vault-init-keys.json | jq -r '.unseal_keys_b64[2]')

# Unseal vault-0
kubectl exec vault-0 -n vault -- vault operator unseal $UNSEAL_KEY_1
kubectl exec vault-0 -n vault -- vault operator unseal $UNSEAL_KEY_2
kubectl exec vault-0 -n vault -- vault operator unseal $UNSEAL_KEY_3

# Repeat for vault-1 and vault-2 if using HA setup
kubectl exec vault-1 -n vault -- vault operator unseal $UNSEAL_KEY_1
kubectl exec vault-1 -n vault -- vault operator unseal $UNSEAL_KEY_2
kubectl exec vault-1 -n vault -- vault operator unseal $UNSEAL_KEY_3

kubectl exec vault-2 -n vault -- vault operator unseal $UNSEAL_KEY_1
kubectl exec vault-2 -n vault -- vault operator unseal $UNSEAL_KEY_2
kubectl exec vault-2 -n vault -- vault operator unseal $UNSEAL_KEY_3
```

#### 9.5 Configure Vault Authentication and Policies

```bash
# Set Vault environment variables
export VAULT_TOKEN=$(cat vault-init-keys.json | jq -r '.root_token')
export VAULT_ADDR="http://localhost:8200"

# Port forward to Vault
kubectl port-forward -n vault vault-0 8200:8200 &

# Make auth scripts executable
chmod +x vault/auth/kubernetes-auth.sh
chmod +x vault/auth/github-oidc-auth.sh

# Configure Kubernetes authentication
./vault/auth/kubernetes-auth.sh

# Apply Vault policies for each service
kubectl exec vault-0 -n vault -- sh -c "cat > /tmp/frontend-policy.hcl" < vault/policies/frontend-policy.hcl
kubectl exec vault-0 -n vault -- vault policy write frontend-policy /tmp/frontend-policy.hcl

kubectl exec vault-0 -n vault -- sh -c "cat > /tmp/catalogue-policy.hcl" < vault/policies/catalogue-policy.hcl
kubectl exec vault-0 -n vault -- vault policy write catalogue-policy /tmp/catalogue-policy.hcl

kubectl exec vault-0 -n vault -- sh -c "cat > /tmp/voting-policy.hcl" < vault/policies/voting-policy.hcl
kubectl exec vault-0 -n vault -- vault policy write voting-policy /tmp/voting-policy.hcl

kubectl exec vault-0 -n vault -- sh -c "cat > /tmp/recommendation-policy.hcl" < vault/policies/recommendation-policy.hcl
kubectl exec vault-0 -n vault -- vault policy write recommendation-policy /tmp/recommendation-policy.hcl

# Optional: Configure GitHub Actions OIDC for CI/CD
export GITHUB_ORG="charliepoker"
export GITHUB_REPO="craftista"
./vault/auth/github-oidc-auth.sh
```

#### 9.6 Populate Vault with Secrets

```bash
# Make sync script executable
chmod +x scripts/sync-secrets.sh

# Set required environment variables from Terraform outputs
export MONGODB_URI="mongodb://craftista_admin:$(cd ../Craftista-IaC/environments/{env} && terraform output -raw docdb_master_password)@$(cd ../Craftista-IaC/environments/{env} && terraform output -raw docdb_endpoint):27017/catalogue?ssl=true&replicaSet=rs0&readPreference=secondaryPreferred"

export POSTGRES_URI="postgresql://craftista_admin:$(cd ../Craftista-IaC/environments/{env} && terraform output -raw rds_master_password)@$(cd ../Craftista-IaC/environments/{env} && terraform output -raw rds_endpoint):5432/voting"

export REDIS_URI="redis://:$(cd ../Craftista-IaC/environments/{env} && terraform output -raw redis_auth_token)@$(cd ../Craftista-IaC/environments/{env} && terraform output -raw redis_endpoint):6379"

# Set DockerHub credentials for image pull
export DOCKERHUB_USERNAME="your-dockerhub-username"
export DOCKERHUB_PASSWORD="your-dockerhub-password"

# Run secrets sync script for your environment (dev, staging, or prod)
./scripts/sync-secrets.sh --environment dev

# For production, use:
# ./scripts/sync-secrets.sh --environment prod
```

#### 9.7 Install External Secrets Operator

```bash
# Add External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/external-secrets -n external-secrets-system
```

#### 9.8 Deploy External Secrets Configuration

```bash
# Create namespaces for each environment
kubectl create namespace craftista-dev
kubectl create namespace craftista-staging
kubectl create namespace craftista-prod

# Deploy service accounts for External Secrets
kubectl apply -f external-secrets/overlays/dev/serviceaccount.yaml
kubectl apply -f external-secrets/overlays/staging/serviceaccount.yaml
kubectl apply -f external-secrets/overlays/prod/serviceaccount.yaml

# Deploy SecretStores (connects ESO to Vault)
kubectl apply -f external-secrets/cluster-secret-store.yaml
kubectl apply -f external-secrets/overlays/dev/secret-store.yaml
kubectl apply -f external-secrets/overlays/staging/secret-store.yaml
kubectl apply -f external-secrets/overlays/prod/secret-store.yaml

# Deploy ExternalSecrets (syncs secrets from Vault to K8s Secrets)
kubectl apply -f external-secrets/overlays/dev/
kubectl apply -f external-secrets/overlays/staging/
kubectl apply -f external-secrets/overlays/prod/

# Verify ExternalSecrets are syncing
kubectl get externalsecrets -A
kubectl get secrets -n craftista-dev
```

#### 9.9 Deploy ArgoCD Applications

```bash
# Create ArgoCD projects
kubectl apply -f argocd/projects/craftista-dev.yaml
kubectl apply -f argocd/projects/craftista-staging.yaml
kubectl apply -f argocd/projects/craftista-prod.yaml

# Deploy applications for your environment (example: dev)
kubectl apply -f argocd/applications/dev/frontend-app.yaml
kubectl apply -f argocd/applications/dev/catalogue-app.yaml
kubectl apply -f argocd/applications/dev/voting-app.yaml
kubectl apply -f argocd/applications/dev/recommendation-app.yaml

# For production:
# kubectl apply -f argocd/applications/prod/

# Verify applications in ArgoCD
kubectl get applications -n argocd

# Check application sync status
argocd app list
argocd app get craftista-frontend-dev
```

#### 9.10 Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n craftista-dev

# Verify secrets are created from Vault
kubectl get secrets -n craftista-dev

# Check ExternalSecret sync status
kubectl describe externalsecret frontend-secrets -n craftista-dev

# View application logs
kubectl logs -l app=frontend -n craftista-dev

# Access the application
kubectl get svc -n craftista-dev
kubectl port-forward svc/frontend -n craftista-dev 3000:3000
```

### Architecture: GitOps & Secrets Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS EKS Cluster                         │
│                                                              │
│  ┌────────────┐    ┌──────────────┐    ┌────────────────┐ │
│  │  ArgoCD    │───>│  Kubernetes  │<───│  External      │ │
│  │            │    │  Deployments │    │  Secrets       │ │
│  │  Syncs     │    │              │    │  Operator      │ │
│  │  from Git  │    │  - Frontend  │    │                │ │
│  │            │    │  - Catalogue │    │  Syncs secrets │ │
│  └────────────┘    │  - Voting    │    │  from Vault    │ │
│         │          │  - Recommend │    └────────┬───────┘ │
│         │          └──────────────┘              │          │
│         │                                        │          │
│         ▼                                        ▼          │
│  ┌────────────────────────────────────────────────────────┐│
│  │            GitHub: craftista-gitops                    ││
│  │  • Kubernetes manifests                               ││
│  │  • ArgoCD applications                                ││
│  │  • External Secrets definitions                       ││
│  └────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌────────────┐                                             │
│  │  Vault     │<────────────────────────────────────────────┤
│  │            │  External Secrets fetches secrets           │
│  │  Stores:   │  Apps consume via K8s Secrets               │
│  │  • DB URIs │                                             │
│  │  • API Keys│                                             │
│  │  • Tokens  │                                             │
│  └────────────┘                                             │
└─────────────────────────────────────────────────────────────┘
```

### Secret Management Strategy

The deployment uses **HashiCorp Vault** as the single source of truth for all secrets, with **External Secrets Operator** automatically syncing them to Kubernetes Secrets.

**Secrets stored in Vault:**

- Database connection strings (PostgreSQL, MongoDB, Redis)
- API keys and JWT secrets
- DockerHub credentials for image pulls
- Service-specific configuration

**Benefits:**

- ✅ Centralized secret management
- ✅ Automatic secret rotation support
- ✅ Audit logging of secret access
- ✅ Fine-grained access control per service
- ✅ Secrets never stored in Git
- ✅ Environment isolation (dev/staging/prod)

**Service Account Strategy:**
Each microservice has its own Kubernetes ServiceAccount that:

1. Authenticates to Vault via Kubernetes auth method
2. Has access only to its specific secrets via Vault policies
3. Secrets are automatically injected as Kubernetes Secrets
4. Applications consume secrets as environment variables

For detailed secrets management documentation, see the [craftista-gitops repository](https://github.com/charliepoker/craftista-gitops):

- `vault/README.md` - Vault integration guide
- `external-secrets/README.md` - External Secrets configuration
- `argocd/docs/deployment-guide.md` - Complete deployment guide

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
| 