# Hanzo Registry

The fleet OCI registry on hanzo-k8s, authenticated with Hanzo IAM tokens.

- **Endpoint**: `oci.hanzo.ai` — container images and Helm charts
- **Image**: upstream `registry:2` (Docker Distribution)
- **Auth**: token realm `https://hanzo.id/v1/iam/registry/token`, service `oci.hanzo.ai`
- **Storage**: `hanzoai/s3` at `s3.hanzo.svc:9000`, bucket `registry`

Repositories are org-namespaced — `oci.hanzo.ai/<org>/<app>`, never a bare name.

```bash
# Login (uses Hanzo IAM credentials)
docker login oci.hanzo.ai

# Push an image
docker tag myapp:latest oci.hanzo.ai/hanzoai/myapp:v1.0.0
docker push oci.hanzo.ai/hanzoai/myapp:v1.0.0

# Pull an image
docker pull oci.hanzo.ai/hanzoai/myapp:v1.0.0
```

## Deployment

Declared in `hanzoai/universe`, applied by Hanzo CD — not from this repo.
Change the workload in `charts/app/values/hanzo/registry.yaml`; CD reconciles it.

```bash
make status    # read the live workload
make logs
make restart   # roll the pods; CD reconciles the same spec
```

## Setup (first time)

1. Generate the signing certificate: `make generate-cert`
2. Create the k8s secret: `make create-secret`

## Structure

```
hanzo.yml               # CI: parse every YAML this repo tracks
Makefile                # Read the live workload, write token signing material
LLM.md                  # Deep notes: where each fact lives, auth exchange, traps
```

## Auth flow

1. Docker client attempts to push/pull from `oci.hanzo.ai`
2. Registry returns 401 with the token realm in `WWW-Authenticate`
3. Client requests a token from `https://hanzo.id/v1/iam/registry/token`
4. IAM validates credentials and returns a signed JWT
5. Client retries with the JWT in the Authorization header
6. Registry validates the JWT signature against `signing.crt`
