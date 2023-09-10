#!/bin/bash

set -eu

KIND_VERSION=v0.20.0
KUBECTL_VERSION=v1.28.1
CILIUM_CLI_VERSION=v0.15.7

# install kind
#  see: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/
kind --version

# install kubectl
#  see: https://kubernetes.io/ja/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo cp kubectl /usr/local/bin/

# install cilium CLI
#  see: https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#cilium-quick-installation
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
