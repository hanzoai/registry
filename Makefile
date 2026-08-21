.PHONY: help build test lint clean deploy status logs

CONTEXT ?= do-sfo3-hanzo-k8s
NAMESPACE ?= hanzo

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# The registry is upstream `registry:2`, configured entirely through REGISTRY_*
# env in k8s/deployment.yaml — so this repo publishes no image, and hanzo.yml
# declares no `images:`. ./Dockerfile and the config.yml it COPYs are built by
# nothing and reach no pod; the live config is the `registry-config` ConfigMap
# in universe. Edit either one and no deploy picks it up.
build: ## Nothing to build — the registry is upstream registry:2.
	@echo "nothing to build. the pod runs upstream registry:2, configured by REGISTRY_* env; ./Dockerfile has no consumer."

# The whole repo is YAML, so "does it parse" is the only check there is to run,
# and it is both the test and the lint. Stated once here; test is the alias.
# python3 because it is already on every box this runs on, where yq is not.
#
# The file list comes from git, not from a literal: a hardcoded list names files
# that move, and the target then fails on the absence rather than on a parse
# error — a red gate that says nothing about the YAML.
#
# `set -e` is load-bearing: recipe lines joined with `;` report the status of the
# LAST command, so without it a parse failure followed by `echo` exits 0 and the
# gate is green over a broken file.
lint: ## Parse every YAML this repo tracks.
	@set -e; \
	files=$$(git ls-files '*.yml' '*.yaml'); \
	[ -n "$$files" ] || { echo ">> no YAML tracked"; exit 0; }; \
	python3 -c 'import sys,yaml;[list(yaml.safe_load_all(open(f))) for f in sys.argv[1:]]' $$files; \
	echo ">> parsed: $$(echo $$files | tr "\n" " ")"

test: lint ## Alias for lint.

# Nothing to remove. The only files this Makefile ever writes are signing.key and
# signing.crt from generate-cert, and those are KEY MATERIAL, not build output:
# the deployed registry-signing-key secret is made from that keypair and the
# registry trusts the cert as its rootcertbundle, so deleting the private key
# would silently orphan a live secret nobody can regenerate a match for.
clean: ## Nothing to remove — this repo generates no build artifacts.
	@echo "nothing to clean. generate-cert writes signing.key/signing.crt — key material, delete those by hand if you mean to."

deploy: ## Deploy registry to k8s
	kubectl --context $(CONTEXT) apply -f k8s/
	kubectl --context $(CONTEXT) -n $(NAMESPACE) rollout restart deployment registry

status: ## Show registry status
	kubectl --context $(CONTEXT) -n $(NAMESPACE) get deployment registry
	kubectl --context $(CONTEXT) -n $(NAMESPACE) get pods -l app=registry
	kubectl --context $(CONTEXT) -n $(NAMESPACE) get pvc registry-data

logs: ## Tail registry logs
	kubectl --context $(CONTEXT) -n $(NAMESPACE) logs -l app=registry -f --tail=50

restart: ## Restart registry pods
	kubectl --context $(CONTEXT) -n $(NAMESPACE) rollout restart deployment registry

generate-cert: ## Generate a self-signed signing certificate for token auth
	openssl req -x509 -newkey rsa:4096 -keyout signing.key -out signing.crt -days 3650 -nodes -subj "/CN=hanzo-registry"
	@echo "Created signing.key and signing.crt"
	@echo "Create k8s secret: kubectl --context $(CONTEXT) -n $(NAMESPACE) create secret generic registry-signing-key --from-file=signing.crt=signing.crt --from-file=signing.key=signing.key"

create-secret: ## Create signing key secret from local files
	kubectl --context $(CONTEXT) -n $(NAMESPACE) create secret generic registry-signing-key \
		--from-file=signing.crt=signing.crt \
		--from-file=signing.key=signing.key \
		--dry-run=client -o yaml | kubectl --context $(CONTEXT) apply -f -
