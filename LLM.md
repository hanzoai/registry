# registry

The Hanzo fleet OCI registry: upstream `registry:2` (Docker Distribution) with
Hanzo IAM token auth, S3-backed, served at **`oci.hanzo.ai`** and org-namespaced
`oci.hanzo.ai/<org>/<app>`. It holds container images and the Helm charts most CD
Applications pull on every sync, so it is load-bearing for fleet deploys.

`oci.hanzo.ai` and `pkg.hanzo.ai` (packages) are the only two artifact hosts.

## The deployed spec lives in universe, not here

This repo carries no manifests. Everything that defines the running registry is
declared in `hanzoai/universe` and applied by Hanzo CD:

| Fact | Home in `hanzoai/universe` |
|---|---|
| Deployment, Service, image digest, `REGISTRY_AUTH_TOKEN_*` | `charts/app/values/hanzo/registry.yaml` (the `fleet` ApplicationSet) |
| Registry config — S3 storage, CORS | `infra/k8s/registry/configmap.yaml` → ConfigMap `registry-config` |
| Public routing | `infra/k8s/ingress/routes.yaml`, router `oci-hanzo-ai` |
| IAM app + push credential reconcile | `infra/k8s/registry/register-app-job.yaml` |

⚠ Auth is declared in the chart values as env, and env OVERRIDES the ConfigMap.
Adding an `auth:` block to the ConfigMap changes nothing; deleting the env arms
whatever the ConfigMap says instead. A token minted for one service name is
refused for another, and that failure reads as bad credentials rather than as
config.

Storage is `hanzoai/s3` at `s3.hanzo.svc:9000`, bucket `registry`, with blob
redirects disabled — the S3 endpoint is cluster-internal, so a presigned redirect
would hand an external client an unresolvable host.

## Auth

Client hits `oci.hanzo.ai` → 401 carrying the realm in `WWW-Authenticate` → client
fetches a token from
`hanzo.id/v1/iam/registry/token?service=oci.hanzo.ai&scope=repository:<org>/<app>:pull,push`,
basic-auth as the `hanzo-registry` IAM app → registry validates the JWT against
`signing.crt`, mounted from secret `registry-signing-key` as `rootcertbundle`.

The IAM-side `hanzo-registry` clientSecret and the KMS-distributed
`registry-credentials` docker secret must agree or every exchange 401s;
`register-app-job.yaml` in universe reconciles them non-destructively.

## Make

`lint` (= `test`) parses every YAML this repo tracks. `build` and `clean` are
no-ops for the fleet verb set: the pod runs upstream `registry:2`, so there is no
image of ours to build and nothing to remove.

`status`, `logs` and `restart` read or roll the live workload. They do not
declare it — CD reconciles the spec from universe either way.

`generate-cert` writes `signing.key`/`signing.crt`: the key material the live
`registry-signing-key` secret is made from, not build output. Deleting the
private key orphans a live secret nobody can regenerate a match for.
