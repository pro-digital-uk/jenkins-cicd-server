#!/bin/bash

################################################################################
# Terraform State Bucket Creation Script
#
# This script creates S3 bucket and DynamoDB table for Terraform remote state
# management. It should be run before enabling the S3 backend in backend.tf
#
# Usage:
#   ./scripts/create-terraform-state-bucket.sh [options]
#
# Options:
#   -b, --bucket-name       S3 bucket name (default: jenkins-cicd-terraform-state)
#   -r, --region            AWS region (default: us-east-1)
#   -t, --table-name        DynamoDB table name (default: terraform-locks)
#   --profile               AWS CLI profile (default: default)
#   -h, --help              Show this help message
#
# Examples:
#   ./scripts/create-terraform-state-bucket.sh
#   ./scripts/create-terraform-state-bucket.sh -b my-state-bucket -r eu-west-1
#   ./scripts/create-terraform-state-bucket.sh --profile production
#
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUCKET_NAME="jenkins-cicd-terraform-state"
REGION="us-east-1"
TABLE_NAME="terraform-locks"
PROFILE="default"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to show help
show_help() {
    head -n 30 "$0" | tail -n +3 | sed 's/^# //'
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bucket-name)
            BUCKET_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -t|--table-name)
            TABLE_NAME="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install it with: pip install awscli"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity --profile "$PROFILE" &> /dev/null; then
        print_error "AWS credentials not configured for profile: $PROFILE"
        echo "Configure with: aws configure --profile $PROFILE"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Function to create S3 bucket
create_s3_bucket() {
    print_info "Creating S3 bucket for Terraform state..."

    # Check if bucket already exists
    if aws s3 ls "s3://$BUCKET_NAME" --profile "$PROFILE" 2>/dev/null; then
        print_warning "S3 bucket '$BUCKET_NAME' already exists"
        return 0
    fi

    # Create bucket
    if [ "$REGION" = "us-east-1" ]; then
        # US-East-1 requires different syntax (no LocationConstraint)
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --profile "$PROFILE"
    else
        # Other regions require LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION" \
            --profile "$PROFILE"
    fi

    print_success "S3 bucket created: $BUCKET_NAME"
}

# Function to enable S3 bucket versioning
enable_versioning() {
    print_info "Enabling versioning on S3 bucket..."

    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "Versioning enabled"
}

# Function to enable S3 bucket encryption
enable_encryption() {
    print_info "Enabling encryption on S3 bucket..."

    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }' \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "Encryption enabled (AES256)"
}

# Function to block public access
block_public_access() {
    print_info "Blocking public access to S3 bucket..."

    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "Public access blocked"
}

# Function to enable logging
enable_logging() {
    print_info "Enabling access logging on S3 bucket..."

    # Create logging bucket if needed
    local log_bucket="${BUCKET_NAME}-logs"

    if ! aws s3 ls "s3://$log_bucket" --profile "$PROFILE" 2>/dev/null; then
        print_info "Creating logging bucket: $log_bucket"
        if [ "$REGION" = "us-east-1" ]; then
            aws s3api create-bucket \
                --bucket "$log_bucket" \
                --region "$REGION" \
                --profile "$PROFILE"
        else
            aws s3api create-bucket \
                --bucket "$log_bucket" \
                --region "$REGION" \
                --create-bucket-configuration LocationConstraint="$REGION" \
                --profile "$PROFILE"
        fi
    fi

    # Enable logging
    aws s3api put-bucket-logging \
        --bucket "$BUCKET_NAME" \
        --bucket-logging-status '{
            "LoggingEnabled": {
                "TargetBucket": "'$log_bucket'",
                "TargetPrefix": "terraform-state-logs/"
            }
        }' \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "Access logging enabled"
}

# Function to create DynamoDB table for state locking
create_dynamodb_table() {
    print_info "Creating DynamoDB table for state locking..."

    # Check if table already exists
    if aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --profile "$PROFILE" \
        --region "$REGION" \
        &>/dev/null; then
        print_warning "DynamoDB table '$TABLE_NAME' already exists"
        return 0
    fi

    # Create table
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "DynamoDB table created: $TABLE_NAME"

    # Wait for table to be active
    print_info "Waiting for DynamoDB table to be active..."
    aws dynamodb wait table-exists \
        --table-name "$TABLE_NAME" \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "DynamoDB table is active"
}

# Function to set bucket lifecycle policy
set_lifecycle_policy() {
    print_info "Setting lifecycle policy for state file versions..."

    aws s3api put-bucket-lifecycle-configuration \
        --bucket "$BUCKET_NAME" \
        --lifecycle-configuration '{
            "Rules": [{
                "ID": "DeleteOldStateVersions",
                "Status": "Enabled",
                "Filter": {"Prefix": ""},
                "NoncurrentVersionExpiration": {"NoncurrentDays": 90}
            }]
        }' \
        --profile "$PROFILE" \
        --region "$REGION"

    print_success "Lifecycle policy set (keep versions for 90 days)"
}

# Function to display summary
display_summary() {
    echo ""
    echo -e "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Terraform State Backend Setup Complete!${NC}"
    echo -e "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Configuration Summary:"
    echo "  S3 Bucket:          $BUCKET_NAME"
    echo "  DynamoDB Table:     $TABLE_NAME"
    echo "  AWS Region:         $REGION"
    echo "  AWS Profile:        $PROFILE"
    echo ""
    echo "Next Steps:"
    echo "  1. Update backend.tf with your configuration"
    echo "  2. Uncomment the backend block in backend.tf"
    echo "  3. Run: terraform init"
    echo "  4. Confirm migration to remote state when prompted"
    echo ""
    echo "Backend Configuration for backend.tf:"
    echo -e "${YELLOW}terraform {${NC}"
    echo -e "${YELLOW}  backend \"s3\" {${NC}"
    echo -e "${YELLOW}    bucket         = \"$BUCKET_NAME\"${NC}"
    echo -e "${YELLOW}    key            = \"jenkins/terraform.tfstate\"${NC}"
    echo -e "${YELLOW}    region         = \"$REGION\"${NC}"
    echo -e "${YELLOW}    encrypt        = true${NC}"
    echo -e "${YELLOW}    dynamodb_table = \"$TABLE_NAME\"${NC}"
    echo -e "${YELLOW}  }${NC}"
    echo -e "${YELLOW}}${NC}"
    echo ""
    echo "Useful commands:"
    echo "  # View state file"
    echo "  terraform state list"
    echo ""
    echo "  # Unlock state if needed (use with caution)"
    echo "  terraform force-unlock <LOCK_ID>"
    echo ""
    echo "  # Backup state"
    echo "  aws s3 cp s3://$BUCKET_NAME/jenkins/terraform.tfstate ./terraform.tfstate.backup"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Terraform Remote State Backend Setup${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    create_s3_bucket
    enable_versioning
    enable_encryption
    block_public_access
    enable_logging
    create_dynamodb_table
    set_lifecycle_policy

    display_summary
}

# Run main function
main
