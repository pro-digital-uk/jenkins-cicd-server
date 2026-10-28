# Jenkins CI/CD Server - Terraform Infrastructure

This Terraform configuration creates a fully automated Jenkins CI/CD server deployment on AWS with the following components:

## Architecture Overview

```
VPC (10.0.0.0/16)
├── Public Subnets (2)
│   ├── Subnet 1: 10.0.1.0/24
│   └── Subnet 2: 10.0.2.0/24
├── Private Subnets (2)
│   ├── Subnet 1: 10.0.10.0/24
│   └── Subnet 2: 10.0.11.0/24
├── Internet Gateway
├── NAT Gateways (2)
└── Route Tables

EC2 Instance (Jenkins Server)
├── Instance Type: t3.medium (configurable)
├── AMI: Amazon Linux 2
├── Root Volume: 50GB gp3 (encrypted)
├── Public IP: Enabled (configurable)
├── Security Group: Custom rules for Jenkins/SSH/HTTPS
└── IAM Role: S3 access permissions

Security Group
├── Ingress: Port 8080 (Jenkins)
├── Ingress: Port 22 (SSH)
├── Ingress: Port 443 (HTTPS)
└── Egress: All traffic

S3 Bucket
├── Versioning: Enabled
├── Encryption: AES256
├── Public Access: Blocked
└── Lifecycle Policies: Intelligent tiering & old version cleanup

Key Pair
└── Automatically generated RSA 4096-bit key

IAM Resources
├── EC2 Role with S3 access
└── Instance Profile
```

## Modules

### VPC Module (`modules/vpc/`)
- Creates VPC with custom CIDR block
- Creates public and private subnets across 2 AZs
- Sets up Internet Gateway
- Creates NAT Gateways for private subnet internet access
- Configures route tables and associations

**Variables:**
- `vpc_name`: VPC name
- `vpc_cidr`: VPC CIDR block (default: 10.0.0.0/16)
- `public_subnet_cidrs`: List of public subnet CIDRs
- `private_subnet_cidrs`: List of private subnet CIDRs
- `availability_zones`: AZs for subnet placement
- `enable_nat_gateway`: Enable NAT Gateway (default: true)

### Security Groups Module (`modules/security_groups/`)
- Creates security group for Jenkins
- Configures inbound rules for HTTP (8080), SSH (22), HTTPS (443)
- Allows all outbound traffic

**Variables:**
- `vpc_id`: VPC ID
- `project_name`: Project name for naming
- `jenkins_port`: Jenkins port (default: 8080)

### Key Pair Module (`modules/key_pair/`)
- Generates RSA 4096-bit key pair
- Creates AWS key pair
- Saves private key locally with 0600 permissions

**Variables:**
- `key_name`: Name of the key pair

### S3 Module (`modules/s3/`)
- Creates S3 bucket
- Enables versioning
- Enables AES256 encryption
- Blocks all public access
- Sets up lifecycle policies:
  - Deletes old versions after 30 days
  - Transitions to intelligent tiering after 90 days

**Variables:**
- `bucket_name`: Unique bucket name

### EC2 Module (`modules/ec2/`)
- Launches Amazon Linux 2 EC2 instance
- Installs Jenkins via package manager
- Installs Docker and Docker Compose
- Installs AWS CLI and Java 17
- Configures IAM role with S3 access
- Runs user data script for automated setup
- Enables detailed CloudWatch monitoring
- Encrypts root volume (50GB gp3)

**Variables:**
- `instance_name`: Instance name
- `instance_type`: EC2 instance type (default: t3.medium)
- `subnet_id`: Subnet for instance
- `vpc_security_group_ids`: Security groups
- `key_name`: SSH key pair name
- `s3_bucket_name`: S3 bucket name for IAM policy
- `associate_public_ip`: Enable public IP (default: true)

## Installation & Usage

### Prerequisites
- AWS CLI configured with credentials
- Terraform >= 1.0
- AWS account with appropriate permissions

