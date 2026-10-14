#!/bin/sh
set -e

# Start Docker daemon in background
dockerd &

# Wait for Docker daemon to be ready
while ! docker info > /dev/null 2>&1; do
  echo "Waiting for Docker daemon to start..."
  sleep 1
done

echo "Docker daemon started."

# Execute passed command or keep container running
exec "$@"
