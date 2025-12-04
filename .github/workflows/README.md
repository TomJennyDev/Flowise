# CI/CD Pipeline Setup Guide

## 🚀 Overview

Pipeline này sẽ:

1. **Build** Docker images cho Server và UI
2. **Push** images lên AWS ECR
3. **Update** GitOps repository với image tags mới
4. **Trigger** ArgoCD để deploy lên Kubernetes

---

## 📋 Prerequisites

### 1. AWS ECR Repositories

Tạo 2 ECR repositories:

```bash
aws ecr create-repository \
    --repository-name flowise-server \
    --region ap-southeast-1

aws ecr create-repository \
    --repository-name flowise-ui \
    --region ap-southeast-1
```

**Note**: Lưu lại ECR registry URL (ví dụ: `123456789012.dkr.ecr.ap-southeast-1.amazonaws.com`)

### 2. GitOps Repository

Tạo repository riêng cho Kustomize manifests:

-   Repository: `TomJennyDev/flowise-gitops`
-   Structure:
    ```
    flowise-gitops/
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

### 3. ArgoCD Applications

Tạo ArgoCD applications cho mỗi environment:

```bash
# Example for production
argocd app create flowise-production \
    --repo https://github.com/TomJennyDev/flowise-gitops.git \
    --path overlays/production \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace flowise-production \
    --sync-policy automated
```

---

## 🔐 GitHub Secrets Setup

Vào repository **Settings → Secrets and variables → Actions**, thêm các secrets sau:

### 📋 Quick Reference - All Required Secrets

**Bắt buộc (chọn 1 trong 2 options AWS):**

**Option 1 - AWS OIDC (Recommended):**

```
AWS_ROLE_TO_ASSUME       # ARN của IAM role
AWS_REGION               # AWS region (e.g., ap-southeast-1)
GITOPS_TOKEN            # GitHub PAT cho GitOps repo
ARGOCD_SERVER           # ArgoCD server URL
ARGOCD_AUTH_TOKEN       # ArgoCD authentication token
```

**Option 2 - AWS IAM User:**

```
AWS_ACCESS_KEY_ID       # AWS access key
AWS_SECRET_ACCESS_KEY   # AWS secret key
AWS_REGION              # AWS region (e.g., ap-southeast-1)
GITOPS_TOKEN            # GitHub PAT cho GitOps repo
ARGOCD_SERVER           # ArgoCD server URL
ARGOCD_AUTH_TOKEN       # ArgoCD authentication token
```

**Optional (cho health check):**

```
DEV_ENDPOINT            # Dev environment endpoint
STAGING_ENDPOINT        # Staging environment endpoint
PROD_ENDPOINT           # Production environment endpoint
```

---

### AWS Credentials (Option 1: OIDC - Recommended)

```
AWS_ROLE_TO_ASSUME=arn:aws:iam::123456789012:role/GitHubActionsRole
AWS_REGION=ap-southeast-1
```

**Setup OIDC:**

1. Tạo OIDC provider trong AWS IAM
2. Tạo IAM role với trust policy cho GitHub Actions
3. Attach policy cho ECR push permissions

### AWS Credentials (Option 2: IAM User)

```
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=ap-southeast-1
```

### GitOps Repository

```
GITOPS_TOKEN=ghp_...  # GitHub Personal Access Token với repo write access
```

**Tạo GitHub PAT:**

1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scopes: `repo` (full control)
4. Copy token

### ArgoCD

```
ARGOCD_SERVER=argocd.yourdomain.com
ARGOCD_AUTH_TOKEN=...
```

**Generate ArgoCD token:**

```bash
argocd login argocd.yourdomain.com

# Generate token (never expires)
argocd account generate-token --account github-actions

