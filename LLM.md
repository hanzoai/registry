# registry — AI Assistant Context

**The** canonical container registry for the Lux / Hanzo / Zoo fleet. Self-hosted
on hanzo-k8s, **S3-backed** (hanzoai/s3). One registry, one way — it replaces
GHCR as the fleet's push/store target and exists precisely to escape GitHub's
GHCR push + Actions-artifact storage quotas.

## Canonical facts
- Engine `registry:2` (Distribution 2.8.3), namespace `hanzo` on hanzo-k8s.
- Storage = **S3 driver → hanzoai/s3** (`s3.hanzo.svc:9000`, bucket `registry`,
  `forcepathstyle: true`). No PVC, unlimited, our boxes. (Was a 50Gi PVC until
  2026-06-20.)
- `config.yml` is source of truth, shipped as the `registry-config` ConfigMap
  mounted over the image default → change storage/auth with no image rebuild.
- Auth = IAM token, realm `https://iam.hanzo.ai/api/registry/token`, issuer
  `hanzo-iam`, JWT verified against `SIGNING_CRT` (in `registry-signing-key`).
- Branded hosts (one store, like s3.lux.cloud): `registry.hanzo.ai`,
  `registry.lux.network`, `registry.zoo.network` → same Service. Images
  org-namespaced: `<host>/<org>/<app>`.

## Secrets (none in repo)
- `s3-credentials` (THE canonical s3 root secret, also used by the `s3` deploy):
  keys `access-key` / `secret-key` → `REGISTRY_STORAGE_S3_ACCESSKEY/SECRETKEY`.
  NB: the `hanzo-s3` secret's keys are stale — do not use them.
- `registry-signing-key`: cert under key `SIGNING_CRT` (NOT `signing.crt`).

## How CI pushes
Repo `hanzo.yml` sets `repo: registry.hanzo.ai/<org>/<app>`; `hanzoai/ci` logs in
with a KMS-provided IAM robot credential for app `hanzo-registry`. Build → push
here → universe (GitOps) or the operator deploys.

## Known gap (2026-06-20)
Storage is live + verified (bucket created, pod healthy on S3). PUSH auth needs
the IAM application **`hanzo-registry`** registered (per the `<org>-<app>` IAM
convention) — a test push currently 401s with `Application not found for client
ID: hanzo`. Register `hanzo-registry` in Hanzo IAM, then CI/clients can push.

## Deploy
`kubectl apply -f k8s/create-bucket-job.yaml` (one-time bucket), then
`kubectl apply -f k8s/{configmap,deployment,service}.yaml`. See README.md.
