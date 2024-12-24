resource "azurerm_resource_group" "k8s_hard_way" {
  name     = "k8s-hard-way"
  location = "West US 2"
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_virtual_network" "k8s_hard_way" {
  name                = "k8s-vn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.k8s_hard_way.location
  resource_group_name = azurerm_resource_group.k8s_hard_way.name
}

resource "azurerm_subnet" "k8s_hard_way" {
  name                 = "k8s-sub"
  resource_group_name  = azurerm_resource_group.k8s_hard_way.name
  virtual_network_name = azurerm_virtual_network.k8s_hard_way.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "k8s_hard_way_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = azurerm_resource_group.k8s_hard_way.location
  resource_group_name = azurerm_resource_group.k8s_hard_way.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "kube-apiserver"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "nodePortServices"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  count                     = 3
  network_interface_id      = element(azurerm_network_interface.test.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.k8s_hard_way_nsg.id
}

resource "azurerm_public_ip" "test" {
  count = 3

  name                = "publicIP-${count.index}"
  location            = azurerm_resource_group.k8s_hard_way.location
  resource_group_name = azurerm_resource_group.k8s_hard_way.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "test" {
  count               = 3
  name                = "k8s-ni${count.index}"
  location            = azurerm_resource_group.k8s_hard_way.location
  resource_group_name = azurerm_resource_group.k8s_hard_way.name

  ip_configuration {
    name                          = "k8s-hard-way"
    subnet_id                     = azurerm_subnet.k8s_hard_way.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = element(azurerm_public_ip.test.*.id, count.index)
  }
}

resource "azurerm_linux_virtual_machine" "test" {
  count                 = 3
  name                  = "darlene-${count.index}"
  location              = azurerm_resource_group.k8s_hard_way.location
  resource_group_name   = azurerm_resource_group.k8s_hard_way.name
  network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
  size                  = "Standard_DS2_v2"
  admin_username        = "adminuser"

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }


  user_data = base64encode(<<EOC
#!/bin/bash
# Turn swap off
swapoff -a

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

# Configure containerd.io apt repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install
sudo apt update -y
sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Configure containerd to use systemd as cgroup driver
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Update index
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Add repo gpg key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add kubernetes apt repo
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm kubectl and kubelet
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

EOC
  )

  tags = {
    environment = "staging"
  }
}
