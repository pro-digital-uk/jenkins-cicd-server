#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/jenkins-setup.log)
exec 2>&1

echo "Starting Jenkins installation and setup..."
echo "Timestamp: $(date)"

# Update system packages
yum update -y
yum install -y wget git java-17-amazon-corretto-devel

# Install Jenkins
echo "Installing Jenkins..."
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum install -y jenkins

# Fix Jenkins systemd service file (Amazon Linux 2 compatibility)
echo "Fixing Jenkins systemd service compatibility..."
if grep -q "StartLimitBurst" /usr/lib/systemd/system/jenkins.service; then
    sed -i '/^\[Unit\]/,/^\[Service\]/{/StartLimitBurst/d; /StartLimitIntervalSec/d;}' /usr/lib/systemd/system/jenkins.service
    echo "Removed incompatible StartLimit parameters from Jenkins service"
fi

# Create jenkins user if not exists
id -u jenkins > /dev/null 2>&1 || useradd -m -s /bin/bash jenkins

# Configure Jenkins
echo "Configuring Jenkins..."

# Set Jenkins port
sed -i 's/JENKINS_PORT="8080"/JENKINS_PORT="8080"/g' /etc/sysconfig/jenkins

# Set Jenkins home
mkdir -p /var/lib/jenkins
chown -R jenkins:jenkins /var/lib/jenkins

# Install AWS CLI
yum install -y aws-cli

# Configure AWS access for Jenkins to S3
mkdir -p /var/lib/jenkins/.aws
cat > /var/lib/jenkins/.aws/config << EOF
[default]
region = us-east-1
output = json
EOF

chown -R jenkins:jenkins /var/lib/jenkins/.aws
chmod 700 /var/lib/jenkins/.aws

# Install Docker
echo "Installing Docker..."
amazon-linux-extras install -y docker
usermod -a -G docker jenkins
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Start Jenkins
echo "Starting Jenkins service..."
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to initialize..."
sleep 30

# Display Jenkins initial admin password location
echo "Jenkins setup complete!"
echo "Initial admin password location: /var/lib/jenkins/secrets/initialAdminPassword"
echo "S3 Bucket configured: ${S3_BUCKET_NAME}"
echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}'):8080"

# Log system information
echo ""
echo "System Information:"
echo "Java version:"
java -version
echo "Jenkins version:"
jenkins --version 2>/dev/null || echo "Jenkins service starting..."
echo "Docker version:"
docker --version
echo "Docker Compose version:"
docker-compose --version
