# Tool versions
TERRAFORM_VERSION := 1.8.0
TFLINT_VERSION := 0.51.1
ACTIONLINT_VERSION := 1.7.7

# OS and architecture detection
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/; s/arm64/arm64/')

VENV := .venv

# Terraform variables
TF_WORKSPACE ?= default
TF_DIR := terraform

.PHONY: deps
deps:
	@mkdir -p ${VENV}/bin

.PHONY: tflint-install
tflint-install: deps
	@if ! command -v ${VENV}/bin/tflint >/dev/null 2>&1 || [ "$$(${VENV}/bin/tflint --version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')" != "${TFLINT_VERSION}" ]; then \
		echo "Installing tflint v${TFLINT_VERSION}..."; \
		echo "Downloading for OS: ${OS}, ARCH: ${ARCH}"; \
		mkdir -p ${VENV}/bin; \
		cd ${VENV}/bin; \
		curl -sL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_${OS}_${ARCH}.zip" -o tflint.zip; \
		unzip -o tflint.zip; \
		rm tflint.zip; \
		chmod +x tflint; \
		cd -; \
		${VENV}/bin/tflint --init; \
	fi

.PHONY: terraform-install
terraform-install: deps
	@if ! command -v ${VENV}/bin/terraform >/dev/null 2>&1 || [ "$$(${VENV}/bin/terraform version -json | jq -r '.terraform_version')" != "${TERRAFORM_VERSION}" ]; then \
		echo "Installing terraform v${TERRAFORM_VERSION}..."; \
		echo "Downloading for OS: ${OS}, ARCH: ${ARCH}"; \
		mkdir -p ${VENV}/bin; \
		cd ${VENV}/bin; \
		curl -sL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" -o terraform.zip; \
		unzip -o terraform.zip; \
		rm terraform.zip; \
		chmod +x terraform; \
		cd -; \
	fi

.PHONY: actionlint-install
actionlint-install: deps
	@if ! command -v ${VENV}/bin/actionlint >/dev/null 2>&1 || [ "$$(${VENV}/bin/actionlint -version 2>/dev/null | head -1)" != "${ACTIONLINT_VERSION}" ]; then \
		echo "Installing actionlint v${ACTIONLINT_VERSION}..."; \
		echo "Downloading for OS: ${OS}, ARCH: ${ARCH}"; \
		mkdir -p ${VENV}/bin; \
		cd ${VENV}/bin; \
		curl -sL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_${OS}_${ARCH}.tar.gz" -o actionlint.tar.gz; \
		tar xzf actionlint.tar.gz; \
		rm actionlint.tar.gz; \
		chmod +x actionlint; \
		cd -; \
	fi

.PHONY: lint
lint: tflint-install terraform-install actionlint-install
	PATH=${VENV}/bin:$$PATH tflint --recursive
	PATH=${VENV}/bin:$$PATH terraform -chdir=${TF_DIR} fmt -recursive -check
	PATH=${VENV}/bin:$$PATH actionlint $(git rev-parse --show-toplevel)

.PHONY: fix
fix: tflint-install terraform-install actionlint-install
	PATH=${VENV}/bin:$$PATH tflint --recursive --fix
	PATH=${VENV}/bin:$$PATH terraform -chdir=${TF_DIR} fmt -recursive
	PATH=${VENV}/bin:$$PATH actionlint $(git rev-parse --show-toplevel)
