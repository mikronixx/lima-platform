# Makefile: manages socket_vmnet, bootp, k8s clusters

.DEFAULT_GOAL := help
NODES := k8scp000 k8sw000 k8sw001
VM := mydev00
PYTHON ?= python3
INSTALL_SOCKET_VMNET_PLAYBOOK := ansible/install_socket_vmnet.yml
REMOVE_SOCKET_VMNET_PLAYBOOK := ansible/remove_socket_vmnet.yml
INVENTORY_FILE ?= ansible/inventory.ini
ANSIBLE_HOST_KEY_CHECKING ?= False
ANSIBLE_SSH_ARGS ?= -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
CREATE_BOOTP_PLAYBOOK := ansible/create_bootp.yml
DELETE_BOOTP_PLAYBOOK := ansible/delete_bootp.yml
#cluster make vars
CREATE_FAKEDNS_PLAYBOOK := ansible/create_bootp_fakedns.yml
DELETE_FAKEDNS_PLAYBOOK := ansible/remove_bootp_fakedns.yml
INSTALL_K8S:= ansible/create_kubeadm_cluster.yml
#VM make vars
CREATE_VM_FAKEDNS_PLAYBOOK := ansible/create_vm_bootp_fakedns.yml
DELETE_VM_FAKEDNS_PLAYBOOK := ansible/remove_vm_bootp_fakedns.yml

.PHONY: help 

help:
	@echo "Targets:"
	@echo "  make mac-vm-infra # runs $(CREATE_VM_FAKEDNS_PLAYBOOK) $(CREATE_BOOTP_PLAYBOOK) and $(INSTALL_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make mac-vm-infra-delete # runs $(DELETE_VM_FAKEDNS_PLAYBOOK)  and $(REMOVE_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make mac-infra # runs $(CREATE_FAKEDNS_PLAYBOOK) $(CREATE_BOOTP_PLAYBOOK) and $(INSTALL_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make mac-infra-delete # runs $(DELETE_FAKEDNS_PLAYBOOK)  and $(REMOVE_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make fakedns-install   # runs $(CREATE_FAKEDNS_PLAYBOOK) in a fresh venv"
	@echo "  make fakedns-delete    # runs $(DELETE_FAKEDNS_PLAYBOOK) in a fresh venv"
	@echo "  make bootp-install   # runs $(CREATE_BOOTP_PLAYBOOK) in a fresh venv"
	@echo "  make bootp-delete    # runs $(DELETE_BOOTP_PLAYBOOK) in a fresh venv"
	@echo "  make socket_vmnet_install    # runs $(INSTALL_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make socket_vmnet_remove    # runs $(REMOVE_SOCKET_VMNET_PLAYBOOK) in a fresh venv"
	@echo "  make cluster-restart # restarts a 3 node cluster"
	@echo "  make cluster-start # starts an existing 3 node cluster"
	@echo "  make cluster-stop # stops an existing 3 node cluster"
	@echo "  make cluster-create  # provisions a 3 node cluster"
	@echo "  make install-k8s # creates a 3 node kubernetes cluster with kubeadm"
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

mac-vm-infra:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(CREATE_VM_FAKEDNS_PLAYBOOK) $(CREATE_BOOTP_PLAYBOOK) $(INSTALL_SOCKET_VMNET_PLAYBOOK)"

mac-vm-infra-delete:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(DELETE_VM_FAKEDNS_PLAYBOOK)" 

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

cluster: mac-infra cluster-create cluster-restart 

cluster-kube: cluster install-k8s

cluster-clean:  cluster-destroy mac-infra-delete 

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

mac-infra:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(CREATE_FAKEDNS_PLAYBOOK) $(CREATE_BOOTP_PLAYBOOK) $(INSTALL_SOCKET_VMNET_PLAYBOOK)"

mac-infra-delete:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(DELETE_FAKEDNS_PLAYBOOK) 

fakedns-install:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(CREATE_FAKEDNS_PLAYBOOK)"

fakedns-delete:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(DELETE_FAKEDNS_PLAYBOOK)"

bootp-install:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(CREATE_BOOTP_PLAYBOOK)"

bootp-delete:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(DELETE_BOOTP_PLAYBOOK)"

socket_vmnet_install:
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(INSTALL_SOCKET_VMNET_PLAYBOOK)"

socket_vmnet_remove:	
	@$(MAKE) _run_local_mac_playbook PLAYBOOK="$(REMOVE_SOCKET_VMNET_PLAYBOOK)"

install-k8s: 
	@$(MAKE) _run_k8s_playbook PLAYBOOK="$(INSTALL_K8S) -i $(INVENTORY_FILE)"

_run_local_mac_playbook:
	@set -euo pipefail; \
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
	echo "[*] Running ansible-playbook -K $(PLAYBOOK)"; \
	ansible-playbook -K $(PLAYBOOK); \
	pip cache purge >/dev/null 2>&1 || true; \
	rm -rf $$VENV_DIR; \
	find $$HOME/Library/Caches/com.apple.python/private/var/folders -type d -iname "ansible-venv-XXXXXX.*"  -exec rm -rf {} + >/dev/null 2>&1 || true

_run_k8s_playbook:
	@set -euo pipefail; \
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
	ansible-playbook  $(PLAYBOOK); \
	pip cache purge >/dev/null 2>&1 || true; \
	rm -rf $$VENV_DIR; \
	find $$HOME/Library/Caches/com.apple.python/private/var/folders -type d -iname "ansible-venv-XXXXXX.*"  -exec rm -rf {} + >/dev/null 2>&1 || true