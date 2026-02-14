# Hanzo Registry

Docker container registry with Hanzo IAM token authentication.

## Overview

Private Docker registry running on hanzo-k8s, authenticated via Hanzo IAM token-based auth.

- **Image**: `registry:2` (Docker Distribution)
- **Auth**: Token-based via `https://iam.hanzo.ai/api/registry/token`
- **Storage**: 50Gi PVC on DigitalOcean Block Storage
- **Endpoint**: `registry.hanzo.ai` (proxied through Cloudflare → KrakenD)

## Usage

```bash
# Login (uses Hanzo IAM credentials)
docker login registry.hanzo.ai

# Push an image
docker tag myapp:latest registry.hanzo.ai/myapp:latest
docker push registry.hanzo.ai/myapp:latest

# Pull an image
docker pull registry.hanzo.ai/myapp:latest
```

## Deployment

```bash
# Deploy to hanzo-k8s
make deploy

# Check status
make status

# View logs
make logs
```

## Setup (first time)

1. Generate signing certificate:
   ```bash
   make generate-cert
   ```

2. Create the k8s secret:
   ```bash
   make create-secret
   ```

3. Deploy:
   ```bash
   make deploy
   ```

## Structure

```
config.yml              # Registry configuration
Dockerfile              # Custom registry image (optional)
k8s/
  deployment.yaml       # Registry deployment with IAM auth
  service.yaml          # ClusterIP service on port 5000
  pvc.yaml              # 50Gi persistent volume claim
Makefile                # Deploy and manage commands
```

## Auth Flow

1. Docker client attempts to push/pull from `registry.hanzo.ai`
2. Registry returns 401 with token realm URL
3. Client requests token from `https://iam.hanzo.ai/api/registry/token`
4. IAM validates credentials and returns signed JWT
5. Client retries with JWT in Authorization header
6. Registry validates JWT signature against `signing.crt`
