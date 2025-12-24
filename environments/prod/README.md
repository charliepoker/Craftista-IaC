# Craftista Production Environment

This directory contains the Terraform infrastructure code for the **Production** environment of the Craftista application.

## Overview

The production environment is designed for:

- Running live production workloads
- High availability and fault tolerance
- Enhanced monitoring and alerting
- Automated backups and disaster recovery
- Security and compliance requirements

**Key Principle**: Maximum reliability, availability, and security. Production infrastructure prioritizes stability over cost optimization, with proper redundancy, monitoring, and protection mechanisms in place.

## 🏗️ Infrastructure Components

### Networking

- **VPC CIDR**: `10.0.0.0/16`
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **Subnets**:
  - Public: 3 subnets
  - Private: 3 subnets
  - Database: 3 subnets
- **NAT Gateways**: 3 (one per AZ for high availability)
- **VPC Flow Logs**: Enabled (S3)
- **VPC Endpoints**: Essential services (S3, ECR, Logs)

### Production Features

- Multi-AZ NAT Gateways for redundancy
- ON_DEMAND instances for reliability
- Multi-AZ database deployments
- Container Insights enabled
- Extended backup retention (7-30 days)
- Deletion protection on critical resources
- Performance Insights enabled
- Enhanced monitoring

### Compute

- **EKS Cluster**: Kubernetes 1.30
- **Node Group**:
  - 2-4 nodes (autoscaling enabled)
  - Instance: t3.medium ON_DEMAND
  - 50 GB disk
  - IRSA enabled for pod-level IAM permissions
  - IMDSv2 enforced

### Databases

- **PostgreSQL**: db.t4g.micro, Multi-AZ with automatic failover
- **Redis**: cache.t3.micro, 2 nodes with automatic failover enabled
- **DocumentDB**: db.t3.medium, 2 instances for high availability

### DevOps Tools

- **SonarQube**: t3.large instance
- **Nexus**: t3.large instance
- Access via SSM Session Manager (no SSH keys)
- Larger EBS volumes for production data

## 📁 Files

```
prod/
├── provider.tf          # Terraform and AWS provider configuration
├── locals.tf            # Local values and tags
├── variables.tf         # Variable definitions with production defaults
├── terraform.tfvars     # Actual values for production environment
├── main.tf              # Main infrastructure resources
├── monitoring.tf        # CloudWatch alarms and monitoring
├── security.tf          # Additional security configurations
├── outputs.tf           # Output values
└── README.md            # This file
```

## 🚀 Getting Started

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.5.0
3. **kubectl** for Kubernetes management
4. **Backend setup**: S3 bucket and DynamoDB table for state
5. **SNS Topic**: For CloudWatch alarms (recommended)

### Initialize Terraform

```bash
cd environments/prod
terraform init
```

### Review the Plan

⚠️ **Important**: Always review the plan carefully before applying to production.

```bash
terraform plan
```

### Apply the Infrastructure

```bash
terraform apply
```

This will take approximately **20-25 minutes** to complete due to Multi-AZ deployments.

## 🔐 Accessing the Cluster

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig \
  --name craftista-prod \
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

# Database endpoints
terraform output rds_endpoint
terraform output redis_primary_endpoint
terraform output docdb_cluster_endpoint

# Load balancer
terraform output alb_dns_name
```

## 🔄 Common Operations

### Update the Infrastructure

⚠️ **Production Change Management**: Always test changes in staging first!

```bash
terraform plan
# Review the plan carefully
terraform apply
```

### Scale the Node Group

For production, scaling should be done carefully and during maintenance windows.

Edit `terraform.tfvars`:

```hcl
node_groups = {
  main = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 6      # Increase max capacity
    desired_size   = 4      # Scale up for increased load
    capacity_type  = "ON_DEMAND"
    disk_size      = 50
    taints         = []
  }
}
```

Then apply during a maintenance window:

```bash
terraform apply
```

### Disaster Recovery

#### Backup Verification

Regularly verify backups are being created:

```bash
# RDS snapshots
aws rds describe-db-snapshots --db-instance-identifier craftista-prod

# DocumentDB snapshots
aws docdb describe-db-cluster-snapshots --db-cluster-identifier craftista-prod-docdb

