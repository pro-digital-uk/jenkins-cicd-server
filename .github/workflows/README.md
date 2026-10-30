# GitHub Actions Workflows

This directory contains CI/CD workflows for automated Terraform validation, planning, and deployment.

## Workflows

### `terraform.yml` - Terraform CI/CD Pipeline

Automated validation, planning, and deployment of Terraform infrastructure.

**Triggers:**
- ✅ Push to `main` or `develop` branches
- ✅ Pull requests to `main` or `develop` branches
- ✅ Only runs when Terraform files change (`.tf`, `.tfvars`)

**Jobs:**

#### 1. **Validate** (Always runs)
- Runs `terraform fmt -check` (format validation)
- Runs `terraform validate` (syntax validation)
- Fails PR if format issues found

#### 2. **Plan** (Runs after validate)
- Configures AWS credentials (if secrets provided)
- Runs `terraform init`
- Runs `terraform plan`
- Comments on PR with validation status
- **Does NOT apply changes**

#### 3. **Security** (Runs after validate)
- Scans Terraform with Trivy
- Detects security issues in IaC
- Uploads results to GitHub Security tab
- Non-blocking (continues even if issues found)

#### 4. **Apply** (Only on main branch push)
- Only runs when pushing to `main` (not PRs)
- Configures AWS credentials
- Runs `terraform apply`
- Comments on commit with completion status
- **This is where infrastructure is actually deployed**

## Setup

### 1. Create GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions):

#### Option A: AWS Role ARN (Recommended - OIDC)

```bash
# Create AWS role for GitHub Actions
# See: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect

Secret Name: AWS_ROLE_ARN
Secret Value: arn:aws:iam::ACCOUNT_ID:role/GitHubActionsRole
```

#### Option B: AWS Access Keys (Less Secure)

```bash
Secret Name: AWS_ACCESS_KEY_ID
Secret Value: your-access-key

Secret Name: AWS_SECRET_ACCESS_KEY
Secret Value: your-secret-key
```

### 2. Create IAM Role (for OIDC)

```bash
# Create trust policy JSON
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:GITHUB_ORG/GITHUB_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create IAM role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://trust-policy.json

# Attach policy for Terraform
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name TerraformPolicy \
  --policy-document file://terraform-policy.json
```

### 3. Terraform Policy

Create `terraform-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "s3:*",
        "iam:*",
        "vpc:*",
        "dynamodb:*",
        "kms:*",
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Workflow Behavior

### Development Branch (`develop`)

```
Pull Request:
  ✅ Validate
  ✅ Plan
  ✅ Security Scan
  ❌ Apply (skipped)

Merge to develop:
  ✅ Validate
  ✅ Plan
  ✅ Security Scan
  ❌ Apply (skipped)
```

### Main Branch (`main`)

```
Pull Request:
  ✅ Validate
  ✅ Plan
  ✅ Security Scan
  ❌ Apply (skipped on PRs)

Merge to main:
  ✅ Validate
  ✅ Plan
  ✅ Security Scan
  ✅ Apply (infrastructure deployed!)
```

## Monitoring Workflows

### GitHub UI
1. Go to **Actions** tab
2. Click on workflow run to view logs
3. Each job shows detailed step output

### Command Line
```bash
# List recent workflow runs
gh run list

# View specific run
gh run view <RUN_ID>

# Watch live logs
gh run view <RUN_ID> --log
```

## Troubleshooting

### Workflow Fails on `terraform plan`

**Check:**
- AWS credentials valid and have correct permissions
- Terraform files have no syntax errors (`terraform validate` locally)
- S3 backend bucket exists (for remote state)

### Apply only runs on main, not develop

**This is intentional.** Apply-on-push only triggers for `main` branch to prevent accidental deployments from development work.

**To deploy from develop:**
1. Create PR to `main`
2. Review plan
3. Merge to `main`
4. Workflow automatically applies changes

### Security scan found issues

**Review:**
- GitHub Security tab shows detailed findings
- Trivy scan results in workflow logs
- Fix issues in Terraform code
- Re-push to trigger new scan

## Best Practices

✅ **Always use main branch for production**
- Only `main` branch auto-applies changes
- All changes go through PR review first

✅ **Review plan output before merging**
- Understand what `terraform apply` will do
- Check for unexpected resource changes

✅ **Use descriptive commit messages**
- Makes workflow history readable
- Links to GitHub issues help tracking

✅ **Keep secrets secure**
- Never commit `.tfvars` files with secrets
- Use GitHub secrets for sensitive values
- Rotate AWS credentials regularly

✅ **Monitor security scan results**
- Address findings in a timely manner
- Understand why Trivy flags something

## Example: Local Testing Before PR

```bash
# Run locally first
terraform validate
terraform fmt -recursive
terraform plan -out=tfplan

# If successful, push to feature branch
git add .
git commit -m "feat: add new Jenkins feature"
git push origin feature/my-feature

# Create PR and let GitHub Actions validate
# Review plan output in workflow logs
# Merge to main when ready
```

## Disabling Workflows

To temporarily disable a workflow:

```bash
# Rename the file
mv .github/workflows/terraform.yml .github/workflows/terraform.yml.disabled

# Or delete it
rm .github/workflows/terraform.yml
```

## Further Reading

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AWS OIDC Provider](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)
