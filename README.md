# Kubernetes The Hard Way Azure

A simple platform that i used for training installing kubernetes the hard way.

### Objective
> This repo already contains a user-data script in order to make things easier and more focused. Take a look before executing the commands.


This repo's objective is to provision an environment and document my first try deploying a kubernetes cluster from scratch(the famous hard way of doing it). Resources listed here are not intended to be a production-ready cluster, but to be a learning environment instead.

It provisions:
- 3 nodes with:
  - Ubuntu 24.04 LTS;
  - Azure vm with `Standard_DS2_v2` image - 2 vCPUs and 7GiB of RAM.
- A minimal network setup with:
  - 1 vnet;
  - 1 subnet;
  - 3 network interfaces(nic) and public ips - 1 per node;
  - 1 network security group(nsg) with free access `Inbound Rules` for control-plane, ssh and nodePort services.
- An user-data script that configures:
  - Swap off;
  - `overlay` and `br_netfilter` modules;
  - `containerd`;
  - Kubernetes apt repos.

### Pre requisites

- Required terraform `>=0.13`;
- A logged azcli.

### Install

```bash
# Init providers
terraform init

# Applying infrastructure
terraform plan -out out.plan
terraform apply "out.plan"

# Getting image certificate
terraform output -raw tls_cert > azurekeypair.pem
sudo chmod 400 azurekeypair.pem

# Accessing nodes
terraform output -json public_ip_addresses
ssh -i azurekeypair.pem adminuser@<node-public-ip>
```

### Cleanup

```bash
# Destroy resources
terraform destroy --auto-approve
```

### Annotations

To know more about kubernetes deploy, read [deploy-k8s](./deploy-k8s.md).
