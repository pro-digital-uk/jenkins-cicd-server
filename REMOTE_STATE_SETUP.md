# Remote State Setup - Remote First

This guide walks you through setting up Terraform remote state **from the start** with NO local state files.

## Overview

**Goal**: Set up infrastructure with Terraform state stored entirely in AWS S3, not locally.

**Architecture**:
```
Your Machine              AWS
     ↓                     ↓
terraform init ────────→ S3 Bucket (state)
terraform plan ────────→ DynamoDB (locking)
terraform apply ────────→ EC2, VPC, S3, etc.
     ↓                     ↓
(no local state)     (all remote state)
```

## Prerequisites

✅ AWS CLI installed: `aws --version`  
✅ AWS credentials configured: `aws sts get-caller-identity`  
✅ Terraform installed: `terraform --version`  
✅ Bash shell available  

## Step-by-Step Setup

### Step 1: Create Remote State Backend (5 minutes)

Run the automated setup script to create S3 bucket and DynamoDB table:

```bash
cd jenkins-cicd-server

./scripts/create-terraform-state-bucket.sh
```

**What the script does:**
- Creates S3 bucket: `jenkins-cicd-terraform-state`
- Enables versioning (90-day retention)
- Enables AES256 encryption
- Blocks public access
- Enables access logging
- Creates DynamoDB table: `terraform-locks`
- Sets lifecycle policies

**Output:**
```
✓ Prerequisites check passed
✓ S3 bucket created: jenkins-cicd-terraform-state
✓ Versioning enabled
✓ Encryption enabled (AES256)
✓ Public access blocked
✓ Access logging enabled
✓ DynamoDB table created: terraform-locks
✓ Lifecycle policy set

Backend Configuration for backend.tf:
terraform {
  backend "s3" {
    bucket         = "jenkins-cicd-terraform-state"
    key            = "jenkins/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Custom Configuration:**

```bash
# Different region
./scripts/create-terraform-state-bucket.sh --region eu-west-1

# Different bucket name
./scripts/create-terraform-state-bucket.sh --bucket-name my-tf-state

# Different AWS profile
./scripts/create-terraform-state-bucket.sh --profile production

# All custom
./scripts/create-terraform-state-bucket.sh \
  --bucket-name my-company-tf-state \
  --region eu-west-1 \
  --table-name prod-locks \
  --profile production
```

### Step 2: Verify Backend Bucket Created

```bash
# Check S3 bucket exists
aws s3 ls | grep jenkins-cicd-terraform-state

# Check bucket configuration
aws s3api get-bucket-versioning \
  --bucket jenkins-cicd-terraform-state

# Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-locks
```

**Expected Output:**
```
$ aws s3 ls | grep jenkins-cicd-terraform-state
2024-10-28 12:34:56 jenkins-cicd-terraform-state

