#!/bin/bash

################################################################################
# Terraform State Bucket Destruction Script
#
# This script removes S3 bucket and DynamoDB table created for Terraform
# remote state management. Use with caution!
#
# Usage:
#   ./scripts/destroy-terraform-state-bucket.sh [options]
#
# Options:
#   -b, --bucket-name       S3 bucket name (default: jenkins-cicd-terraform-state)
#   -t, --table-name        DynamoDB table name (default: terraform-locks)
#   --profile               AWS CLI profile (default: default)
#   -r, --region            AWS region (default: us-east-1)
#   -f, --force             Skip confirmation (dangerous!)
#   -h, --help              Show this help message
#
# Examples:
#   ./scripts/destroy-terraform-state-bucket.sh
#   ./scripts/destroy-terraform-state-bucket.sh --force
#
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
BUCKET_NAME="jenkins-cicd-terraform-state"
TABLE_NAME="terraform-locks"
PROFILE="default"
REGION="us-east-1"
FORCE=false

# Functions
print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_help() {
    head -n 30 "$0" | tail -n +3 | sed 's/^# //'
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bucket-name)
            BUCKET_NAME="$2"
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
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
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

# Confirmation function
confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    local prompt="$1"
    local response

    read -p "$(echo -e ${YELLOW}$prompt${NC})" response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Main function
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Terraform State Bucket Destruction${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_warning "This will delete:"
    echo "  - S3 bucket: $BUCKET_NAME (and all versions)"
    echo "  - Logging bucket: ${BUCKET_NAME}-logs"
    echo "  - DynamoDB table: $TABLE_NAME"
    echo ""

    if ! confirm "Are you sure you want to continue? Type 'yes' to confirm: "; then
        print_info "Destruction cancelled"
        exit 0
    fi

    print_warning "Final confirmation: This is IRREVERSIBLE!"
    if ! confirm "Type 'yes' again to proceed: "; then
        print_info "Destruction cancelled"
        exit 0
    fi

    # Destroy DynamoDB table
    print_info "Destroying DynamoDB table..."
    if aws dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --profile "$PROFILE" \
        --region "$REGION" \
        &>/dev/null; then

        aws dynamodb delete-table \
            --table-name "$TABLE_NAME" \
            --profile "$PROFILE" \
            --region "$REGION"

        print_success "DynamoDB table destroyed"
    else
        print_warning "DynamoDB table does not exist"
    fi

    # Empty and destroy S3 buckets
    for bucket in "$BUCKET_NAME" "${BUCKET_NAME}-logs"; do
        print_info "Destroying S3 bucket: $bucket"

        if ! aws s3 ls "s3://$bucket" --profile "$PROFILE" 2>/dev/null; then
            print_warning "Bucket does not exist: $bucket"
            continue
        fi

        # Empty all versions
        print_info "Removing all objects and versions from: $bucket"
        aws s3api list-object-versions \
            --bucket "$bucket" \
            --profile "$PROFILE" \
            --region "$REGION" \
            --query 'Versions[].[Key,VersionId]' \
            --output text | while read key versionId; do
            if [ -n "$key" ]; then
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$versionId" \
                    --profile "$PROFILE" \
                    --region "$REGION" &>/dev/null || true
            fi
        done

        # Delete delete markers
        aws s3api list-object-versions \
            --bucket "$bucket" \
            --profile "$PROFILE" \
            --region "$REGION" \
            --query 'DeleteMarkers[].[Key,VersionId]' \
            --output text | while read key versionId; do
            if [ -n "$key" ]; then
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$versionId" \
                    --profile "$PROFILE" \
                    --region "$REGION" &>/dev/null || true
            fi
        done

        # Remove bucket
        aws s3 rb "s3://$bucket" \
            --profile "$PROFILE" \
            --region "$REGION"

        print_success "S3 bucket destroyed: $bucket"
    done

    echo ""
    echo -e "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Terraform State Backend Destroyed!${NC}"
    echo -e "${GREEN}═════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Cleanup complete. You can now:"
    echo "  1. Comment out the backend block in backend.tf"
    echo "  2. Run: terraform init"
    echo "  3. Confirm migration back to local state"
    echo ""
}

# Run main
main