# Redis snapshots
aws elasticache describe-snapshots --cache-cluster-id craftista-prod-redis
```

#### Restore from Backup

In case of data loss, restore from the latest backup. Update `terraform.tfvars` with snapshot identifiers before applying.

### Destroy the Environment

⚠️ **DANGER**: This is production! Do NOT run this command unless you absolutely know what you're doing.

Production resources have deletion protection enabled. You must first disable it:

1. Edit `terraform.tfvars`:

   ```hcl
   rds_deletion_protection = false
   docdb_deletion_protection = false
   ```

2. Apply the change:

   ```bash
   terraform apply
   ```

3. Only then can you destroy (if you really must):
   ```bash
   terraform destroy
   ```

## 🛡️ Security Features

### Enabled in Production:

- ✅ Multi-AZ deployments for high availability
- ✅ Encryption at rest (RDS, DocumentDB, EBS, S3)
- ✅ Encryption in transit (TLS/SSL)
- ✅ VPC Flow Logs to S3
- ✅ Security Groups with least privilege
- ✅ Private subnets for databases and compute
- ✅ IMDSv2 enforced on EC2 instances
- ✅ IRSA for Kubernetes pod IAM roles
- ✅ SSM Session Manager (no SSH keys)
- ✅ Deletion protection on databases
- ✅ Automated backups with retention
- ✅ Performance Insights
- ✅ Enhanced monitoring
- ✅ Container Insights
- ✅ CloudWatch alarms

## 📊 Monitoring

### CloudWatch Dashboards

Production includes comprehensive monitoring:

- EKS cluster metrics
- Node and pod resource utilization
- Database performance metrics
- Application logs
- VPC Flow Logs

### CloudWatch Alarms

Configure SNS topic for alerts in `terraform.tfvars`:

```hcl
alarm_sns_topic_arn = "arn:aws:sns:us-east-1:ACCOUNT_ID:production-alerts"
```

Key alarms include:

- High CPU utilization
- High memory usage
- Database connection issues
- Disk space warnings
- Network anomalies

### Container Insights

Enabled by default in production for deep visibility:

```bash
# View Container Insights in AWS Console
# CloudWatch > Container Insights > Performance Monitoring
```

### Application Logs

```bash
# EKS control plane logs
aws logs tail /aws/eks/craftista-prod/cluster --follow

# VPC Flow Logs
aws logs tail <vpc-flow-log-group> --follow

# Application logs (from pods)
kubectl logs -f <pod-name> -n <namespace>
```

### Kubernetes Metrics

```bash
# Node metrics
kubectl top nodes

# Pod metrics by namespace
kubectl top pods -n production

# Describe node for events
kubectl describe node <node-name>
```

## 📋 Production Checklist

Before going live, ensure:

- [ ] All database passwords are stored in AWS Secrets Manager
- [ ] SNS topic configured for CloudWatch alarms
- [ ] Backup retention periods configured appropriately
- [ ] Multi-AZ enabled for all databases
- [ ] Deletion protection enabled
- [ ] Container Insights enabled
- [ ] Performance Insights enabled
- [ ] VPC Flow Logs enabled
- [ ] All monitoring dashboards created
- [ ] Incident response procedures documented
- [ ] Backup restore procedures tested
- [ ] Disaster recovery plan in place
- [ ] Cost alerts configured
- [ ] Tags applied to all resources

## 📝 Variables Reference

### Key Variables to Modify:

| Variable                         | Default      | Description                            |
| -------------------------------- | ------------ | -------------------------------------- |
| `aws_region`                     | us-east-1    | AWS region                             |
| `environment`                    | prod         | Environment name                       |
| `node_groups.main.desired_size`  | 2            | Number of nodes                        |
| `node_groups.main.capacity_type` | ON_DEMAND    | Instance purchasing option             |
| `rds_instance_class`             | db.t4g.micro | RDS instance size                      |
| `rds_multi_az`                   | true         | Enable Multi-AZ for RDS                |
| `redis_num_cache_clusters`       | 2            | Number of Redis nodes                  |
| `docdb_instance_count`           | 2            | Number of DocumentDB instances         |
| `enable_container_insights`      | true         | Enable Container Insights              |
| `rds_deletion_protection`        | true         | Prevent accidental RDS deletion        |
| `docdb_deletion_protection`      | true         | Prevent accidental DocumentDB deletion |
| `budget_amount`                  | 10           | Monthly budget alert (USD)             |

See `variables.tf` for complete list.

---
