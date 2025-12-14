#!/bin/bash
# Nexus Repository Manager Installation Script - Production Standard

set -e

ENVIRONMENT="${environment}"
LOG_FILE="/var/log/nexus-install.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Starting Nexus Repository Manager installation for environment: $ENVIRONMENT"

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
    
    mkdir -p /opt/nexus
    mount /dev/xvdf /opt/nexus
    echo "/dev/xvdf /opt/nexus ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Create Nexus directories with proper permissions
log "Creating Nexus directories..."
mkdir -p /opt/nexus/data
chmod -R 777 /opt/nexus
chown -R 200:200 /opt/nexus/data

# Run Nexus container (no sudo needed after group changes)
log "Starting Nexus container..."
docker run -d \
    --name nexus \
    --restart unless-stopped \
    --user 200:200 \
    -p 8081:8081 \
    -p 8082:8082 \
    -v /opt/nexus/data:/nexus-data \
    -e NEXUS_SECURITY_RANDOMPASSWORD=false \
    -e INSTALL4J_ADD_VM_PARAMS="-Xms1g -Xmx2g -XX:MaxDirectMemorySize=3g" \
    sonatype/nexus3

# Wait for Nexus to initialize
log "Waiting for Nexus to initialize..."
sleep 60

# Wait for Nexus to be ready
log "Waiting for Nexus to be fully ready..."
for i in {1..30}; do
    if curl -s http://localhost:8081/ > /dev/null; then
        log "Nexus is ready!"
        break
    fi
    log "Waiting for Nexus to start... attempt $i/30"
    sleep 10
done

# Stop Nexus to configure context path
log "Stopping Nexus to configure context path..."
docker stop nexus
docker rm nexus

# Configure Nexus properties for ALB context path
log "Configuring Nexus properties..."
mkdir -p /opt/nexus/data/etc
cat > /opt/nexus/data/etc/nexus.properties << 'EOFNEXUS'
# Nexus configuration for ALB routing
application-port=8081
application-host=0.0.0.0
nexus-args=$${jetty.etc}/jetty.xml,$${jetty.etc}/jetty-http.xml,$${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/nexus
EOFNEXUS

# Restart Nexus with context path configuration
log "Starting Nexus with context path configuration..."
docker run -d \
    --name nexus \
    --restart unless-stopped \
    --user 200:200 \
    -p 8081:8081 \
    -p 8082:8082 \
    -v /opt/nexus/data:/nexus-data \
    -e NEXUS_SECURITY_RANDOMPASSWORD=false \
    -e INSTALL4J_ADD_VM_PARAMS="-Xms1g -Xmx2g -XX:MaxDirectMemorySize=3g" \
    sonatype/nexus3

# Verify container is running
log "Verifying Nexus container status..."
sleep 10
if docker ps | grep -q nexus; then
    log "Nexus container started successfully with context path /nexus!"
else
    log "ERROR: Nexus container failed to start. Check logs with: docker logs nexus"
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
                        "file_path": "/var/log/nexus-install.log",
                        "log_group_name": "/aws/ec2/nexus/$ENVIRONMENT",
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

log "Nexus Repository Manager installation completed successfully!"
log "Nexus will be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8081"
log "Docker registry will be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8082"