### Step 1: Prepare Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your desired configuration
```

### Step 2: Initialize Terraform
```bash
terraform init
```

### Step 3: Review Plan
```bash
terraform plan
```

### Step 4: Apply Configuration
```bash
terraform apply
```

### Step 5: Access Jenkins
After applying, Terraform will output:
- Jenkins URL: `http://<EC2_PUBLIC_IP>:8080`
- Private key location: `./jenkins-server-key.pem`
- EC2 instance ID
- S3 bucket name

### Step 6: Get Initial Admin Password
```bash
# SSH into the instance
ssh -i jenkins-server-key.pem ec2-user@<PUBLIC_IP>

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Configuration Variables

Edit `terraform.tfvars` to customize:

```hcl
aws_region     = "us-east-1"          # AWS region
environment    = "dev"                # Environment name
project_name   = "jenkins-cicd"       # Project identifier
instance_type  = "t3.medium"          # EC2 instance type
key_pair_name  = "jenkins-server-key" # SSH key pair name

vpc_cidr             = "10.0.0.0/16"       # VPC CIDR
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

enable_public_ip = true # Set to false for private instance
```

## Outputs

After successful deployment, Terraform outputs:
- `vpc_id`: VPC identifier
- `public_subnet_ids`: Public subnet IDs
- `private_subnet_ids`: Private subnet IDs
- `jenkins_security_group_id`: Security group ID
- `key_pair_name`: Key pair name
- `s3_bucket_name`: S3 bucket name
- `ec2_instance_id`: EC2 instance ID
- `ec2_instance_public_ip`: Public IP address
- `ec2_instance_private_ip`: Private IP address
- `jenkins_url`: Jenkins access URL
- `ec2_iam_role_arn`: IAM role ARN

## Jenkins User Data Script

The EC2 module includes a comprehensive user data script (`modules/ec2/user_data.sh`) that:

1. Updates system packages
2. Installs Java 17 (Corretto)
3. Installs Jenkins from official repository
4. Configures Jenkins port (8080)
5. Installs Docker and Docker Compose
6. Installs AWS CLI
7. Configures AWS credentials for Jenkins
8. Starts Jenkins service
9. Logs all output to `/var/log/jenkins-setup.log`

## Security Considerations

### Network Security
- VPC with private subnets for additional isolation
- NAT Gateway for outbound traffic from private subnets
- Security groups restrict access to necessary ports only
- S3 bucket blocks all public access

### Data Security
- S3 encryption enabled (AES256)
- EBS root volume encrypted
- IAM role follows least privilege principle
- Private key managed with 0600 permissions

### Access Control
- SSH access can be restricted to specific IPs by modifying security group
- Jenkins runs with limited privileges
- EC2 instance only has S3 access via IAM role

## Cost Optimization

- `t3.medium` instance is cost-effective for small-medium CI/CD workloads
- Gp3 volumes provide better price-to-performance vs gp2
- S3 lifecycle rules transition old objects to cheaper storage
- NAT Gateway is the main recurring cost; can be removed if public subnets only

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

⚠️ **Warning**: This will delete:
- EC2 instance
- VPC and subnets
- S3 bucket (unless it contains objects)
- Key pair
- All associated resources

## Troubleshooting

### Jenkins not accessible
1. Check security group allows port 8080
2. Verify EC2 instance is running and has public IP
3. Check instance logs: `ssh -i jenkins-server-key.pem ec2-user@<IP> sudo tail -f /var/log/jenkins-setup.log`

### SSH connection fails
1. Verify key pair file has correct permissions: `chmod 600 jenkins-server-key.pem`
2. Check security group allows port 22
3. Verify EC2 instance has public IP

### S3 access fails
1. Verify IAM role is attached to instance
2. Check S3 bucket policy allows EC2 role
3. Review CloudTrail logs for permission errors

## Advanced Configuration

### Using Remote State
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "jenkins/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Multi-Environment Setup
Create separate directories:
```
├── dev/
│   ├── terraform.tfvars
│   └── *.tf
├── staging/
│   ├── terraform.tfvars
│   └── *.tf
└── prod/
    ├── terraform.tfvars
    └── *.tf
```

### Adding CloudWatch Alarms
Extend the EC2 module to include:
- CPU utilization alarm
- Memory utilization alarm
- Disk space alarm
- Jenkins process monitoring

## Related Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Documentation](https://jenkins.io/doc/)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_best_practices.html)
