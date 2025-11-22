# Production Environment

## Overview

Production infrastructure for Craftista application using AWS modules.

## Usage

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Components

- VPC with multi-AZ subnets
- ECS cluster for containerized services
- RDS PostgreSQL for voting service
- DocumentDB for catalogue service
- Redis ElastiCache for caching
- Application Load Balancer
- CloudWatch monitoring
- Security groups and IAM roles
