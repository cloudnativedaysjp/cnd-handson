#!/bin/bash
set -e

# Parse arguments
DELETE_MODE=false
if [ "$1" == "--delete" ]; then
  DELETE_MODE=true
fi

# Get the first node name (assuming single node cluster)
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Detected node: $NODE_NAME"

if [ "$DELETE_MODE" == true ]; then
  echo "=== Cleaning up scheduling problem demo ==="

  # Delete resources
  echo ""
  echo "Deleting resources..."
  kubectl delete -f manifests/04-scheduling.yaml --ignore-not-found=true

  # Remove taint
  echo ""
  echo "Removing taint from node $NODE_NAME..."
  kubectl taint nodes "$NODE_NAME" workload=batch:NoSchedule- --overwrite || echo "Taint not found or already removed"

  # Verify taint is removed
  echo ""
  echo "Verifying taint removal:"
  kubectl describe node "$NODE_NAME" | grep Taint || echo "No taints on node"

  echo ""
  echo "=== Cleanup complete ==="
else
  echo "=== Setting up scheduling problem demo ==="

  # Check if taint already exists
  EXISTING_TAINT=$(kubectl describe node "$NODE_NAME" | grep "workload=batch:NoSchedule" || true)

  if [ -n "$EXISTING_TAINT" ]; then
    echo "Taint already exists on node $NODE_NAME"
  else
    echo "Setting taint on node $NODE_NAME..."
    kubectl taint nodes "$NODE_NAME" workload=batch:NoSchedule
  fi

  # Verify taint is set
  echo ""
  echo "Verifying taint configuration:"
  kubectl describe node "$NODE_NAME" | grep Taint

  # Apply manifests
  echo ""
  echo "Applying manifests..."
  kubectl apply -f manifests/04-scheduling.yaml

  # Wait a moment for resources to be created
  sleep 2

  # Show created resources
  echo ""
  echo "Created resources:"
  kubectl get all -n scheduling-demo

  echo ""
  echo "=== Setup complete ==="
  echo "Note: The Pod should be in Pending state due to toleration misconfiguration"
fi
