#!/bin/bash

set -eu

KIND_VERSION=v0.20.0
KUBECTL_VERSION=v1.28.1
CILIUM_CLI_VERSION=v0.15.7
HELM_VERSION="v3.12.3"
HELMFILE_VERSION="0.156.0"

# install kind
#  see: https://kind.sigs.k8s.io/docs/user/quick-start/#installation
curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
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
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# install helm
wget "https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz"
tar -zxvf "helm-$HELM_VERSION-linux-amd64.tar.gz"
sudo mv linux-amd64/helm /usr/local/bin/helm

# install helm-diff
helm plugin install https://github.com/databus23/helm-diff

# install helmfile
wget "https://github.com/helmfile/helmfile/releases/download/v$HELMFILE_VERSION/helmfile_$(echo $HELMFILE_VERSION)_linux_amd64.tar.gz"
tar -zxvf "helmfile_$(echo $HELMFILE_VERSION)_linux_amd64.tar.gz"

sudo mv helmfile /usr/local/bin/helmfile
