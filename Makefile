SHELL := /bin/bash
.ONESHELL:
.DEFAULT_GOAL := help

ROOT := $(abspath $(CURDIR))
DIST := $(ROOT)/dist
CACHE := $(ROOT)/build/cache

# Override: make ARCH=arm64 iso
ARCH ?= amd64
BASE_ISO := $(CACHE)/debian-13.4.0-$(ARCH)-netinst.iso
OUT_ISO := $(DIST)/homeos-debian-13.4-$(ARCH).iso

BUILDER_IMAGE := homeos-builder:latest

.PHONY: help iso builder base-iso qemu-test clean refresh-pins pin-tools check-pubkey check-static

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

check-pubkey: ## warn if secrets/authorized_keys missing (public builds ship without)
	@if [ ! -s secrets/authorized_keys ]; then \
	  echo "WARNING: secrets/authorized_keys missing. Building PUBLIC distro."; \
	  echo "         Default login: admin / homeos (forced change on first SSH)."; \
	  echo "         To bake your key, run: cp ~/.ssh/id_ed25519.pub secrets/authorized_keys"; \
	fi

builder: ## build the docker builder image
	docker build -t $(BUILDER_IMAGE) build/

base-iso: ## download upstream debian netinst iso (ARCH=amd64|arm64)
	mkdir -p $(CACHE)
	bash build/download-base-iso.sh $(BASE_ISO) $(ARCH)

pin-tools: ## refresh github tool SHAs into bootstrap/vars/main.yml
	bash build/refresh-pins.sh --write

check-static: ## run non-VM static policy checks
	@echo "[check] shell syntax"
	bash -n build/*.sh bootstrap/installers/*.sh \
	  bootstrap/roles/homeos-cli/files/homeos \
	  bootstrap/roles/homeos-cli/files/homeos-audit-prune \
	  bootstrap/roles/portal/templates/launch.sh.j2
	@echo "[check] Python syntax"
	python3 -m py_compile build/check-yaml.py build/check-markers.py build/check-supply-chain.py
	@echo "[check] CLI UX harness"
	bash build/test-homeos-cli-ux.sh
	@echo "[check] stack snapshot harness"
	bash build/test-homeos-stack-snapshots.sh
	@echo "[check] supply-chain policy"
	python3 build/check-supply-chain.py
	@echo "[check] YAML parse"
	python3 build/check-yaml.py
	@echo "[check] forbidden marker strings"
	python3 build/check-markers.py

iso: check-pubkey check-static builder base-iso ## build the homeos ISO from committed pins
	mkdir -p $(DIST)
	docker run --rm --privileged \
	  -v $(ROOT):/work \
	  -v $(CACHE):/cache \
	  -v $(DIST):/dist \
	  $(BUILDER_IMAGE) \
	  /work/build/repack-iso.sh /cache/$(notdir $(BASE_ISO)) /dist/$(notdir $(OUT_ISO)) $(ARCH)
	@echo
	@echo "Built: $(OUT_ISO)"
	@sha256sum $(OUT_ISO) | tee $(OUT_ISO).sha256

qemu-test: ## boot the ISO in QEMU (needs qemu-system-x86)
	mkdir -p $(CACHE)/qemu
	[ -f $(CACHE)/qemu/disk1.qcow2 ] || qemu-img create -f qcow2 $(CACHE)/qemu/disk1.qcow2 60G
	[ -f $(CACHE)/qemu/disk2.qcow2 ] || qemu-img create -f qcow2 $(CACHE)/qemu/disk2.qcow2 20G
	qemu-system-x86_64 \
	  -enable-kvm -m 8192 -smp 4 \
	  -nographic -serial mon:stdio \
	  -drive file=$(CACHE)/qemu/disk1.qcow2,if=virtio \
	  -drive file=$(CACHE)/qemu/disk2.qcow2,if=virtio \
	  -cdrom $(OUT_ISO) \
	  -boot d \
	  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
	  -device virtio-net-pci,netdev=net0

refresh-pins: ## update tool commit SHAs in bootstrap/vars/main.yml
	bash build/refresh-pins.sh

clean: ## remove build artifacts
	rm -rf $(DIST)/* $(CACHE)/qemu