$ aws dynamodb describe-table --table-name terraform-locks
{
    "Table": {
        "TableStatus": "ACTIVE",
        "ItemCount": 0
    }
}
```

### Step 3: Configure backend.tf (Already Done ✓)

The `backend.tf` file is **already configured** and active:

```hcl
terraform {
  backend "s3" {
    bucket         = "jenkins-cicd-terraform-state"
    key            = "jenkins/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**If using custom values**, update the values above:

```bash
# Example: if you used different bucket/table names
sed -i '' 's/jenkins-cicd-terraform-state/my-tf-state/g' backend.tf
sed -i '' 's/terraform-locks/prod-locks/g' backend.tf
```

### Step 4: Initialize Terraform with Remote Backend

Now initialize Terraform - it will connect to remote state immediately:

```bash
terraform init
```

**What happens:**
1. Terraform reads `backend.tf`
2. Connects to S3 and DynamoDB
3. Creates remote state file in S3
4. Acquires lock in DynamoDB
5. Releases lock
6. Ready for planning/applying

**Expected Output:**
```
Initializing the backend...
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- terraform.io/hashicorp/aws: version ~> 5.0
- terraform.io/hashicorp/tls: version ~> 4.0
- terraform.io/hashicorp/local: version ~> 2.0

Terraform has been successfully initialized!
```

### Step 5: Verify Remote State Connection

Confirm Terraform is using remote state:

```bash
# Check Terraform is using S3 backend
terraform version

# List resources (from remote state)
terraform state list

# Show outputs
terraform output
```

### Step 6: Configure Variables

Create your `terraform.tfvars` file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region    = "us-east-1"
environment   = "dev"
project_name  = "jenkins-cicd"
instance_type = "t3.medium"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

enable_public_ip = true

tags = {
  Environment = "dev"
  Project     = "jenkins-cicd"
  ManagedBy   = "Terraform"
}
```

### Step 7: Plan Infrastructure Deployment

Preview the changes:

```bash
terraform plan -out=tfplan
```

**What happens:**
1. Terraform acquires lock in DynamoDB
2. Reads remote state from S3
3. Plans infrastructure changes
4. Releases lock
5. Saves plan to `tfplan` file

**Expected Output:**
```
Terraform will perform the following actions:

  # module.vpc.aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + cidr_block           = "10.0.0.0/16"
      + enable_dns_hostnames = true
      ...
    }

  # module.ec2.aws_instance.jenkins will be created
  + resource "aws_instance" "jenkins" {
      + ami           = "ami-0c55b159cbfafe1f0"
      + instance_type = "t3.medium"
      ...
    }

Plan: 25 to add, 0 to change, 0 to destroy.
```

### Step 8: Apply Infrastructure

Deploy the infrastructure:

```bash
terraform apply tfplan
```

**What happens:**
1. Terraform acquires lock in DynamoDB
2. Creates all AWS resources
3. Updates remote state file in S3
4. Releases lock

**Expected Output:**
```
module.vpc.aws_vpc.main: Creating...
module.vpc.aws_vpc.main: Creation complete after 2s

module.vpc.aws_internet_gateway.main: Creating...
module.vpc.aws_internet_gateway.main: Creation complete after 1s

...

Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:

vpc_id = "vpc-1234567890abcdef0"
ec2_instance_id = "i-0987654321abcdef0"
ec2_instance_public_ip = "54.123.45.67"
jenkins_url = "http://54.123.45.67:8080"
key_pair_name = "jenkins-server-key"
s3_bucket_name = "jenkins-cicd-dev-123456789012"
```

### Step 9: Verify State is Remote

Check that state is only in S3, not locally:

```bash
# NO local state files should exist
ls -la terraform.tfstate* 2>/dev/null || echo "✓ No local state files"

# Verify state is in S3
aws s3 ls s3://jenkins-cicd-terraform-state/jenkins/

# Expected output:
# 2024-10-28 12:45:23       5432 terraform.tfstate
```

### Step 10: Access Jenkins

Get the Jenkins URL and access your server:

```bash
# Show all outputs
terraform output

# Get Jenkins URL specifically
terraform output jenkins_url

# Get EC2 instance IP
terraform output ec2_instance_public_ip

# Get private key location
terraform output -json | jq .key_pair_name
```

**SSH into the instance:**

```bash
# Get public IP
PUBLIC_IP=$(terraform output -raw ec2_instance_public_ip)

# SSH (wait ~5 minutes for user data to complete)
ssh -i jenkins-server-key.pem ec2-user@$PUBLIC_IP

# Check Jenkins setup progress
sudo cat /var/log/jenkins-setup.log

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Access Jenkins in browser:**

```
http://<PUBLIC_IP>:8080
```

## File Structure After Setup

```
jenkins-cicd-server/
├── .git/
├── .gitignore                           # Excludes *.tfstate (no local files)
├── backend.tf                           # ACTIVE - remote state enabled
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars                     # Your custom configuration
├── terraform.tfvars.example             # Template
├── .terraform/                          # Module cache (gitignored)
├── .terraform.lock.hcl                  # Lock file (optional to commit)
├── jenkins-server-key.pem               # SSH key (gitignored)
├── jenkins-server-key.pub               # Public key (gitignored)
├── CLAUDE.md
├── TERRAFORM.md
├── BACKEND_SETUP.md
├── REMOTE_STATE_SETUP.md                # This file
├── README.md
├── LICENSE
├── scripts/
│   ├── create-terraform-state-bucket.sh
│   └── destroy-terraform-state-bucket.sh
└── modules/
    ├── vpc/
    ├── ec2/
    ├── security_groups/
    ├── s3/
    └── key_pair/

AWS S3 (Remote State)
├── jenkins-cicd-terraform-state/        # State bucket
│   ├── jenkins/terraform.tfstate        # Current state
│   ├── jenkins/terraform.tfstate.vXXX   # Versions
│   └── logs/                            # Access logs
```

## Daily Workflow

Once set up, your workflow is straightforward:

```bash
# 1. Make changes to Terraform files
vi main.tf

# 2. Initialize (only needed if adding new modules)
terraform init

# 3. Plan changes
terraform plan

# 4. Review plan output

# 5. Apply changes
terraform apply

# 6. That's it! State is automatically in S3
```

**NO local state files are created.**

## Team Collaboration

Multiple team members can now work together:

```
Dev 1                    Dev 2
   ↓                        ↓
terraform plan ──────────────────→ DynamoDB Lock
(waits for lock)               (acquired)

terraform apply ────────────────→ S3 Update
                            (state updated)

                             (lock released)
terraform plan ←───────────────
(acquires lock)
```

## State Management Commands

```bash
# Show all resources from remote state
terraform state list

# Show specific resource
terraform state show aws_instance.jenkins

# Show outputs
terraform output
terraform output jenkins_url

# Pull state locally (for inspection only)
terraform state pull > inspect.tfstate

# Don't do this unless absolutely necessary
# terraform state push ./state.tfstate

# View locks in DynamoDB
aws dynamodb scan --table-name terraform-locks

# Force unlock (emergency only)
terraform force-unlock LOCK_ID
```

## Common Issues

### "Error acquiring the state lock"

**Problem**: Another team member is applying infrastructure

**Solution**: Wait for them to finish

```bash
# Check who has the lock
aws dynamodb scan --table-name terraform-locks

# Force unlock if process crashed (use caution!)
terraform force-unlock <LOCK_ID>
```

### "InvalidClientTokenId" error

**Problem**: AWS credentials expired

**Solution**: Refresh credentials

```bash
# Re-authenticate
aws sso login --profile default

# Or configure credentials
aws configure
```

### "Error reading S3 Bucket"

**Problem**: S3 bucket doesn't exist

**Solution**: Run setup script again

```bash
./scripts/create-terraform-state-bucket.sh
```

### "DynamoDB table doesn't exist"

**Problem**: Setup script didn't complete

**Solution**: Recreate the backend

```bash
# Destroy old backend
./scripts/destroy-terraform-state-bucket.sh

# Create new backend
./scripts/create-terraform-state-bucket.sh
```

## Backup and Restore

### Automatic Backups

S3 versioning creates automatic backups:

```bash
# List all state versions
aws s3api list-object-versions \
  --bucket jenkins-cicd-terraform-state \
  --prefix jenkins/terraform.tfstate
```

### Manual Backup

```bash
# Backup state file
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# Backup to S3
aws s3 cp backup-*.tfstate \
  s3://jenkins-cicd-terraform-state/backups/
```

### Restore from Backup

```bash
# List available versions
aws s3api list-object-versions \
  --bucket jenkins-cicd-terraform-state

# Restore specific version
aws s3api get-object \
  --bucket jenkins-cicd-terraform-state \
  --key jenkins/terraform.tfstate \
  --version-id versionid123 \
  restored.tfstate

# Push restored state (dangerous!)
terraform state push restored.tfstate
```

## Cleanup

### Destroy Infrastructure

```bash
# Plan destruction
terraform plan -destroy

# Destroy all resources
terraform apply -destroy

# State remains in S3 for recovery
```

### Remove Remote Backend

Only if you want to delete the state bucket:

```bash
./scripts/destroy-terraform-state-bucket.sh
```

## Security Best Practices

✅ **State Encryption**: AES256 enabled (set by setup script)  
✅ **State Versioning**: 90-day history (set by setup script)  
✅ **State Locking**: DynamoDB prevents concurrent writes  
✅ **Access Logging**: All S3 access logged  
✅ **Public Access**: Blocked (set by setup script)  
✅ **IAM Roles**: EC2 has S3 access only  
✅ **No Local Copies**: No .tfstate files on disk  
✅ **Git Safe**: .gitignore prevents accidental commits  

## Quick Reference

```bash
# Create backend
./scripts/create-terraform-state-bucket.sh

# Initialize with remote state
terraform init

# Plan and apply
terraform plan
terraform apply

# Verify state is remote
terraform state list

# Check state in S3
aws s3 ls s3://jenkins-cicd-terraform-state/jenkins/

# Access Jenkins
terraform output jenkins_url

# SSH to instance
ssh -i jenkins-server-key.pem ec2-user@$(terraform output -raw ec2_instance_public_ip)

# Get initial admin password
# (after SSH) sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Next Steps

1. ✅ Run `./scripts/create-terraform-state-bucket.sh`
2. ✅ Run `terraform init`
3. ✅ Run `terraform plan`
4. ✅ Review outputs
5. ✅ Run `terraform apply`
6. ✅ Access Jenkins at the URL in outputs
7. ✅ Configure Jenkins for your CI/CD pipelines

---

**Status**: Remote-first setup complete  
**State Location**: S3 (jenkins-cicd-terraform-state)  
**State Locking**: DynamoDB (terraform-locks)  
**Local Files**: None (all remote)
