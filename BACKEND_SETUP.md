# Terraform Remote State Backend Setup

This guide explains how to set up and manage Terraform remote state in S3 for the Jenkins CI/CD infrastructure.

## Overview

Remote state management allows teams to:
- **Share infrastructure state** across team members
- **Prevent concurrent modifications** with state locking
- **Maintain state history** with versioning
- **Secure sensitive data** with encryption
- **Enable CI/CD automation** without local state files

## Why Remote State?

| Feature | Local State | Remote State |
|---------|-------------|--------------|
| Team Collaboration | ❌ | ✅ |
| State Locking | ❌ | ✅ |
| State History | ❌ | ✅ |
| Encryption | ❌ | ✅ |
| CI/CD Automation | ❌ | ✅ |
| Sensitive Data Safe | ❌ | ✅ |

## Prerequisites

- AWS CLI installed and configured: `aws --version`
- AWS account with S3 and DynamoDB permissions
- Terraform installed: `terraform --version`
- Bash shell access

## Architecture

### S3 Bucket
```
jenkins-cicd-terraform-state/
├── jenkins/terraform.tfstate          (current state)
├── jenkins/terraform.tfstate.backup   (backup on init)
└── logs/
    └── terraform-state-logs/          (access logs)
```

### DynamoDB Table
```
terraform-locks
├── LockID (partition key)
├── Digest
├── Operation
├── Info
└── Who
```

### Security Features
- ✅ AES256 encryption for state file
- ✅ Versioning enabled (90-day retention)
- ✅ Public access blocked
- ✅ Access logging enabled
- ✅ DynamoDB for state locking
- ✅ IAM-based access control

## Setup Instructions

### Step 1: Create State Backend

Run the automated setup script:

```bash
cd /path/to/jenkins-cicd-server

# Create S3 bucket and DynamoDB table
./scripts/create-terraform-state-bucket.sh
```

**Options:**
```bash
# Custom bucket name and region
./scripts/create-terraform-state-bucket.sh \
  --bucket-name my-state-bucket \
  --region eu-west-1 \
  --profile production

# With different table name
./scripts/create-terraform-state-bucket.sh \
  --table-name prod-terraform-locks \
  --profile production
```

**Script Output:**
```
✓ Prerequisites check passed
✓ S3 bucket created: jenkins-cicd-terraform-state
✓ Versioning enabled
✓ Encryption enabled (AES256)
✓ Public access blocked
✓ Access logging enabled
✓ DynamoDB table created: terraform-locks
✓ Lifecycle policy set (keep versions for 90 days)

Configuration Summary:
  S3 Bucket:          jenkins-cicd-terraform-state
  DynamoDB Table:     terraform-locks
  AWS Region:         us-east-1
  AWS Profile:        default

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

### Step 2: Update backend.tf

Edit `backend.tf` and uncomment the backend block:

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

### Step 3: Migrate to Remote State

Initialize Terraform with remote backend:

```bash
terraform init
```

**Output:**
```
Initializing the backend...

Do you want to copy existing state to the new backend? [new backend]

Enter a value: yes

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

Terraform will:
- ✅ Detect existing local state
- ✅ Ask to migrate to remote
- ✅ Backup local state to `terraform.tfstate.backup`
- ✅ Upload state to S3
- ✅ Lock state in DynamoDB

### Step 4: Verify Remote State

Check that state is now in S3:

```bash
# List objects in state bucket
aws s3 ls s3://jenkins-cicd-terraform-state/ --recursive

# View state file metadata
aws s3api head-object \
  --bucket jenkins-cicd-terraform-state \
  --key jenkins/terraform.tfstate

# Check DynamoDB table
aws dynamodb describe-table \
  --table-name terraform-locks \
  --query 'Table.[TableStatus,ItemCount]'
```

## Usage

### Normal Terraform Operations

Once backend is configured, Terraform operations work normally:

```bash
# Plan changes (state locked during plan)
terraform plan

# Apply changes (state locked, then updated)
terraform apply

# View state remotely
terraform state list
terraform state show module.vpc
```

### State Locking Behavior

During `terraform apply`:
1. DynamoDB lock acquired
2. Terraform executes changes
3. State updated in S3
4. DynamoDB lock released

**Automatic Locking**: Prevents concurrent modifications

```
User A runs: terraform apply
├── Acquires lock in DynamoDB
├── Makes infrastructure changes
├── Uploads new state to S3
└── Releases lock

User B runs: terraform apply (while User A is applying)
├── Waits for lock to be released
├── Proceeds after User A completes
└── Applies their changes
```

## Disaster Recovery

### Backup State File

```bash
# Manual backup
aws s3 cp \
  s3://jenkins-cicd-terraform-state/jenkins/terraform.tfstate \
  ./terraform.tfstate.backup

# Restore from backup
aws s3 cp \
  ./terraform.tfstate.backup \
  s3://jenkins-cicd-terraform-state/jenkins/terraform.tfstate
```

### View State History

S3 versioning keeps all previous versions:

```bash
# List all versions
aws s3api list-object-versions \
  --bucket jenkins-cicd-terraform-state \
  --prefix jenkins/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket jenkins-cicd-terraform-state \
  --key jenkins/terraform.tfstate \
  --version-id versionid123 \
  terraform.tfstate.v123
```

### Unlock State (Emergency)

If state is stuck locked (process crashed):

```bash
# Find lock ID
aws dynamodb scan --table-name terraform-locks

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID

# Or delete from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"LOCK_ID"}}'
```

