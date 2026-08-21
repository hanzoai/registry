# registry

The Hanzo fleet OCI registry: upstream `registry:2` (Docker Distribution) with
Hanzo IAM token auth, S3-backed, served at **`oci.hanzo.ai`** and org-namespaced
`oci.hanzo.ai/<org>/<app>`. It holds container images and the Helm charts most CD
Applications pull on every sync, so it is load-bearing for fleet deploys.

`registry-hanzo-ai` is a Traefik file-router *name*, not a hostname: its rule
matches host `oci.hanzo.ai` and forwards to `registry.hanzo.svc.cluster.local:5000`.
`registry.hanzo.ai` is retired and no longer answers.

## The deployed spec lives in universe, not here

| Fact | Home in `hanzoai/universe` |
|---|---|
| Deployment, Service, image digest | `charts/app/values/hanzo/registry.yaml` (the `fleet` ApplicationSet) |
| Registry config — S3 storage, CORS | `infra/k8s/registry/configmap.yaml` → ConfigMap `registry-config` |
| `REGISTRY_AUTH_TOKEN_*` | the same chart values file. Env overrides the ConfigMap, so auth is declared there and only there |
| Public routing | `infra/k8s/ingress/routes.yaml` |
| IAM app + push credential reconcile | `infra/k8s/registry/register-app-job.yaml` |

Storage is `hanzoai/s3` at `s3.hanzo.svc:9000`, bucket `registry`, with blob
redirects disabled — the S3 endpoint is cluster-internal, so a presigned redirect
hands an external client an unresolvable host.

## ⚠ OPEN DEFECT — two movers write this Deployment, and they disagree

`.hanzo/workflows/deploy.yml` here runs `kubectl apply -f k8s/`, and universe's
`charts/app/values/hanzo/registry.yaml` carries `cd.automated: true`, so
cd.hanzo.ai reconciles the same object. Both write Deployment `registry` in ns
`hanzo`, and their declarations are not the same registry.

Live is the universe one, measured: `GET https://oci.hanzo.ai/v2/` answers 401
with `Bearer realm="https://hanzo.id/v1/iam/registry/token",
service="oci.hanzo.ai"`. `k8s/deployment.yaml` declares filesystem storage on
the `registry-data` PVC with no S3 config, `REGISTRY_AUTH_TOKEN_SERVICE:
registry.hanzo.ai`, and a realm at `iam.hanzo.ai/api/registry/token`. Applying
it points the fleet registry at an empty volume and mints tokens under a
service name it refuses — and a refused token reads as bad credentials, not as
config. CD heals it, but image pushes and the chart pulls most CD Applications
do on every sync fail until it does.

This needs an owner call on WHICH mover survives, not a patch. One of the two
declarations has to go: either `k8s/` is deleted and the deploy lane with it, or
the universe values file drops `cd.automated` and `k8s/` is reconciled to live
first. Until then, do not push to `k8s/**` — that path is what fires the lane.

`make deploy` runs the same two kubectl commands and carries the same hazard.

## Auth

Client hits `oci.hanzo.ai` → 401 carrying the realm in `WWW-Authenticate` → client
fetches a token from `hanzo.id/v1/iam/registry/token?service=oci.hanzo.ai&scope=repository:<org>/<app>:pull,push`,
basic-auth as the `hanzo-registry` IAM app → registry validates the JWT against
`signing.crt`, mounted from secret `registry-signing-key` as `rootcertbundle`.

The IAM-side `hanzo-registry` clientSecret and the KMS-distributed
`registry-credentials` docker secret must agree or every exchange 401s;
`register-app-job.yaml` in universe reconciles them non-destructively.

## Make

`lint` (= `test`) parses every YAML the repo ships; `hanzo.yml` runs kubeconform
-strict over `k8s/` in CI. `build` and `clean` are no-ops for the fleet verb set.
`generate-cert` writes `signing.key`/`signing.crt`: key material the live
`registry-signing-key` secret is made from, not build output.
