# Installing k8s the hard way
> Upgraded to version 1.31 according to [cncf curriculum](https://github.com/cncf/curriculum). 
<br/>Follow the instructions at [kubeadm docs](https://v1-31.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

Things to be aware of: 
- Always look for compatibility matrix between cluster and container runtimes versions; 
- Try to install packages whenever is possible; 
- Be aware of security groups.

### Pre requisites
- 2Gb of RAM
- 2CPUs
- Swap off
- Container runtime
- Network Plugin - CNI

### Cluster Info
- Azure Cloud Provider
- Kubernetes 1.31
- Containerd 2.0 - See [containerd releases](https://containerd.io/releases/#kubernetes-support) for list of kubernetes compatibility.
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


### Installing Container Runtime(CRI)
```bash
# Install containerd as https://github.com/containerd/containerd/blob/main/docs/getting-started.md explains
wget https://github.com/containerd/containerd/releases/download/v2.0.1/containerd-2.0.1-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-2.0.1-linux-amd64.tar.gz
mkdir -p /usr/local/lib/systemd/system/
curl https://raw.githubusercontent.com/containerd/containerd/main/containerd.service | tee /usr/local/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

# Install runc
wget https://github.com/opencontainers/runc/releases/download/v1.2.3/runc.amd64
install -m 775 runc.amd64 /usr/local/sbin/runc

# Install CNI Plugins(Optional)
wget https://github.com/containernetworking/plugins/releases/download/v1.6.1/cni-plugins-linux-amd64-v1.6.1.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin/ cni-plugins-linux-amd64-v1.6.1.tgz
```

### Installing kubeadm, kubectl, kubelet
```bash
# Search available versions
sudo apt-cache madison kubelet

# Install
sudo apt-get update
sudo apt-get install -y kubelet=<version> kubeadm=<version> kubectl=<version>
sudo apt-mark hold kubelet kubeadm kubectl
```

### Bootstrap cluster

> From here, run commands only on control-plane node.

```bash
# Init control-plane
kubeadm init --pod-network-cidr="10.244.0.0/16" --upload-certs --kubernetes-version="<version>" --control-plane-endpoint="20.29.216.161" --cri-socket="unix:///run/containerd/containerd.sock"
```

After control-plane node started, join nodes as the `kubeadm` suggests with `kubeadm join` command.

```bash
# Install CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```