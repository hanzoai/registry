# Hanzo Registry

Docker container registry with Hanzo IAM token authentication.

## Overview

The fleet OCI registry on hanzo-k8s, authenticated with Hanzo IAM tokens.

- **Endpoint**: `oci.hanzo.ai`
- **Image**: `registry:2` (Docker Distribution)
- **Auth**: token realm `https://hanzo.id/v1/iam/registry/token`, service `oci.hanzo.ai`
- **Storage**: `hanzoai/s3` at `s3.hanzo.svc:9000`, bucket `registry`

Repositories are org-namespaced — `oci.hanzo.ai/<org>/<app>`, never a bare name.

```bash
# Login (uses Hanzo IAM credentials)
docker login oci.hanzo.ai

# Push an image
docker tag myapp:latest oci.hanzo.ai/hanzoai/myapp:latest
docker push oci.hanzo.ai/hanzoai/myapp:latest

# Pull an image
docker pull oci.hanzo.ai/hanzoai/myapp:latest
```

## Deployment

`.hanzo/workflows/deploy.yml` applies `k8s/` and rolls the Deployment on a push
to `main` touching `k8s/**`. `make deploy` runs the same two kubectl commands.

```bash
make deploy    # kubectl apply -f k8s/ + rollout restart
make status
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

## Structure

```
k8s/                    # Deployment, Service, PVC — applied by .hanzo/workflows/deploy.yml
hanzo.yml               # CI: kubeconform -strict over k8s/
Makefile                # Deploy, read the live workload, write token signing material
LLM.md                  # Deep notes: routing, auth exchange, where each fact lives
```

## Auth Flow

1. Docker client attempts to push/pull from `oci.hanzo.ai`
2. Registry returns 401 with the token realm in `WWW-Authenticate`
3. Client requests token from `https://hanzo.id/v1/iam/registry/token`
4. IAM validates credentials and returns signed JWT
5. Client retries with JWT in Authorization header
6. Registry validates JWT signature against `signing.crt`
