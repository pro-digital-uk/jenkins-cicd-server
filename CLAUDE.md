# CLAUDE.md - Project Configuration

This file contains project-specific configuration and guidelines for Claude Code to assist with this Jenkins CI/CD infrastructure project.

## Project Overview

**Name**: Jenkins CI/CD Server  
**Description**: Automated Jenkins CI/CD server deployment on AWS using Terraform  
**Purpose**: Infrastructure as Code for enterprise-grade Jenkins automation  
**Repository**: cloud-skills-uk/jenkins-cicd-server

## Technology Stack

- **Infrastructure**: Terraform >= 1.0
- **Cloud Provider**: AWS
- **Base Image**: Amazon Linux 2
- **Jenkins**: Latest stable version
- **Container Runtime**: Docker + Docker Compose
- **Language**: HCL (Terraform)

## Project Structure

```
.
├── main.tf                    # Root module - orchestrates all modules
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── versions.tf                # Provider versions
├── terraform.tfvars.example   # Example configuration
├── .gitignore                 # Git exclusions
├── README.md                  # Quick start guide
├── TERRAFORM.md               # Detailed documentation
├── CLAUDE.md                  # This file
├── LICENSE                    # MIT License
└── modules/
    ├── vpc/                   # VPC module with subnets, IGW, NAT
    ├── security_groups/       # Security groups for Jenkins
    ├── ec2/                   # EC2 instance with user data
    ├── s3/                    # S3 bucket with encryption & versioning
    └── key_pair/              # SSH key pair generation
```

## Development Guidelines

### Terraform Code Standards

1. **Module Structure**: Each module must have:
   - `main.tf` - Resource definitions
   - `variables.tf` - Input variable declarations
   - `outputs.tf` - Output value declarations

2. **Naming Conventions**:
   - Resources: `aws_resource_type` (snake_case)
   - Variables: `descriptive_name` (snake_case)
   - Outputs: `descriptive_name` (snake_case)
   - Tags: Always include `Name` tag and common tags

3. **Variable Declaration**:
   - Always include `description`
   - Always include `type`
   - Set `default` when appropriate
   - Use `validation` blocks for strict requirements

4. **Resource Dependencies**:
   - Use `depends_on` explicitly when dependencies aren't implicit
   - Comment why dependency is needed if non-obvious

5. **Comments**:
   - Only add comments for WHY, not WHAT (code is self-documenting)
   - Explain hidden constraints or non-obvious decisions
   - Reference AWS service limits or quirks

### Code Style

- **Indentation**: 2 spaces
- **Line Length**: Keep under 100 characters when reasonable
- **Blank Lines**: Use to separate logical sections
- **Variables**: Alphabetical order in main.tf
- **Tags**: Use `merge()` function with common_tags local

### Testing & Validation

Before committing:
```bash
# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Plan and review
terraform plan -out=tfplan
```

### Git Workflow

1. **Branches**:
   - `main` - Production-ready, stable
   - Feature branches for new infrastructure

2. **Commits**:
   - Keep commits atomic and logical
   - Use clear, descriptive commit messages
   - Reference GitHub issues when applicable

3. **Pull Requests**:
   - Include terraform plan output
   - Document any breaking changes
   - Request review from infrastructure team

4. **Merge Strategy**:
   - Squash commits for cleaner history
   - Delete branch after merge

## Common Tasks

### Deploy Infrastructure

```bash
# Initialize (first time only)
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output
terraform output -json
```

### Customize Configuration

1. Copy example config:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars`:
   ```hcl
   aws_region    = "us-east-1"
   instance_type = "t3.medium"
   project_name  = "jenkins-cicd"
   ```

3. Deploy with custom config:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

### Access Jenkins

```bash
# Get Jenkins URL
terraform output jenkins_url

# SSH into EC2 instance
ssh -i jenkins-server-key.pem ec2-user@<PUBLIC_IP>

# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo tail -f /var/lib/jenkins/logs/jenkins.log

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Troubleshooting

```bash
# Check EC2 user data execution
ssh -i jenkins-server-key.pem ec2-user@<IP>
sudo cat /var/log/jenkins-setup.log

# View Terraform state
terraform state list
terraform state show aws_instance.jenkins

# Debug AWS CLI from EC2
aws s3 ls
aws sts get-caller-identity

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### Destroy Infrastructure

```bash
# Plan destruction
terraform plan -destroy

# Destroy resources (careful!)
terraform destroy

