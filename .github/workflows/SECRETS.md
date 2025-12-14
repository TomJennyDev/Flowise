# GitHub Secrets Configuration Guide

## Required Secrets for CI/CD Pipeline

### AWS Credentials

| Secret Name             | Description                          | Example                                            | Required                  |
| ----------------------- | ------------------------------------ | -------------------------------------------------- | ------------------------- |
| `AWS_ACCESS_KEY_ID`     | AWS IAM user access key ID           | `AKIAIOSFODNN7EXAMPLE`                             | ✅ Yes                    |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM user secret access key       | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`         | ✅ Yes                    |
| `AWS_ROLE_TO_ASSUME`    | AWS IAM role ARN for OIDC (optional) | `arn:aws:iam::123456789012:role/GitHubActionsRole` | ❌ No (nếu dùng IAM user) |

### GitOps Repository

| Secret Name    | Description                                         | Example                    | Required |
| -------------- | --------------------------------------------------- | -------------------------- | -------- |
| `GITOPS_TOKEN` | GitHub Personal Access Token with repo write access | `ghp_xxxxxxxxxxxxxxxxxxxx` | ✅ Yes   |

**Permissions needed for GITOPS_TOKEN:**

-   ✅ `repo` (Full control of private repositories)
-   ✅ `workflow` (Update GitHub Action workflows)

### ArgoCD Configuration

| Secret Name         | Description                              | Example                                   | Required |
| ------------------- | ---------------------------------------- | ----------------------------------------- | -------- |
| `ARGOCD_SERVER`     | ArgoCD server address (without https://) | `argocd.yourdomain.com`                   | ✅ Yes   |
| `ARGOCD_AUTH_TOKEN` | ArgoCD authentication token              | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` | ✅ Yes   |

### Application Endpoints (Optional)

| Secret Name        | Description                 | Example                                  | Required    |
| ------------------ | --------------------------- | ---------------------------------------- | ----------- |
| `DEV_ENDPOINT`     | Development environment URL | `https://dev-flowise.yourdomain.com`     | ⚠️ Optional |
| `STAGING_ENDPOINT` | Staging environment URL     | `https://staging-flowise.yourdomain.com` | ⚠️ Optional |
| `PROD_ENDPOINT`    | Production environment URL  | `https://flowise.yourdomain.com`         | ⚠️ Optional |

> **Note:** Endpoint secrets are only needed if you want to run health checks after deployment.

---

## Setup Instructions

### 1. AWS Credentials Setup

#### Option A: Using IAM User (Recommended for Getting Started)

```bash
# 1. Create IAM user with ECR permissions
aws iam create-user --user-name github-actions-flowise

# 2. Attach ECR policy
aws iam attach-user-policy \
  --user-name github-actions-flowise \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# 3. Create access key
aws iam create-access-key --user-name github-actions-flowise
```

Save the output:

-   `AccessKeyId` → `AWS_ACCESS_KEY_ID`
-   `SecretAccessKey` → `AWS_SECRET_ACCESS_KEY`

#### Option B: Using OIDC (Advanced, More Secure)

```bash
# 1. Create OIDC provider for GitHub
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create trust policy for GitHub Actions
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:TomJennyDev/Flowise:*"
        }
      }
    }
  ]
}
EOF

# 3. Create IAM role
aws iam create-role \
  --role-name GitHubActionsFlowise \
  --assume-role-policy-document file://trust-policy.json

# 4. Attach ECR policy
aws iam attach-role-policy \
  --role-name GitHubActionsFlowise \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

Set `AWS_ROLE_TO_ASSUME` to the role ARN (e.g., `arn:aws:iam::123456789012:role/GitHubActionsFlowise`)

### 2. GitHub Personal Access Token (PAT)

#### Option A: Classic Token (Simpler)

1. Go to: https://github.com/settings/tokens
2. Click **Generate new token** → **Generate new token (classic)**
3. Set expiration: **No expiration** or **1 year**
4. Select scopes:
    - ✅ `repo` - Full control of private repositories
    - ✅ `workflow` - Update GitHub Action workflows
5. Click **Generate token**
6. Copy token immediately (won't be shown again)
7. Save as `GITOPS_TOKEN`

#### Option B: Fine-grained Token (More Secure, Recommended)

1. Go to: https://github.com/settings/tokens?type=beta
2. Click **Generate new token**
3. Fill in details:
    - **Token name**: `GitOps CI/CD Token`
    - **Expiration**: `90 days` or `1 year`
    - **Resource owner**: `TomJennyDev`
4. **Repository access**:
    - Select **Only select repositories**
    - Choose: `TomJennyDev/devops` (GitOps repository)
5. **Permissions** - Repository permissions:
    - ✅ **Contents**: `Read and write` (để push code)
    - ✅ **Metadata**: `Read-only` (required, auto-selected)
    - ✅ **Workflows**: `Read and write` (nếu GitOps repo có workflows)
6. Click **Generate token**
7. Copy token immediately (format: `github_pat_xxxxx...`)
8. Save as `GITOPS_TOKEN`

**Permissions Summary for Fine-grained Token:**

```
Repository: TomJennyDev/devops
├── Contents: Read and write ✅ (push commits)
├── Metadata: Read-only ✅ (required)
└── Workflows: Read and write ⚠️ (optional, only if updating workflows)
```

### 3. ArgoCD Authentication Token

```bash
# 1. Login to ArgoCD
argocd login argocd.yourdomain.com

