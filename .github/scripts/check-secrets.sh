#!/bin/bash
# Script to verify all required GitHub secrets are configured

set -e

echo "🔍 Checking GitHub Secrets Configuration..."
echo "=========================================="
echo ""

# Required secrets
REQUIRED_SECRETS=(
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "GITOPS_TOKEN"
  "ARGOCD_SERVER"
  "ARGOCD_AUTH_TOKEN"
)

# Optional secrets (for health checks)
OPTIONAL_SECRETS=(
  "DEV_ENDPOINT"
  "STAGING_ENDPOINT"
  "PROD_ENDPOINT"
)

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo ""
    echo "Install from: https://cli.github.com/"
    echo "Or run: brew install gh (macOS)"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo ""
    echo "Run: gh auth login"
    exit 1
fi

# Get all secrets from the repository
echo "📋 Fetching secrets from repository..."
ALL_SECRETS=$(gh secret list --json name --jq '.[].name' 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to list secrets. Check your permissions."
    exit 1
fi

echo ""
echo "✅ Required Secrets (MUST be set):"
echo "─────────────────────────────────"
MISSING_REQUIRED=0
for secret in "${REQUIRED_SECRETS[@]}"; do
    if echo "$ALL_SECRETS" | grep -q "^${secret}$"; then
        # Get last updated date
        UPDATED=$(gh secret list --json name,updatedAt --jq ".[] | select(.name==\"${secret}\") | .updatedAt" | cut -d'T' -f1)
        echo "  ✅ $secret (updated: $UPDATED)"
    else
        echo "  ❌ $secret (MISSING - REQUIRED)"
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
done

echo ""
echo "⚠️  Optional Secrets (for health checks):"
echo "─────────────────────────────────────────"
MISSING_OPTIONAL=0
for secret in "${OPTIONAL_SECRETS[@]}"; do
    if echo "$ALL_SECRETS" | grep -q "^${secret}$"; then
        UPDATED=$(gh secret list --json name,updatedAt --jq ".[] | select(.name==\"${secret}\") | .updatedAt" | cut -d'T' -f1)
        echo "  ✅ $secret (updated: $UPDATED)"
    else
        echo "  ⚪ $secret (not set)"
        MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
    fi
done

echo ""
echo "=========================================="
echo ""

# Summary
if [ $MISSING_REQUIRED -eq 0 ]; then
    echo "🎉 SUCCESS! All required secrets are configured."
    echo ""
    if [ $MISSING_OPTIONAL -gt 0 ]; then
        echo "ℹ️  Note: $MISSING_OPTIONAL optional secret(s) not set."
        echo "   Health checks will be skipped without endpoint URLs."
    fi
    echo ""
    echo "✅ You can now run the deployment pipeline!"
    echo "   Go to: https://github.com/TomJennyDev/Flowise/actions/workflows/deploy-to-k8s.yml"
    exit 0
else
    echo "❌ FAILED! Missing $MISSING_REQUIRED required secret(s)."
    echo ""
    echo "📖 Setup guide: .github/workflows/SECRETS.md"
    echo "🔗 Add secrets at: https://github.com/TomJennyDev/Flowise/settings/secrets/actions"
    echo ""
    echo "Required secrets to add:"
    for secret in "${REQUIRED_SECRETS[@]}"; do
        if ! echo "$ALL_SECRETS" | grep -q "^${secret}$"; then
            echo "  - $secret"
        fi
    done
    exit 1
fi