# Or destroy specific resource
terraform destroy -target=module.ec2
```

## Configuration Reference

### AWS Region
- **Variable**: `aws_region`
- **Default**: `us-east-1`
- **Options**: Any valid AWS region

### Instance Type
- **Variable**: `instance_type`
- **Default**: `t3.medium`
- **Recommended**: `t3.medium` (2 vCPU, 4GB RAM)
- **For heavy workloads**: `t3.large` (2 vCPU, 8GB RAM)
- **For high-traffic**: `m5.large` (2 vCPU, 8GB RAM)

### VPC Configuration
- **CIDR**: `10.0.0.0/16` (65,536 IPs)
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24` (256 IPs each)
- **Private Subnets**: `10.0.10.0/24`, `10.0.11.0/24` (256 IPs each)

### Networking
- **Jenkins Port**: 8080 (configurable)
- **SSH Port**: 22
- **HTTPS Port**: 443

## Security Practices

### Requirements
1. ✅ Always use encryption at rest (S3, EBS)
2. ✅ Always use security groups for network isolation
3. ✅ Always use IAM roles (never hardcoded credentials)
4. ✅ Always block public S3 access unless explicitly needed
5. ✅ Always store sensitive data in AWS Secrets Manager or Parameter Store

### SSH Key Management
- Private key saved to `jenkins-server-key.pem` (gitignored)
- Set permissions: `chmod 600 jenkins-server-key.pem`
- Never commit private keys
- Rotate keys periodically

### IAM Roles
- EC2 instance has only S3 access via IAM role
- No hardcoded AWS credentials in user data
- Role follows principle of least privilege

### Network Security
- Security groups restrict access to necessary ports only
- Public access via HTTP/HTTPS only
- SSH from anywhere (restrict in production)
- Private subnets for future database/backend services

## Modules Guide

### VPC Module (`modules/vpc/`)

**Purpose**: Creates networking infrastructure

**Key Resources**:
- VPC with custom CIDR
- Public & private subnets across 2 AZs
- Internet Gateway for public access
- NAT Gateways for private outbound access
- Route tables & associations

**Variables**:
- `vpc_cidr` - VPC CIDR block
- `public_subnet_cidrs` - List of public subnet CIDRs
- `private_subnet_cidrs` - List of private subnet CIDRs
- `enable_nat_gateway` - Enable NAT for private subnets

**Outputs**:
- `vpc_id` - VPC identifier
- `public_subnet_ids` - Public subnet IDs
- `private_subnet_ids` - Private subnet IDs

### Security Groups Module (`modules/security_groups/`)

**Purpose**: Creates and manages security groups

**Key Resources**:
- Jenkins security group
- Ingress rules (8080, 22, 443)
- Egress rule (all traffic)

**Variables**:
- `vpc_id` - VPC for security group
- `jenkins_port` - Jenkins port (default: 8080)

**Outputs**:
- `jenkins_sg_id` - Security group ID

### EC2 Module (`modules/ec2/`)

**Purpose**: Creates EC2 instance with Jenkins

**Key Resources**:
- EC2 instance (Amazon Linux 2)
- IAM role with S3 permissions
- Instance profile
- 50GB encrypted EBS volume

**User Data Script**:
- Installs Java 17
- Installs Jenkins from official repository
- Installs Docker & Docker Compose
- Installs AWS CLI
- Configures Jenkins & starts service

**Variables**:
- `instance_type` - EC2 instance type
- `subnet_id` - Subnet for instance
- `vpc_security_group_ids` - Security groups
- `key_name` - SSH key pair name
- `s3_bucket_name` - For IAM S3 access policy

**Outputs**:
- `instance_id` - EC2 instance ID
- `public_ip` - Public IP address
- `private_ip` - Private IP address
- `iam_role_arn` - IAM role ARN

### S3 Module (`modules/s3/`)

**Purpose**: Creates secure S3 bucket for Jenkins artifacts

**Key Resources**:
- S3 bucket
- Versioning enabled
- AES256 encryption
- Block public access
- Lifecycle rules (delete old versions, intelligent tiering)

**Variables**:
- `bucket_name` - Unique bucket name

**Outputs**:
- `bucket_name` - Bucket name
- `bucket_arn` - Bucket ARN

### Key Pair Module (`modules/key_pair/`)

**Purpose**: Generates SSH key pair

**Key Resources**:
- TLS private key (RSA 4096)
- AWS key pair
- Local private key file (PEM format)

**Variables**:
- `key_name` - Key pair name

**Outputs**:
- `key_pair_name` - Key pair name
- `private_key_path` - Local file path

## Terraform State Management

