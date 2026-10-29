# Terraform Remote State Configuration
#
# S3 Backend for Remote State Management - ACTIVE
# State is stored in S3 with DynamoDB locking to prevent concurrent modifications
# NO local state files - everything is remote from the start
#
# Setup Instructions:
# 1. Run: ./scripts/create-terraform-state-bucket.sh
# 2. Update bucket name and region below if using custom values
# 3. Run: terraform init (creates remote state immediately, no local state)
#
# IMPORTANT: This backend is ACTIVE - all terraform operations use remote state
# Local terraform.tfstate files will NOT be created

terraform {
  backend "s3" {
    bucket         = "cicd-state-bucket-1793193531" 
    key            = "jenkins/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Backend Configuration Guide:
#
# bucket         - S3 bucket name (must be globally unique)
# key            - Path to state file within bucket (typically: project/terraform.tfstate)
# region         - AWS region where bucket is located
# encrypt        = true  - Enables server-side encryption for state file
# dynamodb_table - DynamoDB table for state locking (prevents concurrent modifications)
#
# To migrate from local to remote state:
# 1. Ensure S3 bucket and DynamoDB table exist
# 2. Uncomment backend block above
# 3. Run: terraform init
# 4. When prompted, confirm migration to remote state
# 5. Local terraform.tfstate files will be backed up
#
# To migrate from remote back to local:
# 1. Comment out the backend block
# 2. Run: terraform init
# 3. Confirm migration back to local state
#
# State File Security:
# - Never commit terraform.tfstate to git
# - S3 bucket has encryption enabled (AES256)
# - Enable versioning on S3 bucket for state history
# - Use DynamoDB for state locking to prevent concurrent writes
# - Restrict S3 bucket access via bucket policy and IAM roles
# - Enable MFA delete protection for production buckets
