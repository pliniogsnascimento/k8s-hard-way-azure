#containers #kubernetes

> [!note] 
> Things to be aware of: 
> - Always look for compatibility matrix between cluster and container runtimes versions; 
> - Try to install packages whenever is possible; 
> - Be aware of security groups.

### Objective
This page's objective is to document my first try deploying a kubernetes cluster from scratch(the famous hard way of doing it).

### Pre requisites
- 2Gb of RAM
- 2CPUs
- Swap off
- Container runtime
- Network Plugin - CNI

### Cluster Info
- Azure Cloud Provider
- Kubernetes 1.26
- Containerd 1.6 - See [containerd releases](https://containerd.io/releases/) for list of kubernetes compatibility.
- Flannel CNI

#### Required ports
Required ports open on nodes:

##### Control Plane
| Protocol | Direction | Port Range | Purpose | Used By |
|-|-|-|-|-|
| TCP | Inbound | 6443 | Kubernetes API server | All |
| TCP | Inbound | 2379-2380 | etcd server client API | kube-apiserver, etcd |
| TCP | Inbound | 10250 | Kubelet API | Self, Control plane |
| TCP | Inbound | 10259 | kube-scheduler | Self |
| TCP | Inbound | 10257 | kube-controller-manager | Self |

##### Worker Nodes
| Protocol | Direction | Port Range | Purpose | Used By |
|-|-|-|-|-|
| TCP | Inbound | 10250 | Kubelet API | Self, Control plane |
| TCP | Inbound | 30000-32767 | NodePort Services | All |

#### Turn swap off
`swapoff -a`

#### Enable modules
```bash
# Validates if modules are already enabled
lsmod | grep overlay
lsmod | grep netfilter

# Enable overlay and br_netfilter modules
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo tee /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Setup required sysctl params, these persist across reboots.
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

### Install containerd
```bash
# Configure apt repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install
sudo apt update -y
sudo apt install -y containerd.io=1.6.12-1

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
```

After installed, can interact with containerd via [CLIs commands](https://github.com/containerd/containerd/blob/main/docs/getting-started.md#interacting-with-containerd-via-cli).

### Installing kubeadm, kubectl, kubelet
```bash
# Update index
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Add repo gpg key
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add

# Add kubernetes apt repo
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Install
sudo apt-get update
sudo apt-get install -y kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00
sudo apt-mark hold kubelet kubeadm kubectl
```

### Bootstrap cluster
> [!note]
> From here, run commands only on control-plane node.

```bash
# Init control-plane
kubeadm init --pod-network-cidr="10.244.0.0/16" --upload-certs --kubernetes-version="v1.26.0" --control-plane-endpoint="20.29.216.161" --cri-socket="unix:///run/containerd/containerd.sock"
```

After control-plane node started, join nodes as the `kubeadm` suggests with `kubeadm join` command.

```bash
# Install CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```