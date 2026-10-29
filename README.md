# Jenkins CI/CD Server

Production-ready Jenkins CI/CD server deployment on AWS using Terraform. Remote state managed in S3, automatic Jenkins installation, Docker support, and enterprise-grade security.

**✅ Remote-first architecture** | **✅ Zero-downtime updates** | **✅ Development optimized** | **✅ Production ready**

## Quick Start (10 minutes)

### Prerequisites
- AWS CLI configured: `aws configure`
- Terraform installed: `terraform --version ≥ 1.0`
- Bash shell access

### Step 1: Create Remote State Backend (5 min)

```bash
git clone <repo-url>
cd jenkins-cicd-server

# Create S3 bucket and DynamoDB table for remote state
./scripts/create-terraform-state-bucket.sh \
  --bucket-name cicd-state-bucket-$(date +%s) \
  --region eu-west-2
```

This creates:
- ✅ S3 bucket with encryption, versioning, access logging
- ✅ DynamoDB table for state locking
- ✅ Lifecycle policies (90-day version retention)

### Step 2: Configure and Initialize

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit if needed (defaults work for most cases)
# aws_region is already set to eu-west-2
# environment is set to dev
nano terraform.tfvars

# Initialize Terraform with remote state
terraform init
```

### Step 3: Plan Infrastructure

```bash
# Review what will be created
terraform plan -out=tfplan

# Should show: Plan: 34 to add, 0 to change, 0 to destroy
```

### Step 4: Deploy

```bash
# Deploy infrastructure (takes ~10-15 minutes)
terraform apply tfplan

# Wait for EC2 user data to complete (~5 minutes after instance launches)
```

### Step 5: Access Jenkins

```bash
# Get Jenkins URL
terraform output jenkins_url

# SSH to instance (after user data completes)
PUBLIC_IP=$(terraform output -raw ec2_instance_public_ip)
ssh -i jenkins-server-key.pem ec2-user@$PUBLIC_IP

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Open browser: http://<PUBLIC_IP>:8080
```

### Complete Workflow
```bash
# One-liner deployment
./scripts/create-terraform-state-bucket.sh --region eu-west-2 && \
  terraform init && \
  terraform plan -out=tfplan && \
  terraform apply tfplan
```

**📖 See [REMOTE_STATE_SETUP.md](REMOTE_STATE_SETUP.md) for detailed remote state setup**

## Architecture

```
VPC (eu-west-2, 10.0.0.0/16)
├── Public Subnet A (10.0.1.0/24)
│   └── Jenkins EC2 (t3.medium)
│       ├── Public IP (elastic)
│       ├── Security Group (8080, 22, 443)
│       ├── 50GB encrypted EBS
│       └── IAM Role (S3 access)
├── Public Subnet B (10.0.2.0/24) - for HA
├── Private Subnet A (10.0.10.0/24) - future use
├── Private Subnet B (10.0.11.0/24) - future use
├── Internet Gateway (public subnet routing)
└── Route Tables (public & private)

State Management
├── S3 Bucket (terraform-state)
│   ├── Encryption (AES256)
│   ├── Versioning (90-day history)
│   └── Access Logging
└── DynamoDB Table (terraform-locks)
    └── State locking (prevents concurrent writes)

Storage
└── S3 Bucket (artifact storage)
    ├── Encryption (AES256)
    ├── Versioning enabled
    └── Lifecycle policies

SSH Access
└── Key Pair (4096-bit RSA)
    └── jenkins-server-key.pem (local, gitignored)
```

## Components

| Component | Details | Cost |
|-----------|---------|------|
| **VPC** | 10.0.0.0/16, multi-AZ subnets | Free |
| **EC2** | t3.medium, Amazon Linux 2, 50GB gp3 | ~$30/mo |
| **Jenkins** | Latest stable, Docker, Docker Compose | Included |
| **S3 (State)** | Encrypted, versioned, logged | <$1/mo |
| **S3 (Artifact)** | Encrypted, versioned, lifecycle mgmt | ~$2/mo |
| **IAM** | Role + Instance Profile | Free |
| **Key Pair** | 4096-bit RSA SSH key | Free |
| **Security Group** | Ports 22, 443, 8080 | Free |
| **Monitoring** | CloudWatch detailed metrics | <$1/mo |
| **Total** | | **~$35-40/mo** |

## Features

✅ **Remote State Management** - S3 + DynamoDB, no local state files  
✅ **Jenkins Pre-configured** - Automated installation via EC2 user data  
✅ **Docker Ready** - Docker + Docker Compose pre-installed for containerized pipelines  
✅ **Zero-Downtime Updates** - EC2 lifecycle rules for graceful rebuilds  
✅ **User Data Flexibility** - Script changes won't trigger instance rebuild  
✅ **AWS Integration** - IAM role for direct S3 access  
✅ **Encrypted Storage** - EBS volumes, S3 buckets, state files  
✅ **Multi-AZ Ready** - Subnets across 2 availability zones  
✅ **Development Optimized** - No NAT Gateway overhead for public Jenkins  
✅ **Production Safe** - Security groups, IAM roles, encrypted volumes  
✅ **CloudWatch Monitoring** - Detailed EC2 metrics enabled  

## Terraform Modules

| Module | Purpose | Resources |
|--------|---------|-----------|
| **vpc** | Networking infrastructure | VPC, subnets, IGW, route tables |
| **security_groups** | Network security | Jenkins security group (8080, 22, 443) |
| **ec2** | Compute instance | EC2, IAM role, user data, monitoring |
| **s3** | Artifact storage | S3 bucket, encryption, versioning, lifecycle |
| **key_pair** | SSH access | RSA key pair, local PEM file |

## Configuration

Default variables (in `terraform.tfvars`):

```hcl
# AWS Configuration
aws_region    = "eu-west-2"        # Change to your region
environment   = "dev"              # dev, staging, prod
project_name  = "jenkins-cicd"     # Used for resource naming

