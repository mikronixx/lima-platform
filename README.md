# Lima Platform (Apple Silicon VM Automation)

Lima configurations that run Linux VMs on macOS (Apple Silicon). A starting point for Platform/SRE workflows and future Kubernetes clusters.

> **Tested on:** Apple M3 Pro (12 cores, 36 GB RAM)

## Why Lima?

For engineers who want real Linux/K8s on a Mac.

- **VMs without the bloat** on macOS, without full hypervisor UX
- **Scriptable + reproducible** VM creation
- **K8s-ready** foundation supporting multiple VMs, custom networks, and cloud-init for authentication/authorization setup

## Requirements

- macOS 14+
- Apple Silicon
- Homebrew
- Lima ≥ 1.2.x
- Python ≥ 3.9.6
- socket_vmnet

## Setup

Install Lima with Homebrew

```bash
brew install lima
limactl -v  # verify
```

Clone this repo:

```bash
git clone git@github.com:mikronixx/lima-platform.git
# or
git clone https://github.com/mikronixx/lima-platform.git
```

### Installing socket_vmnet for network management

```bash
# If you are creating a single vm or a k8s cluster with the make commands below there is to need to run this step.
# Included for informational purposes
# make help for a full list of options
cd lima-platform/
make socket_vmnet_install 
```

## Create a single VM
Creates a fully configured VM using Lima with networking, hostname setup, and package updates.
```bash
# make help for a full list of options
cd lima-platform/
make vm  # Installs socket_vmnet, adds vm hostname to /etc/hosts, adds a MAC address to bootptab for DHCP,  creates a single vm, updates packages and reboots
```

## Start, Stop, or Restart your VM
Basic lifecycle operations for the VM created above.
```bash
# make help for a full list of options
cd lima-platform/
make vm-start
make vm-stop
make vm-restart
```

## Create a 3 node cluster, but no k8s
Creates 3 fully configured VMs using Lima with networking, hostname setup, and package updates. 
```bash
# make help for a full list of options
cd lima-platform/
make cluster # Installs socket_vmnet, adds hostnames to /etc/hosts, adds a bootptab file for DHCP,  creates a 3 node cluster, updates packages and reboots
```

## Create a 3 node kubeadm managed Kubernetes cluster
Creates a 3 node Kubernetes cluster using Lima with networking, hostname setup, and package updates. 
```bash
# make help for a full list of options
cd lima-platform/
make cluster-kube # Installs socket_vmnet, adds hostnames to /etc/hosts, adds a bootptab file for DHCP,  creates a 3 node cluster, updates packages, reboots, and installs Kubernetes with kubeadm
ssh k8sc000 # Welcome to your cluster!
watch "kubectl get pod -A" # it takes about 8 min for your cluster to be ready
```

## Start, Stop, or Restart your cluster
Basic lifecycle operations for the cluster created above.
```bash
# make help for a full list of options
cd lima-platform/
make cluster-start
make cluster-stop
make cluster-restart
```
## Using the poc code, if you must

```bash
# Run from repo root, or adjust path as needed

limactl create --name vm-dhcp-bootp ./poc/vm-dhcp-bootp.yml -y
# Remove -y if you want to edit the configuration interactively
limactl start vm-dhcp-bootp
limactl shell vm-dhcp-bootp
```

## Stop or delete a VM with limactl

```bash
# Examples
limactl stop vm-dhcp-bootp
limactl delete vm-dhcp-bootp
limactl delete vm-dhcp-bootp --force
```

## Roadmap

- Simplify current Makefile target rules
- UTM compatibility/ co-existance
- Makefile refactor to remove redundant code
- Ansible refactor to include limactl commands to build VMs and Kubernetes clusters

## References

- [Lima documentation](https://github.com/lima-vm/lima)
- [Lima configuration YAML example](https://github.com/lima-vm/lima/blob/master/templates/default.yaml)
- [socket_vmnet (network helper)](https://github.com/lima-vm/socket_vmnet)
- [Ubuntu Cloud Images (ARM64)](https://cloud-images.ubuntu.com/)
