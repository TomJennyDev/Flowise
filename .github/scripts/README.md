# GitHub Secrets Verification Script

## Overview

This directory contains utility scripts to verify GitHub secrets configuration for the CI/CD pipeline.

## Scripts

### `check-secrets.sh`

Verifies that all required secrets are configured in the GitHub repository.

**Usage:**

```bash
# Make executable (first time only)
chmod +x .github/scripts/check-secrets.sh

# Run check
./.github/scripts/check-secrets.sh
```

**Prerequisites:**

-   GitHub CLI (`gh`) installed: https://cli.github.com/
-   Authenticated with GitHub: `gh auth login`
-   Access to repository secrets

**Output:**

✅ **Success output:**

```
🔍 Checking GitHub Secrets Configuration...
==========================================

📋 Fetching secrets from repository...

✅ Required Secrets (MUST be set):
─────────────────────────────────
  ✅ AWS_ACCESS_KEY_ID (updated: 2025-12-13)
  ✅ AWS_SECRET_ACCESS_KEY (updated: 2025-12-13)
  ✅ GITOPS_TOKEN (updated: 2025-12-13)
  ✅ ARGOCD_SERVER (updated: 2025-12-13)
  ✅ ARGOCD_AUTH_TOKEN (updated: 2025-12-13)

⚠️  Optional Secrets (for health checks):
─────────────────────────────────────────
  ✅ DEV_ENDPOINT (updated: 2025-12-13)
  ⚪ STAGING_ENDPOINT (not set)
  ⚪ PROD_ENDPOINT (not set)

==========================================

🎉 SUCCESS! All required secrets are configured.

ℹ️  Note: 2 optional secret(s) not set.
   Health checks will be skipped without endpoint URLs.

✅ You can now run the deployment pipeline!
   Go to: https://github.com/TomJennyDev/Flowise/actions/workflows/deploy-to-k8s.yml
```

❌ **Failure output:**

```
🔍 Checking GitHub Secrets Configuration...
==========================================

📋 Fetching secrets from repository...

✅ Required Secrets (MUST be set):
─────────────────────────────────
  ✅ AWS_ACCESS_KEY_ID (updated: 2025-12-13)
  ❌ AWS_SECRET_ACCESS_KEY (MISSING - REQUIRED)
  ⚪ GITOPS_TOKEN (MISSING - REQUIRED)
  ✅ ARGOCD_SERVER (updated: 2025-12-13)
  ❌ ARGOCD_AUTH_TOKEN (MISSING - REQUIRED)

==========================================

❌ FAILED! Missing 3 required secret(s).

📖 Setup guide: .github/workflows/SECRETS.md
🔗 Add secrets at: https://github.com/TomJennyDev/Flowise/settings/secrets/actions

Required secrets to add:
  - AWS_SECRET_ACCESS_KEY
  - GITOPS_TOKEN
  - ARGOCD_AUTH_TOKEN
```

## Quick Check (Without Installing gh CLI)

If you don't have GitHub CLI installed, you can manually check via GitHub UI:

1. Go to: https://github.com/TomJennyDev/Flowise/settings/secrets/actions
2. Verify these secrets exist:

**Required (5):**

-   ✅ `AWS_ACCESS_KEY_ID`
-   ✅ `AWS_SECRET_ACCESS_KEY`
-   ✅ `GITOPS_TOKEN`
-   ✅ `ARGOCD_SERVER`
-   ✅ `ARGOCD_AUTH_TOKEN`

**Optional (3):**

-   ⚪ `DEV_ENDPOINT`
-   ⚪ `STAGING_ENDPOINT`
-   ⚪ `PROD_ENDPOINT`

## Troubleshooting

### GitHub CLI Not Installed

```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli/blob/trunk/docs/install_linux.md

# Windows
# Download from: https://cli.github.com/
```

### Not Authenticated

```bash
gh auth login
# Follow prompts to authenticate
```

### Permission Denied

Make sure your GitHub account has access to repository settings and secrets.

### Script Permission Denied

```bash
chmod +x .github/scripts/check-secrets.sh
```

## Integration with CI/CD

This script can be integrated into your local development workflow:

```bash
# Before pushing changes
git add .
git commit -m "feat: update pipeline"

# Verify secrets before pushing
./.github/scripts/check-secrets.sh && git push
```

Or add to `.git/hooks/pre-push`:

```bash
#!/bin/bash
echo "Checking secrets configuration..."
./.github/scripts/check-secrets.sh
if [ $? -ne 0 ]; then
    echo "❌ Please configure all required secrets before pushing"
    exit 1
fi
```

## See Also

-   [Secrets Configuration Guide](../workflows/SECRETS.md)
-   [Deployment Workflow](../workflows/deploy-to-k8s.yml)
-   [GitHub CLI Documentation](https://cli.github.com/manual/)
