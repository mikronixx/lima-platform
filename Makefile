# Makefile: manages socket_vmnet, bootp, k8s clusters

.DEFAULT_GOAL := help
NODES := k8scp000 k8sw000 k8sw001
VM := mydev00
ANSIBLE_DIR := ansible
PYTHON      := python3
CREATE_CLUSTER_PLAYBOOK := playbooks/create_cluster.yml
DELETE_CLUSTER_PLAYBOOK := playbooks/delete_cluster.yml
CREATE_VM_PLAYBOOK := playbooks/create_vm.yml
DELETE_VM_PLAYBOOK := playbooks/delete_vm.yml
INSTALL_KUBEADM_PLAYBOOK := playbooks/create_kubeadm.yml

# Virtual environments possible enhancement
#VENV_MAC   := venv-mac
#VENV_LINUX := venv-linux


.PHONY: help 

help:
	@echo "Targets:"
	@echo "  make mac-vm-infra # runs $(CREATE_VM_PLAYBOOK)"
	@echo "  make mac-vm-infra-delete # runs $(DELETE_VM_PLAYBOOK)"
	@echo "  make mac-infra # runs $(CREATE_CLUSTER_PLAYBOOK)" 
	@echo "  make mac-infra-delete # runs $(DELETE_CLUSTER_PLAYBOOK)" 
	@echo "  make cluster-restart # restarts a 3 node cluster"
	@echo "  make cluster-start # starts an existing 3 node cluster"
	@echo "  make cluster-stop # stops an existing 3 node cluster"
	@echo "  make cluster-create  # provisions a 3 node cluster"
	@echo "  make install-kubeadm # creates a 3 node kubernetes cluster with kubeadm"
	@echo "  make cluster  # provisions a 3 node cluster, including socket_vmnet, a dhcp configuration for the VM's and a restart to update to latest kernel"
	@echo "  make cluster-kube # provisions a 3 node cluster with kubeadm"
	@echo "  make cluster-destroy # deletes all VM's provisioned for a k8s cluster"
	@echo "  make cluster-clean # deletes /etc/hosts  entries, all VM's provisioned for a k8s cluster"
	@echo "  make vm-clean # deletes /etc/hosts  entries, all VM's provisioned outside of a k8s cluster"
	@echo "  make vm-create # creates a single VM, IP addr 192.168.105.105, hostname mydev00"
	@echo "  make vm-start # starts single vm mydev00"
	@echo "  make vm-restart # restarts single vm mydev00"
	@echo "  make vm # creates a single vm, including socket_vmnet, a dhcp configuration for the a single VM, and mock dns in /etc/hosts"

vm: mac-vm-infra vm-create vm-restart

vm-clean:  vm-destroy mac-vm-infra-delete 

cluster: mac-infra cluster-create cluster-restart 

cluster-clean:
	$(MAKE) cluster-destroy
	$(MAKE) mac-infra-delete

cluster-kubeadm: cluster install-kubeadm

mac-vm-infra:
	@$(MAKE) _run_local_mac_playbook CWD=$(ANSIBLE_DIR) PLAYBOOK="$(CREATE_VM_PLAYBOOK)"

mac-vm-infra-delete:
	@$(MAKE) _run_local_mac_playbook CWD=$(ANSIBLE_DIR) PLAYBOOK="$(DELETE_CLUSTER_PLAYBOOK)"

mac-infra:
	@$(MAKE) _run_local_mac_playbook CWD=$(ANSIBLE_DIR) PLAYBOOK="$(CREATE_CLUSTER_PLAYBOOK)"

mac-infra-delete:
	@$(MAKE) _run_local_mac_playbook CWD=$(ANSIBLE_DIR) PLAYBOOK="$(DELETE_CLUSTER_PLAYBOOK)"

install-kubeadm:
	@$(MAKE) run_k8s_playbook CWD=$(ANSIBLE_DIR) PLAYBOOK="$(INSTALL_KUBEADM_PLAYBOOK) -i $(INVENTORY_FILE)"

vm-create:
	@set -e; \
	for n in $(VM); do \
		echo "Starting $$n..."; \
		limactl start --name $$n single-vm/$$n.yml -y; \
	done

vm-start:
	@set -e; \
	for n in $(VM); do \
		echo "Starting $$n..."; \
		limactl start $$n; \
	done

