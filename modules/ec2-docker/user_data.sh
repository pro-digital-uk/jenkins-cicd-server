#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/jenkins-docker-setup.log)
exec 2>&1

echo "Starting Docker Jenkins installation and setup..."
echo "Timestamp: $(date)"

# Update system packages
yum update -y
yum install -y wget git docker

# Create jenkins user for docker group
usermod -a -G docker ec2-user

# Start Docker daemon
echo "Starting Docker service..."
systemctl enable docker
systemctl start docker
sleep 2

# Create Jenkins data directory with proper permissions
echo "Creating Jenkins data directory..."
mkdir -p /jenkins-data
# Jenkins container runs as UID 1000, set permissions accordingly
chown 1000:1000 /jenkins-data
chmod 755 /jenkins-data

# Pull Jenkins Docker image
echo "Pulling Jenkins Docker image (lts)..."
docker pull jenkins/jenkins:lts

# Create Jenkins container
echo "Starting Jenkins Docker container..."
docker run -d \
  --name jenkins \
  --restart always \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -e JENKINS_OPTS="--httpPort=8080" \
  -e JAVA_OPTS="-Xmx512m -Xms512m" \
  jenkins/jenkins:lts

# Wait for Jenkins to start
echo "Waiting for Jenkins to initialize (up to 60 seconds)..."
for i in {1..60}; do
  if docker logs jenkins 2>/dev/null | grep -q "Jenkins is fully up and running"; then
    echo "Jenkins is ready!"
    break
  fi
  echo "Waiting... ($i/60)"
  sleep 1
done

# Wait for initial admin password to be created
echo "Waiting for initial admin password file..."
for i in {1..30}; do
  if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
    echo "Admin password file found!"
    break
  fi
  echo "Waiting for password... ($i/30)"
  sleep 1
done

# Display Jenkins information
echo ""
echo "========================================"
echo "Docker Jenkins setup complete!"
echo "========================================"
echo "Container Name: jenkins"
echo "Jenkins Port: 8080"
echo "Jenkins Home: /jenkins-data"
echo "Instance IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "Get initial admin password:"
echo "  docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "Or SSH to instance:"
echo "  ssh -i jenkins-server-key.pem ec2-user@<PUBLIC_IP>"
echo "  docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"
echo "========================================"

# Log system information
echo ""
echo "System Information:"
echo "Docker version:"
docker --version
echo "Docker running containers:"
docker ps
echo "Jenkins container logs:"
docker logs jenkins | tail -20