# 2. Generate token (valid for 1 year)
argocd account generate-token --account github-actions --expires-in 8760h

# Or for specific user
argocd account generate-token --account admin --expires-in 8760h
```

Save the output as `ARGOCD_AUTH_TOKEN`

**ArgoCD Server Address:**

-   Use hostname only (no `https://`)
-   Example: `argocd.yourdomain.com` ✅
-   Not: `https://argocd.yourdomain.com` ❌

---

## Adding Secrets to GitHub

### Via GitHub UI

1. Go to: `https://github.com/TomJennyDev/Flowise/settings/secrets/actions`
2. Click **New repository secret**
3. Enter name and value
4. Click **Add secret**
5. Repeat for all secrets

### Via GitHub CLI

```bash
# Install GitHub CLI
# https://cli.github.com/

# Login
gh auth login

# Add secrets
gh secret set AWS_ACCESS_KEY_ID -b "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY -b "YOUR_SECRET_KEY"
gh secret set GITOPS_TOKEN -b "ghp_xxxxxxxxxxxx"
gh secret set ARGOCD_SERVER -b "argocd.yourdomain.com"
gh secret set ARGOCD_AUTH_TOKEN -b "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Optional endpoints
gh secret set DEV_ENDPOINT -b "https://dev-flowise.yourdomain.com"
gh secret set STAGING_ENDPOINT -b "https://staging-flowise.yourdomain.com"
gh secret set PROD_ENDPOINT -b "https://flowise.yourdomain.com"
```

---

## Verification Checklist

### ✅ Pre-deployment Checklist

-   [ ] AWS credentials configured and tested

    ```bash
    aws sts get-caller-identity
    ```

-   [ ] ECR repositories created

    ```bash
    aws ecr describe-repositories --region ap-southeast-1
    # Should show: flowise-server and flowise-ui
    ```

-   [ ] GitOps repository exists and is accessible

    ```bash
    git clone https://github.com/TomJennyDev/devops.git
    ```

-   [ ] GitOps repository structure ready

    ```
    devops/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── deployment-server.yaml
    │   ├── deployment-ui.yaml
    │   └── service.yaml
    └── overlays/
        ├── dev/
        │   └── kustomization.yaml
        ├── staging/
        │   └── kustomization.yaml
        └── production/
            └── kustomization.yaml
    ```

-   [ ] ArgoCD applications created

    ```bash
    argocd app list
    # Should show: flowise-dev, flowise-staging, flowise-production
    ```

-   [ ] All GitHub secrets added
    ```bash
    gh secret list
    ```

**Expected output should show:**

```
AWS_ACCESS_KEY_ID        Updated YYYY-MM-DD
AWS_SECRET_ACCESS_KEY    Updated YYYY-MM-DD
GITOPS_TOKEN            Updated YYYY-MM-DD
ARGOCD_SERVER           Updated YYYY-MM-DD
ARGOCD_AUTH_TOKEN       Updated YYYY-MM-DD
DEV_ENDPOINT            Updated YYYY-MM-DD (optional)
STAGING_ENDPOINT        Updated YYYY-MM-DD (optional)
PROD_ENDPOINT           Updated YYYY-MM-DD (optional)
```

**Quick verification script:**

