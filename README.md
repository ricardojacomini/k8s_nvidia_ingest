# Kubernetes Cluster Setup with GPU Support

This repository is a playbook that sets up a Kubernetes cluster in Slurm Reservation to evaluate NVIDIA-Ingest with GPU support on the master and worker nodes. It ensures that the GPU worker node is configured correctly to handle GPU workloads, including running NVIDIA Ingest (NV-Ingest) and NeMo Retriever Extraction.

The playbook is divided into three main sections:
1. **Install and Configure Containerd with NVIDIA Support**: Installs Containerd, configures it for Kubernetes, and adds NVIDIA runtime if a GPU is detected.
2. **Initialize Kubernetes Control Plane**: Initializes the Kubernetes cluster on the master node.
3. **Join Worker Nodes to Cluster**: Joins the worker nodes to the cluster and labels the GPU node.

Additionally, this setup includes the deployment of NV-Ingest using Helm for GPU-accelerated workloads.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Cluster Setup](#cluster-setup)
3. [GPU Worker Configuration](#gpu-worker-configuration)
4. [Deploy NVIDIA Device Plugin](#deploy-nvidia-device-plugin)
5. [Test GPU Workloads](#test-gpu-workloads)
6. [Deploy NV-Ingest](#deploy-nv-ingest)
7. [Cleanup](#cleanup)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before running the playbook, ensure the following:

- **Master Node**: Properly initialized (`kubectl get nodes` should show the master node as `Ready`).
- **Worker Nodes**: Correctly join the cluster.
- **GPU Worker**: The GPU worker node (`icgpu10`) must have:
    - NVIDIA GPU with drivers installed.
    - NVIDIA Container Toolkit configured.
    - Containerd configured for Kubernetes.
- **NVIDIA NGC API Key**: Required for pulling NVIDIA Docker images and deploying NV-Ingest. Generate it from the [NVIDIA NGC website](https://ngc.nvidia.com/setup/api-key).
- **Ansible**: Installed on the machine running the playbook.
- **SSH Access**: Ensure SSH access to all nodes with the provided SSH key (`/etc/kubernetes/key`).

---

## Cluster Setup

### 1. **Install and Configure Containerd with NVIDIA Support**
- This step installs and configures Containerd as the container runtime on all nodes.
- If a GPU is detected on `icgpu10`, it configures Containerd to use the NVIDIA runtime for GPU workloads.

### 2. **Initialize Kubernetes Control Plane**
- Initializes the Kubernetes cluster on the master node (`c267`) using `kubeadm init`.
- Sets up `kubeconfig` for the user and deploys the Flannel CNI plugin for networking.

### 3. **Join Worker Nodes to Cluster**
- Joins worker nodes (`c276` and `icgpu10`) to the cluster using `kubeadm join`.
- Labels the GPU node (`icgpu10`) with `gpu=true` to enable GPU scheduling.

---

## GPU Worker Configuration

The GPU worker node (`icgpu10`) is automatically configured to:
- Use the NVIDIA runtime for GPU workloads.
- Be labeled with `gpu=true` for GPU scheduling.

---

## Deploy NVIDIA Device Plugin

The NVIDIA Device Plugin is deployed on the master node to enable GPU resource management in Kubernetes. This allows Kubernetes to schedule GPU workloads on the GPU worker node.

---

## Test GPU Workloads

To verify that the GPU worker node is properly configured, you can deploy a test pod that runs `nvidia-smi`.

### Steps:
1. Apply the GPU test pod:
   ```bash
   kubectl apply -f gpu-test.yaml
   ```
2. Check the status of the pod:
   ```bash
   kubectl get pods -n gpu-test
   ```
3. Verify GPU usage:
   ```bash
   kubectl logs -f <gpu-test-pod-name> -n gpu-test
   ```
4. Check the logs to see the output of nvidia-smi:
   ```bash
   kubectl logs gpu-test
   ```
5. Clean up the test pod:
   ```bash
   kubectl delete pod gpu-test
   ```

## Cleanup

To clean up the Kubernetes cluster and remove all resources:

1. Delete the NV-Ingest deployment:
   ```bash
   helm uninstall nv-ingest -n nv-ingest
   kubectl delete namespace nv-ingest
   ```
2. Delete the GPU test pod (if still running):
   ```bash
   kubectl delete pod gpu-test
   ```
3. Reset the Kubernetes cluster (on the master node):
   ```bash
   kubeadm reset
   ```
4. Remove Containerd and Kubernetes components from all nodes.
5. Remove the NVIDIA Container Toolkit and drivers from the GPU worker node.

## Troubleshooting

1. **GPU Not Detected**
    * Ensure the NVIDIA drivers and Container Toolkit are installed on the GPU worker node.
    * Verify that the NVIDIA runtime is configured in `/etc/containerd/config.toml`.

2. **Pods Not Scheduling on GPU Node**
    * Check that the GPU node is labeled correctly:
   ```bash
   kubectl get nodes --show-labels
   ```
3. **Ensure the NVIDIA Device Plugin is running:**
   ```bash
   kubectl get pods -n kube-system | grep nvidia
   kubectl get pods -A | grep nvidia
   ```
4. **NV-Ingest Deployment Fails**
    * Verify that the NVIDIA NGC API key is correct and has the necessary permissions.
    * Check the logs of the NV-Ingest pods for errors:
   ```bash
   kubectl get pods -n nv-ingest
   kubectl logs -n nv-ingest <pod-name>
   ```
5. **Network Issues**
    * Ensure the Flannel CNI plugin is deployed and running:
   ```bash
   kubectl get pods -n kube-system | grep flannel
   kubectl get pods -A | grep flannel
   ```

6. **General Kubernetes Issues**
    * Check the status of all nodes:
   ```bash
    kubectl get nodes
    ```
     * Check the status of all pods:
    ```bash
    kubectl get pods --all-namespaces
    ```
    * Check the logs of the Kubernetes components:
    ```bash
    journalctl -u kubelet
    ```
    * Check the logs of the master node:
    ```bash
    journalctl -u kube-apiserver
    ```
    * Check the logs of the worker node:
    ```bash
     journalctl -u kubelet
    ``` 
    * Check the logs of the Flannel CNI plugin:
    ```bash
    kubectl logs -n kube-system <flannel-pod-name>
    ```
    * Check the logs of the NVIDIA Device Plugin:
    ```bash
    kubectl logs -n kube-system <nvidia-device-plugin-pod-name>
    ```
    * Check the logs of the NV-Ingest pods:
    ```bash
    kubectl logs -n nv-ingest <nv-ingest-pod-name>
    ```
    * Check the logs of the GPU test pod:
    ```bash
    kubectl logs -n gpu-test <gpu-test-pod-name>
    ```
    * Check the logs of the GPU worker node:
    ```bash
    journalctl -u kubelet
    ```
    * Check the logs of the master node:
    ```bash
    journalctl -u kube-apiserver
    ```
   