## Access Control

### IAM Policy for Developers

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::jenkins-cicd-terraform-state",
        "arn:aws:s3:::jenkins-cicd-terraform-state/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/terraform-locks"
    }
  ]
}
```

### S3 Bucket Policy

The setup script enables versioning and logging. Additional bucket policy for team access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:role/DevOpsRole"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::jenkins-cicd-terraform-state",
        "arn:aws:s3:::jenkins-cicd-terraform-state/*"
      ]
    }
  ]
}
```

## Multi-Environment Setup

Use separate state files for different environments:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "jenkins-cicd-terraform-state"
    key            = "${ENV}/terraform.tfstate"  # Key by environment
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

Directory structure:
```
terraform/
├── dev/
│   ├── terraform.tfvars
│   ├── backend.tf          # key = "dev/terraform.tfstate"
│   └── *.tf
├── staging/
│   ├── terraform.tfvars
│   ├── backend.tf          # key = "staging/terraform.tfstate"
│   └── *.tf
└── prod/
    ├── terraform.tfvars
    ├── backend.tf          # key = "prod/terraform.tfstate"
    └── *.tf
```

## Migration: Local to Remote

Already have local state? Migrate to remote:

### Step 1: Create Backend

```bash
./scripts/create-terraform-state-bucket.sh
```

### Step 2: Update backend.tf

Uncomment the backend block.

### Step 3: Initialize

```bash
terraform init
# Answer "yes" to migrate state
```

### Step 4: Verify

```bash
# Local state should now be backed up
ls -la terraform.tfstate*

# Verify remote state is in S3
aws s3 ls s3://jenkins-cicd-terraform-state/jenkins/
```

## Migration: Remote to Local

Want to switch back to local state?

### Step 1: Disable Backend

Comment out backend block in `backend.tf`:

```hcl
terraform {
  # backend "s3" {
  #   bucket         = "..."
  # }
}
```

### Step 2: Initialize

```bash
terraform init
# Answer "yes" to migrate state back to local
```

### Step 3: Keep or Destroy Backend

Keep S3 bucket for archival:
```bash
# State remains in S3, new deploys use local state
```

Or destroy backend:
```bash
./scripts/destroy-terraform-state-bucket.sh
```

## Troubleshooting

### "Error acquiring the state lock"

**Problem**: Another user is applying infrastructure

**Solution**: Wait for them to finish, or unlock if process crashed:
```bash
terraform force-unlock LOCK_ID
```

### "InvalidClientTokenId" error

**Problem**: AWS credentials expired or invalid

**Solution**: Refresh credentials
```bash
aws sso login --profile my-profile
```

### "Error: error reading S3 Bucket"

**Problem**: S3 bucket doesn't exist or wrong name

**Solution**: Check bucket exists
```bash
aws s3 ls | grep jenkins-cicd-terraform-state

# Recreate if needed
./scripts/create-terraform-state-bucket.sh
```

### "resource does not exist" after init

**Problem**: State file corrupted or missing

**Solution**: Restore from version
```bash
# List versions
aws s3api list-object-versions \
  --bucket jenkins-cicd-terraform-state

# Restore specific version
aws s3api get-object \
  --bucket jenkins-cicd-terraform-state \
  --key jenkins/terraform.tfstate \
  --version-id versionid \
  terraform.tfstate
```

## Cleanup

### Remove Backend (Destroy)

```bash
# Script handles everything
./scripts/destroy-terraform-state-bucket.sh

# Or manual cleanup
aws s3 rb s3://jenkins-cicd-terraform-state --force
aws dynamodb delete-table --table-name terraform-locks
```

### Switch Back to Local

```bash
# Comment out backend block
# Run terraform init
# Confirm migration

terraform init
# Answer "yes" to migrate state
```

## Best Practices

1. **Always use remote state for production**
   - Enables team collaboration
   - Prevents state corruption
   - Maintains audit trail

2. **Enable versioning**
   - Automatic backup of all versions
   - Recover from accidental changes
   - Keep 90+ days of history

3. **Use state locking**
   - Prevents concurrent modifications
   - DynamoDB automatically handles locks
   - Manual unlock only in emergencies

4. **Encrypt sensitive data**
   - S3 encryption for state at rest
   - DynamoDB encryption for locks
   - HTTPS/TLS for transport

5. **Restrict access**
   - Use IAM roles and policies
   - Grant least privilege access
   - Enable access logging

6. **Monitor and audit**
   - Enable CloudTrail for API calls
   - Monitor S3 access logs
   - Set up alerts for state changes

7. **Backup regularly**
   - Automated via S3 versioning
   - Manual backups for critical changes
   - Test restore procedures

## Useful Commands

```bash
# Check backend status
terraform version

# Show state resources
terraform state list

# Show specific resource
terraform state show aws_instance.jenkins

# Backup state
terraform state pull > terraform.tfstate.backup

# Restore state (dangerous!)
terraform state push terraform.tfstate.backup

# Validate backend
aws s3 ls s3://jenkins-cicd-terraform-state/
aws dynamodb describe-table --table-name terraform-locks

# Remove resource from state (dangerous!)
terraform state rm aws_instance.jenkins
```

## References

- [Terraform S3 Backend Documentation](https://www.terraform.io/language/settings/backends/s3)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/BestPractices.html)
- [AWS DynamoDB for State Locking](https://www.terraform.io/language/state/locking)

---

**Last Updated**: October 28, 2026  
**Terraform Version**: >= 1.0  
**AWS CLI**: >= 2.0