### Local State (Default)
- State stored in `terraform.tfstate` and `terraform.tfstate.backup`
- `.gitignore` prevents committing state files
- **Warning**: Contains sensitive data, keep secure

### Remote State (Recommended for Teams)
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "jenkins/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Terraform Plan
on: [pull_request]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      - run: terraform validate
      - run: terraform plan
```

## Cost Management

### Estimated Monthly Costs (US-East-1)
- EC2 (t3.medium): ~$30
- NAT Gateway: ~$45
- S3 (100GB): ~$2.50
- **Total**: ~$80-100/month

### Cost Optimization Tips
1. Use spot instances for non-critical environments
2. Stop instance when not in use
3. Remove unused resources
4. Use S3 intelligent tiering
5. Monitor CloudWatch metrics

## Documentation

### Files to Read First
1. [README.md](README.md) - Quick start guide
2. [TERRAFORM.md](TERRAFORM.md) - Detailed documentation
3. [CLAUDE.md](CLAUDE.md) - This file

### External Resources
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Jenkins Official Documentation](https://jenkins.io/doc/)
- [AWS Best Practices](https://docs.aws.amazon.com/whitepapers/)

## Troubleshooting Checklist

### Jenkins not accessible
- [ ] EC2 instance running?
- [ ] Security group allows port 8080?
- [ ] Public IP assigned?
- [ ] User data script completed? Check `/var/log/jenkins-setup.log`

### SSH connection fails
- [ ] Correct private key used?
- [ ] Key has 0600 permissions?
- [ ] Security group allows port 22?
- [ ] Correct username (ec2-user for AL2)?

### Terraform errors
- [ ] AWS credentials configured?
- [ ] Correct AWS region?
- [ ] Sufficient IAM permissions?
- [ ] Variable values valid?

### S3 access fails
- [ ] IAM role attached to EC2?
- [ ] S3 bucket exists?
- [ ] EC2 can reach S3 (NAT Gateway running)?
- [ ] Security group allows outbound 443?

## Environment Variables

### AWS Configuration
```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=default
```

### Terraform Variables
```bash
export TF_LOG=DEBUG              # Enable debug logging
export TF_LOG_PATH=terraform.log # Log file location
export TF_INPUT=false            # Non-interactive mode
```

## Useful Commands

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Show current state
terraform state list
terraform state show module.ec2

# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0

# Get specific output
terraform output ec2_instance_public_ip

# Refresh state
terraform refresh

# Taint resource (force recreation)
terraform taint aws_instance.jenkins

# Target specific resource
terraform apply -target=module.ec2
```

## Git Ignore Patterns

The `.gitignore` file excludes:
- Terraform state files (`*.tfstate*`)
- Terraform lock files (`.terraform/`)
- Private keys (`*.pem`)
- Variable files with secrets (`*.tfvars`)
- AWS credentials files
- IDE files (`.vscode`, `.idea`)
- Temporary files (`*.swp`, `*~`)
- OS files (`.DS_Store`)

## Version Control Strategy

### Commit Frequency
- Commit frequently with logical, atomic changes
- One feature or fix per commit

### Commit Message Format
```
<type>: <subject>

<body>

<footer>
```

**Types**: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

**Examples**:
```
feat: add monitoring to EC2 instance
fix: correct S3 bucket encryption config
docs: update Terraform documentation
```

## Team Collaboration

### Code Review Checklist
- [ ] Terraform validates without errors
- [ ] Variables are properly documented
- [ ] Security best practices followed
- [ ] No hardcoded credentials
- [ ] Tags are consistent
- [ ] Cost implications understood

### Communication
- Use PR comments for discussion
- Update documentation when infrastructure changes
- Document any manual AWS console changes
- Keep team informed of deployments

## Helpful Tips

1. **Always plan before apply**:
   ```bash
   terraform plan -out=tfplan
   # Review output
   terraform apply tfplan
   ```

2. **Use variable files for environments**:
   ```bash
   terraform apply -var-file="prod.tfvars"
   ```

3. **Organize outputs logically**:
   - Access information in outputs
   - Display in readable format

4. **Document all changes**:
   - Update TERRAFORM.md
   - Add comments in code
   - Reference in commit message

5. **Test locally first**:
   - Validate syntax
   - Plan before apply
   - Check security groups
   - Verify outputs

## Contact & Support

For questions or issues:
1. Check TERRAFORM.md documentation
2. Review AWS provider documentation
3. Search existing GitHub issues
4. Create new GitHub issue with details

---

**Last Updated**: October 28, 2026  
**Terraform Version**: >= 1.0  
**AWS Provider Version**: ~> 5.0