# Or with expiration (1 year)
argocd account generate-token --account github-actions --expires-in 8760h
```

### Health Check Endpoints (Optional)

```
DEV_ENDPOINT=https://dev-flowise.yourdomain.com
STAGING_ENDPOINT=https://staging-flowise.yourdomain.com
PROD_ENDPOINT=https://flowise.yourdomain.com
```

---

## 🎯 Usage

### Auto Deployment (Push Trigger)

Push vào main branch sẽ tự động trigger deployment:

```bash
# Deploy to production
git push origin main
```

**Tag logic (SHA-based):**

-   `main` → `abc1234` (7-character SHA)

### Manual Deployment

1. Vào **Actions** tab
2. Chọn workflow **"Deploy to Kubernetes via ArgoCD"**
3. Click **"Run workflow"**
4. Select:
    - **Environment**: dev/staging/production
    - **Tag version**: (optional) custom prefix (e.g., "v1.0.0"), SHA sẽ được thêm vào sau
    - **Node version**: 20

**Ví dụ manual tags:**

-   Empty input → `abc1234` (chỉ SHA)
-   Input "v1.0.0" → `v1.0.0-abc1234` (custom prefix + SHA)

---

## 📊 Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Set Environment Variables                                │
│    - Generate 7-char SHA from commit                        │
│    - Determine tag based on branch/input                    │
│    - Set environment (dev/staging/production)               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Build & Push Images (Parallel)                          │
│    ┌─────────────────┐  ┌─────────────────┐              │
│    │ Build Server    │  │ Build UI        │              │
│    │ → Push to ECR   │  │ → Push to ECR   │              │
│    │ → 3 tags:       │  │ → 3 tags:       │              │
│    │   - SHA         │  │   - SHA         │              │
│    │   - latest      │  │   - latest      │              │
│    │   - full-SHA    │  │   - full-SHA    │              │
│    └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Update GitOps Repository                                 │
│    - Checkout flowise-gitops repo                          │
│    - Update image tags in kustomization.yaml               │
│    - Commit and push changes                               │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Trigger ArgoCD                                           │
│    - Login to ArgoCD                                        │
│    - Trigger sync for environment                          │
│    - Wait for deployment to complete                       │
│    - Show deployment status                                │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Health Check (Optional)                                  │
│    - Wait for pods to stabilize                            │
│    - Call health check endpoint                            │
│    - Retry up to 10 times                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Troubleshooting

### Build fails with "Cannot find module"

**Cause**: Missing dependencies trong Dockerfile

**Fix**: Đảm bảo `.npmrc` được copy vào Docker:

```dockerfile
COPY .npmrc ./
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
```

### ArgoCD sync timeout

**Cause**: Deployment takes too long or unhealthy

**Fix**:

1. Check ArgoCD UI: `https://argocd.yourdomain.com`
2. Check application logs:
    ```bash
    argocd app get flowise-production
    argocd app logs flowise-production
    ```

### GitOps push failed

**Cause**: Invalid GitHub PAT or wrong permissions

**Fix**:

1. Regenerate GitHub PAT with `repo` scope
2. Update `GITOPS_TOKEN` secret
3. Retry workflow

### Health check failed

**Cause**: Application not ready or wrong endpoint

**Fix**:

1. Check Kubernetes pods:
    ```bash
    kubectl get pods -n flowise-production
    kubectl logs -n flowise-production deployment/flowise-server
    ```
2. Verify endpoint URLs in secrets
3. Increase timeout in workflow

---

## 🧪 Testing Guide

### Bước 1: Verify Prerequisites

Trước khi test, kiểm tra tất cả prerequisites đã setup:

```bash
# 1. Check ECR repositories exist
aws ecr describe-repositories --region ap-southeast-1 | grep flowise

# Expected output:
# "repositoryName": "flowise-server"
# "repositoryName": "flowise-ui"

# 2. Check GitOps repository exists
git clone https://github.com/TomJennyDev/flowise-gitops.git
cd flowise-gitops
ls -la overlays/  # Should see: dev/, staging/, production/

# 3. Check ArgoCD applications
argocd app list | grep flowise

# Expected output:
# flowise-dev          ...
# flowise-staging      ...
# flowise-production   ...

# 4. Verify GitHub secrets are configured
# Go to: https://github.com/TomJennyDev/Flowise/settings/secrets/actions
# Confirm all required secrets are present
```

### Bước 2: Test Local Docker Build (Optional)

