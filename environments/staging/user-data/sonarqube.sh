#!/bin/bash
# SonarQube Installation Script - Production Standard

set -e

ENVIRONMENT="${environment}"
LOG_FILE="/var/log/sonarqube-install.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting SonarQube installation for environment: $ENVIRONMENT"

# Update system and install packages
log "Updating system and installing packages..."
yum update -y
yum install -y docker amazon-cloudwatch-agent

# Start Docker
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Add ec2-user to docker group and fix socket permissions
log "Configuring Docker permissions..."
usermod -aG docker ec2-user
chmod 666 /var/run/docker.sock

# Ensure docker group changes take effect
newgrp docker || true

# Set up data volume
log "Setting up data volume..."
if lsblk | grep -q xvdf; then
    if ! file -s /dev/xvdf | grep -q filesystem; then
        log "Formatting data volume..."
        mkfs -t ext4 /dev/xvdf
    fi
    
    mkdir -p /opt/sonarqube
    mount /dev/xvdf /opt/sonarqube
    echo "/dev/xvdf /opt/sonarqube ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Create SonarQube directories with proper permissions
log "Creating SonarQube directories..."
mkdir -p /opt/sonarqube/{data,logs,extensions}
chmod -R 777 /opt/sonarqube
chown -R 1000:1000 /opt/sonarqube

# Set system parameters for SonarQube
log "Configuring system parameters..."
cat >> /etc/sysctl.conf << 'EOF'
vm.max_map_count=524288
fs.file-max=131072
EOF
sysctl -p

# Run SonarQube container (no sudo needed after group changes)
log "Starting SonarQube container..."
docker run -d \
    --name sonarqube \
    --restart unless-stopped \
    --user 1000:1000 \
    -p 9000:9000 \
    -v /opt/sonarqube/data:/opt/sonarqube/data \
    -v /opt/sonarqube/logs:/opt/sonarqube/logs \
    -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    sonarqube:community

# Verify container is running
log "Verifying SonarQube container status..."
sleep 5
if docker ps | grep -q sonarqube; then
    log "SonarQube container started successfully!"
else
    log "ERROR: SonarQube container failed to start. Check logs with: docker logs sonarqube"
    exit 1
fi

# Configure CloudWatch agent
log "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/sonarqube-install.log",
                        "log_group_name": "/aws/ec2/sonarqube/$ENVIRONMENT",
                        "log_stream_name": "{instance_id}/install.log"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

log "SonarQube installation completed successfully!"
log "SonarQube will be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"