# Instance Configuration
instance_type = "t3.medium"        # t3.small (dev), t3.large (heavy)

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

# Features
enable_public_ip = true            # Jenkins needs public IP

# S3 Bucket (state management)
# Auto-generated unless specified

# Tags
tags = {
  Environment = "dev"
  Project     = "jenkins-cicd"
  ManagedBy   = "Terraform"
}
```

**📖 See [CLAUDE.md](CLAUDE.md) for development guidelines and [TERRAFORM.md](TERRAFORM.md) for complete reference**

## Project Structure

```
jenkins-cicd-server/
├── backend.tf                    # Remote S3 backend (ACTIVE)
├── main.tf                       # Root module orchestration
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
├── versions.tf                   # Provider versions
├── terraform.tfvars.example      # Configuration template
│
├── Documentation
├── README.md                     # This file
├── REMOTE_STATE_SETUP.md         # Remote state guide
├── BACKEND_SETUP.md              # Backend configuration
├── TERRAFORM.md                  # Terraform reference
├── CLAUDE.md                     # Development guide
│
├── scripts/
│   ├── create-terraform-state-bucket.sh    # Setup remote state
│   └── destroy-terraform-state-bucket.sh   # Cleanup remote state
│
└── modules/
    ├── vpc/                   # VPC + subnets + routing
    ├── ec2/                   # Jenkins instance
    ├── security_groups/       # Network security
    ├── s3/                    # Artifact storage
    └── key_pair/              # SSH key pair
```

## Usage

### Initial Setup
```bash
# 1. Create remote state backend
./scripts/create-terraform-state-bucket.sh --region eu-west-2

# 2. Initialize Terraform
terraform init

# 3. Review what will be created
terraform plan -out=tfplan

# 4. Deploy
terraform apply tfplan
```

### Daily Operations
```bash
# View all resources and outputs
terraform state list
terraform output

# View specific output (e.g., Jenkins URL)
terraform output jenkins_url

# Update infrastructure (e.g., scale instance type)
# Edit terraform.tfvars
terraform plan -out=tfplan
terraform apply tfplan

# SSH to instance
ssh -i jenkins-server-key.pem ec2-user@<PUBLIC_IP>
```

### Cleanup
```bash
# Destroy all AWS resources (keeps state in S3)
terraform destroy

# Remove remote state backend (optional)
./scripts/destroy-terraform-state-bucket.sh --force
```

### Updating Jenkins
```bash
# User data changes WON'T trigger instance rebuild
# (due to lifecycle ignore_changes rule)

# Edit modules/ec2/user_data.sh
nano modules/ec2/user_data.sh

# Restart Jenkins to apply changes
ssh -i jenkins-server-key.pem ec2-user@<IP>
sudo systemctl restart jenkins
```

## Security Best Practices

### Network Security
- ✅ VPC with isolated public/private subnets
- ✅ Security groups restrict access (port 8080 HTTP, 22 SSH, 443 HTTPS)
- ✅ Internet Gateway for public subnet access (no NAT for dev cost savings)
- ✅ Jenkins in public subnet with Elastic IP
- ✅ Private subnets ready for future databases

### Data Security
- ✅ S3 buckets block all public access
- ✅ AES256 encryption for EBS volumes and S3 objects
- ✅ S3 versioning with 90-day retention
- ✅ Access logging enabled for compliance

### Access Control
- ✅ IAM role with least privilege (S3 only)
- ✅ SSH key pair (4096-bit RSA)
- ✅ Private key saved locally with 0600 permissions
- ✅ No hardcoded credentials in code
- ✅ DynamoDB state locking prevents concurrent writes

### State Management
- ✅ Remote state in encrypted S3 bucket
- ✅ State file versioning (90-day history)
- ✅ State locking via DynamoDB
- ✅ Never committed to git (gitignored)
- ✅ Access logging for audit trail

## Cost Optimization

### Monthly Cost Breakdown (eu-west-2)

| Component | Usage | Cost |
|-----------|-------|------|
| EC2 (t3.medium) | 730 hours | $30 |
| S3 (state bucket) | <100MB | $0.50 |
| S3 (artifact bucket) | 50GB | $1.25 |
| DynamoDB (state locks) | Minimal | <$0.10 |
| Data transfer | Minimal | <$0.10 |
| **Total** | | **~$32/month** ✅ |

### Optimizations Applied
- ✅ **No NAT Gateway** - Jenkins in public subnet (saves $45/mo)
- ✅ **Lifecycle policies** - Old S3 versions auto-deleted (saves storage)
- ✅ **gp3 volumes** - Better price/performance than gp2
- ✅ **Development-focused** - Private subnets included but not used

### Scaling Up
```hcl
# Scale up instance type
instance_type = "t3.large"    # 2 vCPU, 8GB RAM (~$60/mo)
instance_type = "m5.large"    # For high-traffic (~$65/mo)
```

## Troubleshooting

### Jenkins won't start
```bash
# SSH to instance
ssh -i jenkins-server-key.pem ec2-user@<PUBLIC_IP>

