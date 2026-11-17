# Makefile: manages socket_vmnet, bootp, k8s clusters
#
# Every public target carries a "## description" comment; `make help` prints them.
# Note: macOS ships GNU make 3.81, so this file avoids newer features
# (.SHELLFLAGS, .ONESHELL) and uses `set -e` inside recipes instead.

.DEFAULT_GOAL := help
SHELL := /bin/bash

NODES := k8scp000 k8sw000 k8sw001
VM := mydev00
ANSIBLE_DIR := ansible
VENV := $(abspath $(ANSIBLE_DIR)/.venv)
VENV_STAMP := $(VENV)/.installed
VENV_PIP := "$(VENV)/bin/python" -m pip install --quiet
REQUIREMENTS := $(ANSIBLE_DIR)/requirements.txt
PYTHON := python3

CREATE_CLUSTER_PLAYBOOK := playbooks/create_cluster.yml
DELETE_CLUSTER_PLAYBOOK := playbooks/delete_cluster.yml
CREATE_VM_PLAYBOOK := playbooks/create_vm.yml
DELETE_VM_PLAYBOOK := playbooks/delete_vm.yml
INSTALL_KUBEADM_PLAYBOOK := playbooks/create_kubeadm.yml
DELETE_VMNET_SOCKET_PLAYBOOK := playbooks/delete_vmnet_socket.yml

.PHONY: all help test clean venv \
	vm vm-clean vm-create vm-start vm-stop vm-restart vm-destroy \
	cluster cluster-clean cluster-kubeadm cluster-create cluster-start \
	cluster-stop cluster-restart cluster-destroy \
	mac-vm-infra mac-vm-infra-delete mac-infra mac-infra-delete \
	install-kubeadm delete-vmnet-socket \
	_run_local_mac_playbook _run_k8s_playbook

# ---------------------------------------------------------------------------
# limactl helpers
#   $(call lima_each,<instances>,<subcommand>)   start/stop/restart each instance
#   $(call lima_create,<instances>,<yaml dir>)   create each instance from <dir>/<name>.yml
#   $(call lima_delete,<instances>)              best-effort delete (skips missing ones)
# ---------------------------------------------------------------------------
lima_each = set -e; for n in $(1); do echo "[*] limactl $(2) $$n"; limactl $(2) $$n; done
lima_create = set -e; for n in $(1); do echo "[*] creating $$n from $(2)/$$n.yml"; limactl start --name $$n $(2)/$$n.yml -y; done
lima_delete = for n in $(1); do echo "[*] deleting $$n"; limactl delete $$n --force || echo "    $$n not found, skipping"; done

# ---------------------------------------------------------------------------
# Meta
# ---------------------------------------------------------------------------
help: ## show this help
	@awk -F':.*## ' '/^[a-zA-Z][a-zA-Z_-]*:.*## /{printf "  make %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: help ## same as help (this Makefile has no safe "build everything" action)

test: ## run all pre-commit hooks against the whole repo
	pre-commit run --all-files --show-diff-on-failure

clean: ## remove the Ansible venv (does NOT touch any VMs)
	rm -rf "$(VENV)"

# ---------------------------------------------------------------------------
# Single dev VM
# ---------------------------------------------------------------------------
vm: ## create mydev00 with socket_vmnet, dhcp and mock dns in /etc/hosts
	@$(MAKE) --no-print-directory mac-vm-infra
	@$(MAKE) --no-print-directory vm-create
	@$(MAKE) --no-print-directory vm-restart

vm-clean: ## delete mydev00 and its /etc/hosts entries
	@$(MAKE) --no-print-directory vm-destroy
	@$(MAKE) --no-print-directory mac-vm-infra-delete

vm-create: ## create mydev00 (192.168.105.105)
	@$(call lima_create,$(VM),single-vm)

vm-start: ## start mydev00
	@$(call lima_each,$(VM),start)

vm-stop: ## stop mydev00
	@$(call lima_each,$(VM),stop)

vm-restart: ## restart mydev00
	@$(call lima_each,$(VM),restart)

vm-destroy: ## delete mydev00 (skips it if already gone)
	@$(call lima_delete,$(VM))

mac-vm-infra: ## run playbook create_vm.yml on this Mac
	@$(MAKE) --no-print-directory _run_local_mac_playbook PLAYBOOK="$(CREATE_VM_PLAYBOOK)"

