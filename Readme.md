# ⚡ Serverless Energy Efficiency Project: Runc vs. Kata (QEMU)

## 📖 Project Overview
This project aims to evaluate the energy impact and performance trade-offs of two virtualization approaches for Serverless (FaaS) platforms. We compare:

1.  **Native Containers (Cluster 1 - Baseline):** OS-level virtualization using `runc`. Low overhead, shared kernel isolation.
2.  **Micro-VMs (Cluster 2 - Secure):** Hardware-level virtualization using **Kata Containers (QEMU)**. Strong isolation, higher overhead.

The objective is to measure the trade-off between **Security** (Isolation) and **Energy Efficiency** (CPU/RAM/Watts) in a Kubernetes + Apache OpenWhisk environment.

## 🏗 Cluster Architectures

The project relies on two distinct Kubernetes clusters with identical hardware specifications to ensure metric validity.

### 🟢 Cluster 1: Baseline (Standard)
* **Runtime:** `runc` (Standard Docker)
* **Isolation:** Namespaces & Cgroups (Shared Host Kernel)
* **Use Case:** Maximum performance, standard security.
* **Architecture:**
<p align="center">
  <img src="./docs/archi_cluster_1.png" alt="Cluster 1 Architecture - runc based isolation" width="700">
</p>

### 🟠 Cluster 2: Secure (Experimental)
* **Runtime:** `Kata Containers` (v3.x Static Binaries)
* **Hypervisor:** **QEMU** (Optimized for performance)
* **Isolation:** Full Virtual Machine with a dedicated kernel.
* **Use Case:** Strict Multi-tenancy, Maximum Security ("Hard Multi-tenancy").
<p align="center">
  <img src="./docs/architecture_cluster2_kata_qemu.png" alt="Cluster 2 Architecture - Kata Containers with QEMU" width="700">
</p>

#### Cluster 2 Hardware Setup
The secure cluster consists of **5 Nodes** running Ubuntu 20.04.01 LTS.

| Role       | Hostname            | IP Address      | OS           |
|------------|---------------------|-----------------|--------------|
| **Master** | `cluster2-master`   | `192.168.27.16` | Ubuntu 20.04 |
| **Worker** | `cluster2-worker-1` | `192.168.27.17` | Ubuntu 20.04 |
| **Worker** | `cluster2-worker-2` | `192.168.27.18` | Ubuntu 20.04 |
| **Worker** | `cluster2-worker-3` | `192.168.27.19` | Ubuntu 20.04 |
| **Worker** | `cluster2-worker-4` | `192.168.27.20` | Ubuntu 20.04 |

---

## ⚙️ Technical Prerequisites
* **OS:** Ubuntu 20.04 LTS (Kernel 5.4+).
* **Orchestrator:** Kubernetes v1.28 (via Kubeadm).
* **FaaS Framework:** Apache OpenWhisk (deployed via Helm).
* **CRI:** Containerd (with CRI plugin configuration).
* **Hardware:** Nested Virtualization (VT-x / AMD-V) must be enabled on Workers to support QEMU.

---

## 🚀 Installation & Configuration (Cluster 2)

### 1. Base Setup & Dependencies
Install Kubernetes dependencies, disable swap, and configure system settings.
```bash
# Run on MASTER and ALL WORKERS
bash 01_all_nodes_common.sh

```

### 2. Kata Containers + QEMU Setup

We use **static binaries** for Kata Containers to avoid GLIBC version conflicts with the host OS.

```bash
# Run on MASTER and ALL WORKERS
bash 01_all_nodes_kata_qemu.sh

```

*Note: This script downloads Kata Static v2.5.2/3.x, configures QEMU, and updates `/etc/containerd/config.toml` to register the `kata-qemu` runtime.*

### 3. Initialize Master Node

Initialize the control plane and install the Flannel network plugin.

```bash
# Run on MASTER only
bash 02_master_init.sh

```

### 4. Join Worker Nodes

Connect the workers to the master using the token generated in the previous step.

```bash
# Run on WORKER nodes
bash 03_workers_join.sh <PASTE_KUBEADM_JOIN_COMMAND>

```

### 5. OpenWhisk Deployment

Deploy Apache OpenWhisk via Helm, configure Persistent Volumes, and set Invoker timeouts.

```bash
# Run on MASTER only
bash 05_master_openwhisk.sh

```

### 6. Enforcing Kata (QEMU) via Webhook

To ensure OpenWhisk actions run inside QEMU VMs automatically, we deploy a **Mutating Admission Webhook**. This injects `runtimeClassName: kata-qemu` into every action pod.

```bash
# Run on MASTER only
bash 06_mater_kata_webhook.sh

```

---

## 🧪 Testing Protocol

### 1. Deploy Test Function

We use a simple function to validate the execution environment.

```javascript
// hello.js
function main(params) {
    return { payload: "Hello from inside a QEMU VM! 🚀" };
}

```

Deploy using the script:

```bash
bash 07_master_wsk_test.sh

```

### 2. Verify Isolation (The "Smoking Gun")

To prove the function is running inside a VM (and not on the host), check the kernel version from *inside* the function.

```bash
# Host Kernel Check
uname -r

# Pod Kernel Check (Should be different, e.g., 5.19 vs 5.4)
kubectl exec -it -n openwhisk <pod-name> -- uname -r

```

Alternatively, check for the QEMU hypervisor process on the worker node:

```bash
ps aux | grep qemu-system-x86_64

```

---

## 📊 Monitored Metrics

The comparative study focuses on the following metrics:

1. **Cold Start Latency:** Time required to boot the VM + Container vs. Container only.
2. **Resource Usage (CPU/RAM):** The overhead introduced by QEMU per function.
3. **Energy (Watts):** Measured via `scaphandre` or RAPL at the physical node level.

---

## 🛠 Common Troubleshooting

* **Error "GLIBC not found":** Ensure you are using the *static* version of Kata Containers binaries.
* **Pods "NotReady" / Kubelet Crash:** Check disk space (`df -h`) and ensure Swap is disabled (`swapoff -a`).
* **Connection Refused (Wsk):** Verify that the Nginx service is `Running` and accessible via the configured NodePort.
* **RuntimeClass Not Found:** Ensure `containerd` was restarted after editing `config.toml`.

---

## 📂 Repository Structure

* `01_all_nodes_common.sh`: Basic K8s setup.
* `01_all_nodes_kata_qemu.sh`: Kata/QEMU installation.
* `02_master_init.sh`: Control Plane initialization.
* `05_master_openwhisk.sh`: OpenWhisk Helm deployment.
* `06_mater_kata_webhook.sh`: Runtime injection webhook.
* `07_master_wsk_test.sh`: Smoke test script.

## 👥 Contact

**Ayoub SAMI**
Member of "Projet Long" : Serverless Energy Efficiency

```