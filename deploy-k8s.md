# Installing k8s the hard way
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


### Installing kubeadm, kubectl, kubelet
```bash
# Install
sudo apt-get update
sudo apt-get install -y kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00
sudo apt-mark hold kubelet kubeadm kubectl
```

### Bootstrap cluster

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