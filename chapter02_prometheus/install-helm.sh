set -eu

HELM_VERSION="v3.12.3"
HELMFILE_VERSION="0.156.0"

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
