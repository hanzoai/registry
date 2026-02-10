.PHONY: help deploy status logs

CONTEXT ?= do-sfo3-hanzo-k8s
NAMESPACE ?= hanzo

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

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
