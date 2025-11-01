#!/bin/bash
set -e

# Parse arguments
DELETE_MODE=false
if [ "$1" == "--delete" ]; then
  DELETE_MODE=true
fi

# Get all node names
NODE_NAMES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')

if [ "$DELETE_MODE" == true ]; then
  echo "=== Cleaning up scheduling problem demo ==="

  # Delete resources
  echo ""
  echo "Deleting resources..."
  kubectl delete -f manifests/04-scheduling.yaml --ignore-not-found=true

  # Remove taint from all nodes
  echo ""
  echo "Removing taint from all nodes..."
  for NODE_NAME in $NODE_NAMES; do
    kubectl taint nodes "$NODE_NAME" workload=batch:NoSchedule- --overwrite || echo "Taint not found or already removed on $NODE_NAME"
  done

  # Verify taint is removed
  echo ""
  echo "Verifying taint removal:"
  for NODE_NAME in $NODE_NAMES; do
    kubectl describe node "$NODE_NAME" | grep Taint || echo "No taints on node $NODE_NAME"
  done

  echo ""
  echo "=== Cleanup complete ==="
else
  echo "=== Setting up scheduling problem demo ==="

  # Set taint on all nodes
  echo "Setting taint on all nodes..."
  for NODE_NAME in $NODE_NAMES; do
    EXISTING_TAINT=$(kubectl describe node "$NODE_NAME" | grep "workload=batch:NoSchedule" || true)
    if [ -n "$EXISTING_TAINT" ]; then
      echo "Taint already exists on node $NODE_NAME"
    else
      kubectl taint nodes "$NODE_NAME" workload=batch:NoSchedule
    fi
  done

  # Verify taint is set
  echo ""
  echo "Verifying taint configuration:"
  for NODE_NAME in $NODE_NAMES; do
    kubectl describe node "$NODE_NAME" | grep Taint
  done

  # Apply manifests
  echo ""
  echo "Applying manifests..."
  kubectl apply -f manifests/04-scheduling.yaml

  # Wait a moment for resources to be created
  sleep 2

  # Show created resources
  echo ""
  echo "Created resources:"
  kubectl get all -n troubleshoot

  echo ""
  echo "=== Setup complete ==="
  echo "Note: The Pod should be in Pending state due to toleration misconfiguration"
fi