#!/bin/bash

HUBBLE_VERSION=v0.12.0

# Install hubble CLI
# See: https://docs.cilium.io/en/stable/gettingstarted/hubble_setup/#install-the-hubble-client
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz{,.sha256sum}
