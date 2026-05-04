SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

.PHONY: help check shellcheck syntax smoke clean

help: ## show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

check: shellcheck syntax ## run all local static checks

shellcheck: ## run shellcheck against installer scripts
	shellcheck --severity=warning universal-installer/install.sh universal-installer/smoke-test.sh

syntax: ## run bash syntax checks against installer scripts
	bash -n universal-installer/install.sh
	bash -n universal-installer/smoke-test.sh

smoke: ## run fast Docker smoke tests for parser/security paths
	docker run --rm \
	  -v "$$PWD/universal-installer/install.sh:/install.sh:ro" \
	  -v "$$PWD/universal-installer/smoke-test.sh:/smoke-test.sh:ro" \
	  debian:bookworm \
	  bash /smoke-test.sh

clean: ## remove local transient files
	rm -rf .pytest_cache .ruff_cache __pycache__
