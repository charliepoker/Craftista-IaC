#!/bin/bash
set -ex

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

# Update system packages
yum update -y

# Configure kubelet with custom arguments
KUBELET_EXTRA_ARGS="${bootstrap_arguments}"

# Join the EKS cluster
/etc/eks/bootstrap.sh ${cluster_name} \
  --b64-cluster-ca "${cluster_ca}" \
  --apiserver-endpoint "${cluster_endpoint}" \
  --kubelet-extra-args "$KUBELET_EXTRA_ARGS"

# Install and configure SSM agent for management
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

echo "Node initialization completed successfully"
