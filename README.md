# Jenkins CI/CD Server

Automated Jenkins CI/CD server deployment on AWS using Terraform with VPC, EC2, S3, security groups, and IAM resources.

## Quick Start

⚠️ **Remote State Only** - No local state files. All infrastructure state is stored in AWS S3.

1. **Create Remote State Backend** (5 minutes)
   ```bash
   git clone <repo-url>
   cd jenkins-cicd-server
   ./scripts/create-terraform-state-bucket.sh
   ```

2. **Initialize with Remote State**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed
   terraform init
   ```

3. **Plan and Deploy**
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. **Access Jenkins**
   ```bash
   # Get Jenkins URL
   terraform output jenkins_url
   
   # SSH to instance (wait ~5 min for user data)
   ssh -i jenkins-server-key.pem ec2-user@$(terraform output -raw ec2_instance_public_ip)
   
   # Get initial admin password
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

**See [REMOTE_STATE_SETUP.md](REMOTE_STATE_SETUP.md) for detailed setup instructions**

## Architecture

- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **EC2**: Amazon Linux 2 instance with Jenkins, Docker, Docker Compose
- **S3**: Encrypted bucket with versioning and lifecycle policies
- **Security**: Security groups, IAM roles, encrypted volumes
- **Networking**: NAT Gateways for private subnet outbound access

## Components

| Component | Details |
|-----------|---------|
| VPC | 10.0.0.0/16 with public/private subnets |
| EC2 | t3.medium (configurable) with 50GB encrypted EBS |
| Jenkins | Latest version installed via package manager |
| Docker | Installed for containerized CI/CD pipelines |
| S3 | Encrypted with versioning and lifecycle management |
| IAM | Role with S3 access permissions |
| Key Pair | RSA 4096-bit SSH key pair |

## Features

✅ Fully automated with Terraform modules  
✅ Jenkins installed and pre-configured via user data  
✅ Docker and Docker Compose ready for containerized workloads  
✅ AWS CLI configured for S3 integration  
✅ Encrypted S3 bucket for artifact storage  
✅ Security groups configured for Jenkins access  
✅ IAM role with least privilege S3 access  
✅ CloudWatch monitoring enabled  
✅ Multi-AZ VPC for high availability  

## Terraform Modules

- **vpc**: VPC, subnets, Internet Gateway, NAT Gateways, route tables
- **security_groups**: Jenkins security group with ingress/egress rules
- **ec2**: EC2 instance with IAM role, user data, encrypted EBS
- **s3**: S3 bucket with encryption, versioning, lifecycle policies
- **key_pair**: RSA key pair generation and management

## Configuration

Edit `terraform.tfvars` to customize:

```hcl
aws_region    = "us-east-1"
environment   = "dev"
project_name  = "jenkins-cicd"
instance_type = "t3.medium"
```

See [TERRAFORM.md](TERRAFORM.md) for complete documentation.

## Project Structure

```
.
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Terraform & provider versions
├── terraform.tfvars.example   # Example variables
├── TERRAFORM.md               # Detailed documentation
└── modules/
    ├── vpc/                   # VPC module
    ├── ec2/                   # EC2 module
    ├── security_groups/       # Security groups module
    ├── s3/                    # S3 module
    └── key_pair/              # Key pair module
```

## Usage

### Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### View Outputs
```bash
terraform output
terraform output jenkins_url
```

### Destroy Infrastructure
```bash
terraform destroy
```

## Security Considerations

- VPC with isolated subnets
- Security groups restrict access to necessary ports
- S3 bucket blocks all public access
- Encrypted EBS volumes and S3 objects
- IAM role with least privilege permissions
- Private key saved locally with restricted permissions

## Costs

Estimated monthly costs (AWS US-East-1):
- EC2 (t3.medium): ~$30
- NAT Gateway: ~$45
- S3 (100GB): ~$2.50
- Data transfer: Variable

**Total: ~$80-100/month** (varies by usage)

## Troubleshooting

### Jenkins not starting
```bash
ssh -i jenkins-server-key.pem ec2-user@<IP>
sudo tail -f /var/log/jenkins-setup.log
```

### SSH key issues
```bash
chmod 600 jenkins-server-key.pem
```

### S3 access issues
Verify EC2 IAM role has S3 permissions in AWS console.

## Documentation

- [TERRAFORM.md](TERRAFORM.md) - Complete Terraform documentation
- [AWS Terraform Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Documentation](https://jenkins.io/doc/)

## License

MIT License - see [LICENSE](LICENSE) file
