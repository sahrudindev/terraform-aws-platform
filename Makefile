# Convenience targets. Everything here also runs in CI.
SHELL := /bin/bash
ENVS  := dev prod

# Which AWS profile every target runs against.
# Override per invocation: make bootstrap AWS_PROFILE=other
AWS_PROFILE ?= cloudops
export AWS_PROFILE

# Terraform asks for confirmation before it changes anything, which is the right
# default for a human at a terminal. Set AUTO_APPROVE=1 for non-interactive
# runs - CI, or a shell with no TTY. Read the plan first either way.
APPROVE := $(if $(AUTO_APPROVE),-auto-approve,)
MODULES := $(wildcard modules/*/)

.PHONY: help bootstrap fmt validate lint test security docs check clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Create the state bucket, then move this stack's own state into it
	@set -euo pipefail; \
	cd bootstrap; \
	if [ -f backend.tf ]; then \
	  echo "--> backend already enabled; running apply against remote state"; \
	  terraform init -backend-config=backend.hcl -input=false; \
	  terraform apply -input=false $(APPROVE); \
	else \
	  echo "--> step 1/3: creating the bucket with local state"; \
	  terraform init -input=false; \
	  terraform apply -input=false $(APPROVE); \
	  BUCKET=$$(terraform output -raw state_bucket); \
	  echo "--> step 2/3: pointing every stack at $$BUCKET"; \
	  echo "bucket = \"$$BUCKET\"" > backend.hcl; \
	  for d in ../environments/dev ../environments/prod ../global; do \
	    echo "bucket = \"$$BUCKET\"" > $$d/backend.hcl; \
	  done; \
	  echo "--> step 3/3: migrating bootstrap state into the bucket"; \
	  cp backend.tf.tpl backend.tf; \
	  terraform init -backend-config=backend.hcl -migrate-state -force-copy; \
	  rm -f terraform.tfstate terraform.tfstate.backup; \
	  echo "--> done. No Terraform state remains on this machine."; \
	fi

fmt: ## Rewrite all files to canonical format
	terraform fmt -recursive

validate: ## terraform validate every stack and module
	@for d in bootstrap global environments/dev environments/prod $(MODULES); do \
	  echo "--> $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null || exit 1; \
	  terraform -chdir=$$d validate || exit 1; \
	done

lint: ## tflint across the repository
	tflint --init && tflint --recursive --format compact

test: ## Run terraform test (mocked providers, no AWS credentials needed)
	@for d in $(MODULES); do \
	  if compgen -G "$$d/tests/*.tftest.hcl" >/dev/null; then \
	    echo "--> $$d"; \
	    terraform -chdir=$$d init -input=false >/dev/null || exit 1; \
	    terraform -chdir=$$d test || exit 1; \
	  fi; \
	done

security: ## checkov + trivy + gitleaks
	checkov -d . --config-file .checkov.yaml --compact
	trivy config --severity HIGH,CRITICAL .
	gitleaks detect --no-banner

docs: ## Regenerate the input/output tables in each module README
	@for d in $(MODULES); do terraform-docs markdown table --output-file README.md --output-mode inject "$$d"; done

check: fmt validate lint test ## Everything a PR must pass

clean: ## Remove local Terraform working directories
	find . -type d -name .terraform -prune -exec rm -rf {} +
	find . -name '*.tfplan' -delete