vm-restart:
	@set -e; \
	for n in $(VM); do \
		echo "Restarting $$n..."; \
		limactl restart $$n; \
	done

vm-stop:
	@set -e; \
	for n in $(VM); do \
		echo "Stopping $$n..."; \
		limactl stop $$n; \
	done

vm-destroy:
	@set -e; \
	for n in $(VM); do \
		echo "deleting $$n..."; \
		limactl delete $$n --force; \
		echo "exit: $?"; \
	done
	


cluster-create:
	@set -e; \
	for n in $(NODES); do \
		echo "Starting $$n..."; \
		limactl start --name $$n k8snodes/$$n.yml -y; \
	done

cluster-start:
	@set -e; \
	for n in $(NODES); do \
		echo "Starting $$n..."; \
		limactl start $$n; \
	done

cluster-restart:
	@set -e; \
	for n in $(NODES); do \
		echo "Restarting $$n..."; \
		limactl restart $$n; \
	done

cluster-stop:
	@set -e; \
	for n in $(NODES); do \
		echo "Stopping $$n..."; \
		limactl stop $$n; \
	done

cluster-destroy:
	@set -e; \
	for n in $(NODES); do \
		echo "deleting $$n..."; \
		limactl delete $$n --force; \
	done

	

bootp-install:
	@cd $(ANSIBLE_DIR) && $(MAKE) _run_local_mac_playbook PLAYBOOK="$(CREATE_BOOTP_PLAYBOOK)"

bootp-delete:
	@cd $(ANSIBLE_DIR) && $(MAKE) _run_local_mac_playbook PLAYBOOK="$(DELETE_BOOTP_PLAYBOOK)"

_run_local_mac_playbook:
	@cd $(CWD) && \
	set -euo pipefail; \
	if ! command -v $(PYTHON) >/dev/null 2>&1; then \
	  echo "ERROR: $(PYTHON) not found. Install Python 3 and retry." >&2; exit 1; \
	fi; \
	VENV_DIR=$$(mktemp -d -t ansible-venv-XXXXXX); \
	trap 'rm -rf "$$VENV_DIR"' EXIT INT TERM; \
	echo "[*] Creating venv at $$VENV_DIR"; \
	$(PYTHON) -m venv "$$VENV_DIR"; \
	. "$$VENV_DIR/bin/activate"; \
	echo "[*] Upgrading pip and installing ansible..."; \
	python -m pip install --upgrade pip >/dev/null; \
	pip install --quiet ansible >/dev/null; \
	echo "[*] Running ansible-playbook $(PLAYBOOK)"; \
	ansible-playbook -K $(PLAYBOOK); \
	pip cache purge >/dev/null 2>&1 || true; \
	rm -rf $$VENV_DIR; \
	find $$HOME/Library/Caches/com.apple.python/private/var/folders -type d -iname "ansible-venv-XXXXXX.*" -exec rm -rf {} + >/dev/null 2>&1 || true

run_k8s_playbook:
	@cd $(CWD) && \
	set -euo pipefail; \
	if ! command -v $(PYTHON) >/dev/null 2>&1; then \
	  echo "ERROR: $(PYTHON) not found. Install Python 3 and retry." >&2; exit 1; \
	fi; \
	VENV_DIR=$$(mktemp -d -t ansible-venv-XXXXXX); \
	trap 'rm -rf "$$VENV_DIR"' EXIT INT TERM; \
	echo "[*] Creating venv at $$VENV_DIR"; \
	$(PYTHON) -m venv "$$VENV_DIR"; \
	. "$$VENV_DIR/bin/activate"; \
	echo "[*] Upgrading pip and installing ansible..."; \
	python -m pip install --upgrade pip >/dev/null; \
	pip install --quiet ansible >/dev/null; \
	echo "[*] Running ansible-playbook $(PLAYBOOK)"; \
	ansible-playbook $(PLAYBOOK); \
	pip cache purge >/dev/null 2>&1 || true; \
	rm -rf $$VENV_DIR; \
	find $$HOME/Library/Caches/com.apple.python/private/var/folders -type d -iname "ansible-venv-XXXXXX.*" -exec rm -rf {} + >/dev/null 2>&1 || true