Test Docker build locally trước khi chạy pipeline:

```bash
cd D:/devops/flowise/Flowise

# Build server image
docker build -f packages/server/Dockerfile -t flowise-server:test .

# Build UI image
docker build -f packages/ui/Dockerfile -t flowise-ui:test .

# Check images
docker images | grep flowise

# Test run server locally
docker run -p 3000:3000 flowise-server:test
```

### Bước 3: Test Manual Deployment (Recommended First)

**Cách 1: Test với Dev Environment**

1. Vào GitHub repository: `https://github.com/TomJennyDev/Flowise`
2. Click tab **Actions**
3. Chọn workflow **"Deploy to Kubernetes via ArgoCD"**
4. Click **"Run workflow"** (button xanh bên phải)
5. Fill form:
    ```
    Environment: dev
    Tag version: test-v1  (optional, để trống cũng được)
    Node version: 20
    ```
6. Click **"Run workflow"** để bắt đầu

**Monitor pipeline execution:**

```bash
# Watch GitHub Actions (trên browser)
# https://github.com/TomJennyDev/Flowise/actions

# Or theo dõi bằng CLI
gh run list --workflow=deploy-to-k8s.yml
gh run watch  # Watch latest run
```

**Verify từng job:**

-   ✅ **set-env**: Check logs xem tag và environment đúng chưa
-   ✅ **build-server**: Xem Docker build có lỗi không
-   ✅ **build-ui**: Xem Docker build có lỗi không
-   ✅ **update-gitops-and-deploy**: Check commit vào GitOps repo
-   ✅ **health-check**: Verify deployment thành công

### Bước 4: Verify Deployment

**Check ECR images:**

```bash
# List images in ECR
aws ecr list-images \
    --repository-name flowise-server \
    --region ap-southeast-1

aws ecr list-images \
    --repository-name flowise-ui \
    --region ap-southeast-1

# Should see 3 tags per image:
# - test-v1-abc1234  (your custom tag + SHA)
# - latest
# - full-commit-sha
```

**Check GitOps repository:**

```bash
cd flowise-gitops
git pull origin main

# View latest commit
git log -1

# Expected: "chore(dev): update images to test-v1-abc1234"

# Check kustomization.yaml
cat overlays/dev/kustomization.yaml

# Should show updated image tags:
# images:
#   - name: flowise-server
#     newName: 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server
#     newTag: test-v1-abc1234
```

**Check ArgoCD deployment:**

```bash
# Login to ArgoCD
argocd login argocd.yourdomain.com

# Check application status
argocd app get flowise-dev

# Expected output shows:
# Health Status: Healthy
# Sync Status: Synced

# View application resources
argocd app resources flowise-dev

# Check pods
kubectl get pods -n flowise-dev

# Should see:
# flowise-server-xxx   1/1   Running
# flowise-ui-xxx       1/1   Running
```

**Test application endpoint:**

```bash
# If you configured DEV_ENDPOINT secret
curl https://dev-flowise.yourdomain.com/api/v1/health

# Or port-forward locally
kubectl port-forward -n flowise-dev svc/flowise-server 3000:3000

# Then test
curl http://localhost:3000/api/v1/health
```

### Bước 5: Test Auto Deployment

Sau khi manual test thành công, test auto-deployment từ main branch:

```bash
cd D:/devops/flowise/Flowise

# Make a small change (e.g., update README)
echo "# Test deployment" >> TEST.md
git add TEST.md
git commit -m "test: trigger auto deployment"

# Push to main
git push origin main

# Pipeline sẽ tự động chạy!
```

**Monitor auto deployment:**

```bash
# Watch on GitHub Actions
# https://github.com/TomJennyDev/Flowise/actions

# Tag will be SHA-based, e.g., abc1234
# Environment will be production (auto-detected from main branch)
```

### Bước 6: Verify Production Deployment

```bash
# Check ArgoCD
argocd app get flowise-production

# Check production pods
kubectl get pods -n flowise-production

# Test production endpoint
curl https://flowise.yourdomain.com/api/v1/health
```

