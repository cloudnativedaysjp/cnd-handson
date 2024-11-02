#!/bin/bash

set -o nounset
set -o pipefail
set -o errexit

# Versions of the tools to install
readonly KIND_VERSION="v0.24.0"
readonly KUBECTL_VERSION="v1.31.1"
readonly CILIUM_CLI_VERSION="v0.16.16"
readonly HELM_VERSION="v3.16.0"
readonly HELMFILE_VERSION="0.168.0"
# Output colors
readonly GREEN='\033[0;32m'
readonly RED="\033[0;31m"
readonly RESET='\033[0;39m'

TMP_DIR=$(mktemp -d -p /tmp) || {
  echo "Failed to create temporary directory"
  exit 1
}
readonly TMP_DIR

has() {
  command -v "$1" > /dev/null 2>&1
}

info() {
  echo -e "${GREEN}[info]${RESET} $1"
}

err() {
  echo -e "${RED}[error]${RESET} $1"
}

err_on_exit() {
  echo -e "${RED}[error]${RESET} $1"
  exit 1
}

cleanup() {
  info "Cleaning up temporary files..."
  rm -rf "${TMP_DIR}" || err "Failed to remove temporary directory: ${TMP_DIR}"
}
trap cleanup EXIT ERR

download() {
  local url=$1
  local output=$2

  curl -sfSL "${url}" -o "${output}" || {
    err "Failed to download ${url}"
    return 1
  }
}

validate_checksum() {
  local target=$1
  local checksum_file=$2

  diff <(sha256sum "${target}" | cut -d" " -f 1) <(cut -d" " -f 1 "${checksum_file}") >/dev/null 2>&1 || {
    err "Checksum mismatch for ${target}"
    return 1
  }
}

install_binary() {
  local -r binary_src_path=$1
  sudo install -m 0755 "$binary_src_path" /usr/local/bin/ || {
    err "Failed to install $binary_src_path"
    return 1
  }
}

install_kind() {
  local -r base_download_url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}"

  if has kind; then
    info "kind is already installed"
    return
  fi

  info "Installing kind..."
  download "${base_download_url}/kind-linux-amd64" "${TMP_DIR}/kind" || return 1
  download "${base_download_url}/kind-linux-amd64.sha256sum" "${TMP_DIR}/kind.sha256sum" || return 1
  validate_checksum "${TMP_DIR}/kind" "${TMP_DIR}/kind.sha256sum" || return 1
  install_binary "${TMP_DIR}/kind" || return 1
  info "kind installed successfully: $(kind --version)"
}

install_kubectl() {
  local -r base_download_url="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64"

  if has kubectl; then
    info "kubectl is already installed"
    return
  fi

  info "Installing kubectl..."
  download "${base_download_url}/kubectl" "${TMP_DIR}/kubectl" || return 1
  download "${base_download_url}/kubectl.sha256" "${TMP_DIR}/kubectl.sha256" || return 1
  validate_checksum "${TMP_DIR}/kubectl" "${TMP_DIR}/kubectl.sha256" || return 1
  install_binary "${TMP_DIR}/kubectl" || return 1
  info "kubectl installed successfully: $(kubectl version --client | head -n1)"
}

install_cilium_cli() {
  local -r base_download_url="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}"
  local -r base_file_name="cilium-linux-amd64"

  if has cilium; then
    info "cilium is already installed"
    return
  fi

  info "Installing cilium CLI..."
  download "${base_download_url}/${base_file_name}.tar.gz" "${TMP_DIR}/${base_file_name}.tar.gz" || return 1
  download "${base_download_url}/${base_file_name}.tar.gz.sha256sum" "${TMP_DIR}/${base_file_name}.tar.gz.sha256sum" || return 1
  validate_checksum "${TMP_DIR}/${base_file_name}.tar.gz" "${TMP_DIR}/${base_file_name}.tar.gz.sha256sum" || return 1
  tar xzfC "${TMP_DIR}/${base_file_name}.tar.gz" "$TMP_DIR" || return 1
  install_binary "${TMP_DIR}/cilium" || return 1
  info "cilium CLI installed successfully: $(cilium version --client)"
}

