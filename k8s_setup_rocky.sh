#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Ensure pipeline errors are detected

# Define log file
LOG_FILE="/var/log/k8s_setup_rocky.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sysctl --system

echo -e "Edit kubelet configuration manually to set cgroupDriver to systemd:\n
1. Open the kubelet configuration file:\n
   sudo vi /var/lib/kubelet/config.yaml\n
2. Find the cgroupDriver option (or add it if missing):\n
   apiVersion: kubelet.config.k8s.io/v1beta1\n
   kind: KubeletConfiguration\n
   cgroupDriver: systemd\n
3. Save the file and restart kubelet:\n
   sudo systemctl restart kubelet"

echo "Starting Kubernetes Cluster Setup on Rocky Linux..."

# --- Step 1: Update System and Install Dependencies ---
echo "Updating system packages..."
dnf update -y

echo "Installing required dependencies..."
dnf install -y yum-utils device-mapper-persistent-data lvm2 curl

# --- Step 2: Install Containerd ---
echo "Installing Containerd..."
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y containerd.io
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- Step 3: Install Kubernetes (kubeadm, kubelet, kubectl) ---
echo "Adding Kubernetes repository..."
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/Release.key
EOF

echo "Installing Kubernetes components..."
dnf install -y kubelet kubeadm kubectl
systemctl enable kubelet

# --- Step 4: Initialize Kubernetes Master (if applicable) ---
if [[ $(hostname) == "control" ]]; then
    echo "Initializing Kubernetes control plane..."
    kubeadm init --cri-socket /run/containerd/containerd.sock --pod-network-cidr=10.10.10.0/24

    echo "Setting up kubeconfig for root user..."
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    echo "Installing Flannel CNI Plugin..."
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
fi

# --- Step 5: Join Worker Nodes ---
if [[ $(hostname) != "control" ]]; then
    echo "Fetching Kubernetes join command..."
    JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no jacomini@control "kubeadm token create --print-join-command")

    echo "Joining Kubernetes cluster..."
    $JOIN_COMMAND --cri-socket /run/containerd/containerd.sock
fi

echo "Kubernetes setup on Rocky Linux completed!"