### 🐛 Common Issues During Testing

**Issue 1: Build fails with "Cannot find module"**

```bash
# Solution: Verify .npmrc is in repo root
ls -la .npmrc

# Should contain:
# shamefully-hoist=true
```

**Issue 2: ECR push failed - "authentication token expired"**

```bash
# Solution: Check AWS credentials
aws sts get-caller-identity

# Or re-configure AWS CLI
aws configure
```

**Issue 3: ArgoCD sync timeout**

```bash
# Check ArgoCD app details
argocd app get flowise-dev --refresh

# View sync history
argocd app history flowise-dev

# Manual sync if needed
argocd app sync flowise-dev --force
```

**Issue 4: Health check failed**

```bash
# Check pod status
kubectl get pods -n flowise-dev
kubectl logs -n flowise-dev deployment/flowise-server --tail=50

# Check service
kubectl get svc -n flowise-dev

# Check ingress
kubectl get ingress -n flowise-dev
```

**Issue 5: GitOps push failed**

```bash
# Verify GITOPS_TOKEN is valid
# Test manually:
git clone https://${GITOPS_TOKEN}@github.com/TomJennyDev/flowise-gitops.git

# If fails, regenerate token with 'repo' scope
```

### 📊 Success Criteria

Pipeline test thành công khi:

-   ✅ All 5 jobs complete without errors
-   ✅ 2 images pushed to ECR với 3 tags mỗi image
-   ✅ GitOps repo có commit mới với updated image tags
-   ✅ ArgoCD app shows "Healthy" và "Synced"
-   ✅ Kubernetes pods running (1/1 Ready)
-   ✅ Application responds to health check
-   ✅ New deployment visible trong ArgoCD UI

---

## 📝 Environment Variables

Update trong workflow file nếu cần:

```yaml
env:
    AWS_REGION: ap-southeast-1 # Your AWS region
    GITOPS_REPO: TomJennyDev/flowise-gitops # Your GitOps repo
```

---

## ✅ Checklist

Before running pipeline, verify:

-   [ ] ECR repositories created
-   [ ] GitOps repository setup với Kustomize structure
-   [ ] ArgoCD applications created
-   [ ] All GitHub secrets configured
-   [ ] `.npmrc` file exists trong repo root
-   [ ] Dockerfiles có `COPY .npmrc ./`
-   [ ] ArgoCD accessible và token valid

---

## 🏷️ Image Tagging Strategy

Pipeline sử dụng **Git SHA** cho tất cả tags để đảm bảo traceability:

**Mỗi image được push với 3 tags:**

1. **Primary tag**: SHA-based tag (e.g., `abc1234` hoặc `dev-abc1234`)
2. **Latest tag**: `latest` (cho environment)
3. **Full SHA tag**: Full commit SHA (e.g., `abc1234567890abcdef...`)

**Lợi ích của SHA-based tagging:**

-   ✅ **Immutable**: Mỗi commit có unique SHA
-   ✅ **Traceable**: Dễ dàng tìm lại commit tương ứng với image
-   ✅ **Rollback friendly**: Rollback bằng cách deploy lại SHA cũ
-   ✅ **No conflicts**: Không bao giờ bị trùng tag như timestamp

## 🔗 Useful Commands

```bash
# Check ECR images với SHA tags
aws ecr describe-images --repository-name flowise-server --region ap-southeast-1

# List images với specific SHA
aws ecr describe-images \
    --repository-name flowise-server \
    --region ap-southeast-1 \
    --image-ids imageTag=abc1234

# Verify GitOps changes
git clone https://github.com/TomJennyDev/flowise-gitops.git
cd flowise-gitops/overlays/production
kustomize build .

# Check ArgoCD app status
argocd app get flowise-production

# Manual sync ArgoCD
argocd app sync flowise-production

# Check Kubernetes resources
kubectl get all -n flowise-production
kubectl describe deployment flowise-server -n flowise-production
```

---

## 📚 References

-   [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
-   [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
-   [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
-   [GitHub Actions Documentation](https://docs.github.com/en/actions)