install_helm() {
  local -r base_download_url="https://get.helm.sh/helm-${HELM_VERSION}"
  local -r base_file_name="linux-amd64"

  if has helm; then
    info "helm is already installed"
    return
  fi

  download "${base_download_url}-${base_file_name}.tar.gz" "${TMP_DIR}/helm-${HELM_VERSION}-${base_file_name}.tar.gz" || return 1
  download "${base_download_url}-${base_file_name}.tar.gz.sha256sum" "${TMP_DIR}/helm-${HELM_VERSION}-${base_file_name}.tar.gz.sha256sum" || return 1
  validate_checksum "${TMP_DIR}/helm-${HELM_VERSION}-${base_file_name}.tar.gz" "${TMP_DIR}/helm-${HELM_VERSION}-${base_file_name}.tar.gz.sha256sum" || return 1
  tar xzfC "${TMP_DIR}/helm-${HELM_VERSION}-${base_file_name}.tar.gz" "$TMP_DIR" || return 1
  install_binary "${TMP_DIR}/${base_file_name}/helm" || return 1
  info "helm installed successfully: $(helm version --short)"
}

install_helm_diff() {
  local -r plugin_url="https://github.com/databus23/helm-diff"

  if ! has helm; then
    err_on_exit "helm is not installed"
  fi
  if helm plugin list | grep -q diff; then
    info "helm-diff plugin is already installed"
    return
  fi

  info "Installing helm-diff plugin..."
  helm plugin install "$plugin_url" > /dev/null 2>&1 || {
    err "Failed to install helm-diff plugin"
    return 1
  }
  info "helm-diff plugin installed successfully: $(helm plugin list | grep diff | awk '{print $2}')"
}

install_helmfile() {
  local -r base_download_url="https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}"
  local -r base_file_name="linux_amd64"
  local tmp_checksum_file="${TMP_DIR}/helmfile_${HELMFILE_VERSION}_${base_file_name}_checksum.txt"

  if has helmfile; then
    info "helmfile is already installed"
    return
  fi

  info "Installing helmfile..."
  download "${base_download_url}/helmfile_${HELMFILE_VERSION}_${base_file_name}.tar.gz" "${TMP_DIR}/helmfile_${HELMFILE_VERSION}_${base_file_name}.tar.gz" || {
    return 1
  }
  download "${base_download_url}/helmfile_${HELMFILE_VERSION}_checksums.txt" "${TMP_DIR}/helmfile_${HELMFILE_VERSION}_checksums.txt" || return 1
  grep "${base_file_name}" "${TMP_DIR}/helmfile_${HELMFILE_VERSION}_checksums.txt" > "$tmp_checksum_file" || {
    err "Failed to find checksum for helmfile_${HELMFILE_VERSION}_${base_file_name}.tar.gz"
    return 1
  }
  validate_checksum "${TMP_DIR}/helmfile_${HELMFILE_VERSION}_${base_file_name}.tar.gz" "$tmp_checksum_file" || return 1
  tar xzfC "${TMP_DIR}/helmfile_${HELMFILE_VERSION}_${base_file_name}.tar.gz" "$TMP_DIR" || return 1
  install_binary "${TMP_DIR}/helmfile" || return 1
  info "helmfile installed successfully: $(helmfile --version)"
}

main() {
  info "Starting installation of Kubernetes tools..."
  info "Temporary directory: ${TMP_DIR}"

  local tools=(
    install_kind
    install_kubectl
    install_cilium_cli
    install_helm
    install_helm_diff
    install_helmfile
  )
  for tool in "${tools[@]}"; do
    $tool || err_on_exit "Failed to execute '${tool}'"
  done

  info "All tools have been installed successfully!"
}

sudo apt update -y && \
sudo apt install -y jq
cd "$(dirname "$0")" || err_on_exit "Failed to change directory"
main
