# Lima Platform (Apple Silicon VM Automation)

Lima configurations that run Linux VMs on macOS (Apple Silicon). A starting point for Platform/SRE workflows and future Kubernetes clusters.

> **Tested on:** Apple M3 Pro (12 cores, 36 GB RAM)

## Why Lima?

- **VMs without the bloat** on macOS, without full hypervisor UX
- **Scriptable + reproducible** VM creation
- **K8s-ready** foundation (multi-VM, custom networks, cloud-init)

## Requirements

- macOS 14+
- Apple Silicon
- Homebrew
- Lima ≥ 1.2.x
- Python ≥ 3.9.6
- socket_vmnet

## Setup

install Lima with Homebrew

```bash
brew install lima
limactl -v  # verify
```

Clone this repo:

```bash
git clone https://github.com/mkrohn-repo/lima-platform.git
#or
git clone git@github.com:mkrohn-repo/lima-platform.git
```

### Installing socket_vmnet for network management

```bash
# if you are creating a k8s cluster there is to need to run this step.
# It is only needed if you are running a single vm 
# make help for a full list of options
cd lima-platform/
make socket_vmnet_install 
```

## Create a 3 node cluster, but no k8s

```bash
# make help for a full list of options
cd lima-platform/
make cluster #Installs socket_vmnet, adds hostnames to /etc/hosts, add a bootptab file for dhcp,  creates a 3 node cluster, updates packages and reboots
```

## Create a 3 node kubeadm managed kubernetes cluster

```bash
# make help for a full list of options
cd lima-platform/
make cluster-kube # Installs socket_vmnet, adds hostnames to /etc/hosts, add a bootptab file for dhcp,  creates a 3 node cluster, updates packages, reboots and installs kubernetes with kubeadm
ssh k8sc000 # Welcome to your cluster!
watch "kubectl get pod -A" # it takes about 8 min for you cluster to be ready
```

## Start, Stop, or Restart your cluster

```bash
# make help for a full list of options
cd lima-platform/
make cluster-start
make cluster-stop
make cluster-restart
```

## Use your new Kubernetes cluster

## Spin up a VM

```bash
#run from repo root, or adjust path as needed

limactl create --name vm-dhcp-bootp ./poc/vm-dhcp-bootp.yml -y
# remove -y if you want to edit the configuration interactively
limactl start vm-dhcp-bootp
limactl shell vm-dhcp-bootp
```

## Stop or delete a VM

```bash
limactl stop vm-dhcp-bootp
limactl delete vm-dhcp-bootp
limactl delete vm-dhcp-bootp --force
```

## Roadmap

- Simplify current Makefile target rules
- UTM Compatibility/Co-existance
- Ansible refactor

## References

- [Lima documentation](https://github.com/lima-vm/lima)
- [Lima configuration YAML example ](https://github.com/lima-vm/lima/blob/master/templates/default.yaml)
- [socket_vmnet (network helper)](https://github.com/lima-vm/socket_vmnet)
- [Ubuntu Cloud Images (ARM64)](https://cloud-images.ubuntu.com/)

