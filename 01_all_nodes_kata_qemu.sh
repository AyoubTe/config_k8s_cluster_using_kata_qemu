#!/bin/bash
set -e

# Run on ALL nodes
KATA_VERSION="2.5.2"

apt-get update
apt-get install -y cpu-checker qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

if ! kvm-ok; then
    echo "ERROR: KVM not available. Enable nested virtualization."
    exit 1
fi

# Download and install Kata 2.5.2
if ! command -v kata-runtime &>/dev/null; then
    KATA_URL="https://github.com/kata-containers/kata-containers/releases/download/${KATA_VERSION}/kata-static-${KATA_VERSION}-x86_64.tar.xz"
    curl -fsSL --retry 3 "$KATA_URL" -o /tmp/kata-static.tar.xz
    tar -xf /tmp/kata-static.tar.xz -C /
    rm /tmp/kata-static.tar.xz
fi

# Setup symlinks
ln -sf /opt/kata/bin/kata-runtime /usr/local/bin/kata-runtime
ln -sf /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-v2
ln -sf /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-qemu-v2

# Create QEMU configuration
mkdir -p /etc/kata-containers
# Use the default QEMU template from the installation
cp /opt/kata/share/defaults/kata-containers/configuration-qemu.toml /etc/kata-containers/configuration.toml

# Fine-tune configuration for QEMU + Virtio-FS (standard for K8s)
sed -i 's/^#\?virtio_fs_daemon =.*/virtio_fs_daemon = "\/opt\/kata\/libexec\/virtiofsd"/' /etc/kata-containers/configuration.toml
sed -i 's/^#\?shared_fs =.*/shared_fs = "virtio-fs"/' /etc/kata-containers/configuration.toml

# Update containerd to recognize the new handler
CONTAINERD_CFG="/etc/containerd/config.toml"
if ! grep -q "kata-qemu" "$CONTAINERD_CFG"; then
    cat >> "$CONTAINERD_CFG" <<'ENDOFBLOCK'

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu]
          runtime_type = "io.containerd.kata.v2"
          privileged_without_host_devices = true
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata-qemu.options]
            ConfigPath = "/etc/kata-containers/configuration.toml"
ENDOFBLOCK
fi

systemctl restart containerd
echo "Kata + QEMU setup complete on $(hostname)"