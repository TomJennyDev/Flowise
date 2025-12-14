# Quick Fix for ArgoCD Authentication Error

## Error

```
rpc error: code = Unauthenticated desc = invalid session: token signature is invalid
```

## Root Cause

`ARGOCD_AUTH_TOKEN` secret is invalid, expired, or incorrect.

## Solution

### Step 1: Generate New ArgoCD Token

```bash
# Login to ArgoCD
argocd login argocd.yourdomain.com --username admin

# Generate new token (valid for 1 year = 8760 hours)
argocd account generate-token --account admin --expires-in 8760h
```

**Output will be:**

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhcmdvY2QiLCJzdWIiOiJhZG1pbjphcGlLZXkiLCJuYmYiOjE3MzQxNjAwMDAsImlhdCI6MTczNDE2MDAwMCwiZXhwIjoxNzY1Njk2MDAwfQ.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 2: Update GitHub Secret

#### Via GitHub UI (Recommended):

1. Go to: https://github.com/TomJennyDev/Flowise/settings/secrets/actions
2. Click on `ARGOCD_AUTH_TOKEN`
3. Click **Update secret**
4. Paste the new token from Step 1
5. Click **Update secret**

#### Via GitHub CLI:

```bash
# Set new token
gh secret set ARGOCD_AUTH_TOKEN -b "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Verify
gh secret list | grep ARGOCD
```

### Step 3: Verify ArgoCD Server Address

Make sure `ARGOCD_SERVER` secret is correct (without `https://`):

**Correct:** `argocd.yourdomain.com` ✅  
**Wrong:** `https://argocd.yourdomain.com` ❌

Update if needed:

```bash
gh secret set ARGOCD_SERVER -b "argocd.yourdomain.com"
```

### Step 4: Test Connection Locally

```bash
# Export secrets (for testing only)
export ARGOCD_SERVER="argocd.yourdomain.com"
export ARGOCD_AUTH_TOKEN="eyJhbGciOiJIUzI1..."

# Test login
argocd login ${ARGOCD_SERVER} \
    --auth-token ${ARGOCD_AUTH_TOKEN} \
    --grpc-web \
    --insecure

# If successful, list apps
argocd app list
```

**Expected output:**

```
NAME              CLUSTER                         NAMESPACE          PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS
flowise-dev       https://kubernetes.default.svc  flowise-dev        default  Synced  Healthy  Auto        <none>
flowise-production https://kubernetes.default.svc flowise-production default  Synced  Healthy  Auto        <none>
```

### Step 5: Re-run GitHub Actions Workflow

1. Go to: https://github.com/TomJennyDev/Flowise/actions/workflows/deploy-to-k8s.yml
2. Click **Run workflow**
3. Select environment: `dev`
4. Click **Run workflow**

## Troubleshooting

### Token Still Invalid

**Check token format:**

-   Must start with `eyJ` (JWT format)
-   Should be ~200+ characters long
-   No spaces or newlines

**Verify ArgoCD user exists:**

```bash
argocd account list
```

If `admin` doesn't exist or has issues, create service account:

```bash
# Create service account in ArgoCD
kubectl create serviceaccount argocd-github-actions -n argocd

# Generate token for it
argocd account generate-token --account argocd-github-actions --expires-in 8760h
```

### Connection Timeout

**Check ArgoCD is accessible:**

```bash
curl -k https://argocd.yourdomain.com/healthz
```

Should return: `ok`

**Check from GitHub Actions runner:**
The issue might be network/firewall. ArgoCD must be publicly accessible or you need to setup VPN/bastion.

### GRPC-Web Required

If you get GRPC errors, make sure ArgoCD server has GRPC-web enabled:

```yaml
# argocd-server deployment
spec:
    template:
        spec:
            containers:
                - name: argocd-server
                  command:
                      - argocd-server
                      - --insecure
                      - --staticassets
                      - /shared/app
```

## Alternative: Skip ArgoCD Integration Temporarily

If you want to test just the build and ECR push without ArgoCD, you can:

1. Comment out the `update-gitops-and-deploy` and `health-check` jobs in workflow
2. Or use the simpler `test-build-ecr.yml` workflow instead

## Current Status

Based on your workflow error:

-   ✅ AWS credentials working (ECR login successful)
-   ✅ Docker builds working
-   ✅ GitOps repo accessible
-   ❌ ArgoCD authentication failed

**Next step:** Update `ARGOCD_AUTH_TOKEN` secret following steps above.