mac-vm-infra-delete: ## run playbook delete_vm.yml on this Mac
	@$(MAKE) --no-print-directory _run_local_mac_playbook PLAYBOOK="$(DELETE_VM_PLAYBOOK)"

# ---------------------------------------------------------------------------
# 3-node k8s cluster
# ---------------------------------------------------------------------------
cluster: ## socket_vmnet + dhcp, create 3 nodes, restart them onto the latest kernel
	@$(MAKE) --no-print-directory mac-infra
	@$(MAKE) --no-print-directory cluster-create
	@$(MAKE) --no-print-directory cluster-restart

cluster-kubeadm: ## make cluster, then install kubeadm on it
	@$(MAKE) --no-print-directory cluster
	@$(MAKE) --no-print-directory install-kubeadm

cluster-clean: ## delete all cluster VMs and their /etc/hosts entries
	@$(MAKE) --no-print-directory cluster-destroy
	@$(MAKE) --no-print-directory mac-infra-delete

cluster-create: ## create the 3 cluster VMs
	@$(call lima_create,$(NODES),k8snodes)

cluster-start: ## start the 3 cluster VMs
	@$(call lima_each,$(NODES),start)

cluster-stop: ## stop the 3 cluster VMs
	@$(call lima_each,$(NODES),stop)

cluster-restart: ## restart the 3 cluster VMs
	@$(call lima_each,$(NODES),restart)

cluster-destroy: ## delete the 3 cluster VMs (skips any already gone)
	@$(call lima_delete,$(NODES))

mac-infra: ## run playbook create_cluster.yml on this Mac
	@$(MAKE) --no-print-directory _run_local_mac_playbook PLAYBOOK="$(CREATE_CLUSTER_PLAYBOOK)"

mac-infra-delete: ## run playbook delete_cluster.yml on this Mac
	@$(MAKE) --no-print-directory _run_local_mac_playbook PLAYBOOK="$(DELETE_CLUSTER_PLAYBOOK)"

install-kubeadm: ## install kubeadm on the existing cluster VMs
	@$(MAKE) --no-print-directory _run_k8s_playbook PLAYBOOK="$(INSTALL_KUBEADM_PLAYBOOK)"

delete-vmnet-socket: ## remove the socket_vmnet setup (cluster and vm)
	@$(MAKE) --no-print-directory _run_local_mac_playbook PLAYBOOK="$(DELETE_VMNET_SOCKET_PLAYBOOK)"

# ---------------------------------------------------------------------------
# Ansible venv
# Rebuild the venv if its interpreter is missing/broken (e.g. pyenv/brew Python
# removed or upgraded) even when the stamp file still exists.
# ---------------------------------------------------------------------------
VENV_HEALTHY := $(shell "$(VENV)/bin/python" -c 'import ansible' >/dev/null 2>&1 && echo yes)
ifneq ($(VENV_HEALTHY),yes)
.PHONY: $(VENV_STAMP)
endif

venv: $(VENV_STAMP) ## create/repair the Ansible venv

$(VENV_STAMP): $(REQUIREMENTS)
	@command -v $(PYTHON) >/dev/null 2>&1 || { echo "ERROR: $(PYTHON) not found. Install Python 3 and retry." >&2; exit 1; }
	@echo "[*] Building Ansible venv at $(VENV)"
	@rm -rf "$(VENV)" && $(PYTHON) -m venv "$(VENV)"
	@$(VENV_PIP) --upgrade pip && $(VENV_PIP) -r "$(REQUIREMENTS)"
	@touch "$@"

# ---------------------------------------------------------------------------
# Internal playbook runners (not meant to be called directly)
# ---------------------------------------------------------------------------
_run_local_mac_playbook: ANSIBLE_ARGS = -K

_run_local_mac_playbook _run_k8s_playbook: $(VENV_STAMP)
	@test -n "$(PLAYBOOK)" || { echo "ERROR: PLAYBOOK is not set." >&2; exit 1; }
	@echo "[*] Running ansible-playbook $(PLAYBOOK)"
	@cd "$(ANSIBLE_DIR)" && PATH="$(VENV)/bin:$$PATH" ansible-playbook $(ANSIBLE_ARGS) "$(PLAYBOOK)"