# Check setup progress
sudo cat /var/log/jenkins-setup.log

# View Jenkins logs
sudo tail -f /var/lib/jenkins/logs/jenkins.log

# Start Jenkins manually
sudo systemctl start jenkins
sudo systemctl status jenkins

# If systemd error: fix service file
sudo sed -i '/^\[Unit\]/,/^\[Service\]/{/StartLimit/d;}' /usr/lib/systemd/system/jenkins.service
sudo systemctl daemon-reload
sudo systemctl start jenkins
```

### Can't SSH to instance
```bash
# Verify key permissions
chmod 600 jenkins-server-key.pem
ls -la jenkins-server-key.pem  # Should show: -rw------- 

# Verify security group allows port 22
aws ec2 describe-security-groups --group-ids <SG_ID>

# Verify instance has public IP
terraform output ec2_instance_public_ip
```

### Jenkins not accessible on port 8080
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <SG_ID> | grep 8080

# Check if Jenkins is running
ssh -i jenkins-server-key.pem ec2-user@<IP>
sudo systemctl status jenkins

# Check Jenkins port
sudo netstat -tlnp | grep 8080
```

### State file issues
```bash
# View remote state
terraform state list
terraform state show aws_instance.jenkins

# Pull state locally (inspection only)
terraform state pull > state.backup

# Check S3 bucket
aws s3 ls s3://cicd-state-bucket-<NAME>/jenkins/

# Check DynamoDB locks
aws dynamodb scan --table-name terraform-locks
```

### Instance won't rebuild
```bash
# Lifecycle rules prevent user_data changes from triggering rebuilds
# This is intentional (ignore_changes = [user_data])

# To force rebuild:
terraform taint module.ec2.aws_instance.jenkins
terraform apply

# Or edit instance_type to force recreation:
# instance_type = "t3.large"
terraform apply
```

## Instance Lifecycle

### What Triggers a Rebuild
- ❌ User data script changes (ignored intentionally)
- ✅ Instance type changes
- ✅ Security group changes
- ✅ Subnet changes
- ✅ Key pair changes

### Graceful Updates
- ✅ **create_before_destroy** - New instance created before old one removed
- ✅ **Zero downtime** - Elastic IP can reassign to new instance
- ✅ **User data ignored** - Change script without rebuilding

### Manual Jenkins Updates
```bash
# Edit user_data.sh
nano modules/ec2/user_data.sh

# SSH and restart Jenkins
ssh -i jenkins-server-key.pem ec2-user@<IP>
sudo systemctl restart jenkins

# Changes apply immediately without instance rebuild
```

## Documentation

- **[REMOTE_STATE_SETUP.md](REMOTE_STATE_SETUP.md)** - Remote-first state management guide
- **[BACKEND_SETUP.md](BACKEND_SETUP.md)** - S3 + DynamoDB backend configuration
- **[TERRAFORM.md](TERRAFORM.md)** - Complete Terraform infrastructure reference
- **[CLAUDE.md](CLAUDE.md)** - Development guidelines, conventions, workflows
- **[AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)** - Official docs
- **[Jenkins Documentation](https://jenkins.io/doc/)** - Jenkins server guide

## Deployment Checklist

- [ ] AWS CLI configured and credentials valid
- [ ] Terraform installed (>= 1.0)
- [ ] Region set to your preferred AWS region
- [ ] Run `./scripts/create-terraform-state-bucket.sh`
- [ ] Run `terraform init`
- [ ] Review `terraform plan`
- [ ] Run `terraform apply`
- [ ] Wait 10-15 minutes for infrastructure
- [ ] SSH to instance and check `/var/log/jenkins-setup.log`
- [ ] Access Jenkins at output URL
- [ ] Complete Jenkins setup wizard
- [ ] Configure Jenkins plugins and jobs

## Contributing

Issues and improvements welcome! This is an open-source project for the Jenkins community.

## License

MIT License - see [LICENSE](LICENSE) file for details

---

**Last Updated**: October 28, 2026  
**Terraform Version**: >= 1.0  
**AWS Provider**: ~> 5.0  
**Jenkins Version**: Latest stable