```bash
#!/bin/bash
echo "🔍 Checking required secrets..."
echo ""

REQUIRED_SECRETS=(
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "GITOPS_TOKEN"
  "ARGOCD_SERVER"
  "ARGOCD_AUTH_TOKEN"
)

OPTIONAL_SECRETS=(
  "DEV_ENDPOINT"
  "STAGING_ENDPOINT"
  "PROD_ENDPOINT"
)

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not installed. Install from: https://cli.github.com/"
    exit 1
fi

# Get all secrets
ALL_SECRETS=$(gh secret list --json name --jq '.[].name' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to list secrets. Make sure you're authenticated: gh auth login"
    exit 1
fi

echo "✅ Required Secrets:"
MISSING_REQUIRED=0
for secret in "${REQUIRED_SECRETS[@]}"; do
    if echo "$ALL_SECRETS" | grep -q "^${secret}$"; then
        echo "  ✅ $secret"
    else
        echo "  ❌ $secret (MISSING)"
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
done

echo ""
echo "⚠️  Optional Secrets:"
for secret in "${OPTIONAL_SECRETS[@]}"; do
    if echo "$ALL_SECRETS" | grep -q "^${secret}$"; then
        echo "  ✅ $secret"
    else
        echo "  ⚪ $secret (not set)"
    fi
done

echo ""
if [ $MISSING_REQUIRED -eq 0 ]; then
    echo "🎉 All required secrets are configured!"
    exit 0
else
    echo "❌ Missing $MISSING_REQUIRED required secret(s). Please configure them before running the pipeline."
    exit 1
fi
```

**Usage:**

```bash
# Save script
curl -o check-secrets.sh https://raw.githubusercontent.com/TomJennyDev/Flowise/main/.github/scripts/check-secrets.sh

# Or create manually
nano check-secrets.sh
# Paste script above, save and exit

# Make executable
chmod +x check-secrets.sh

# Run check
./check-secrets.sh
```

### 🧪 Testing

```bash
# Test AWS access
aws ecr describe-repositories --region ap-southeast-1

# Test ArgoCD connection
argocd login ${ARGOCD_SERVER} --auth-token ${ARGOCD_AUTH_TOKEN} --grpc-web --insecure
argocd app list

# Test GitOps repo access
git clone https://${GITOPS_TOKEN}@github.com/TomJennyDev/devops.git

# Trigger manual deployment
# Go to: https://github.com/TomJennyDev/Flowise/actions/workflows/deploy-to-k8s.yml
# Click "Run workflow"
```

---

## Troubleshooting

### AWS Authentication Issues

**Error:** `Credentials could not be loaded`

**Solution:**

```bash
# Verify credentials are set
gh secret list | grep AWS

# Test credentials locally
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
aws sts get-caller-identity
```

### GitOps Token Issues

**Error:** `remote: Permission to TomJennyDev/devops.git denied`

**Solution:**

-   Check PAT has `repo` and `workflow` scopes
-   Regenerate token if expired
-   Verify token with: `curl -H "Authorization: token ${GITOPS_TOKEN}" https://api.github.com/user`

### ArgoCD Connection Issues

**Error:** `Failed to establish connection to argocd.yourdomain.com`

**Solution:**

-   Verify `ARGOCD_SERVER` doesn't include `https://`
-   Check server is accessible: `curl -k https://argocd.yourdomain.com`
-   Regenerate auth token if expired
-   Test login: `argocd login ${ARGOCD_SERVER} --auth-token ${ARGOCD_AUTH_TOKEN} --grpc-web --insecure`

### ECR Repository Not Found

**Error:** `repository does not exist`

**Solution:**

```bash
# Create repositories
aws ecr create-repository --repository-name flowise-server --region ap-southeast-1
aws ecr create-repository --repository-name flowise-ui --region ap-southeast-1
```

---

## Security Best Practices

### ✅ Do's

-   ✅ Use GitHub secrets for all sensitive data
-   ✅ Rotate credentials every 90 days
-   ✅ Use least privilege IAM policies
-   ✅ Enable GitHub secret scanning
-   ✅ Use OIDC instead of long-lived credentials (when possible)
-   ✅ Review IAM access logs regularly

### ❌ Don'ts

-   ❌ Never commit secrets to git
-   ❌ Never log secrets in GitHub Actions
-   ❌ Don't use root AWS credentials
-   ❌ Don't share secrets across multiple projects
-   ❌ Don't use personal accounts for automation

---

## Additional Resources

-   [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
-   [GitHub Actions Security](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
-   [ArgoCD Authentication](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
-   [ECR Authentication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html)

---

## Contact & Support

For issues or questions:

1. Check troubleshooting section above
2. Review workflow logs: https://github.com/TomJennyDev/Flowise/actions
3. Check ArgoCD UI: https://argocd.yourdomain.com
4. Review AWS CloudTrail logs for permission issues
