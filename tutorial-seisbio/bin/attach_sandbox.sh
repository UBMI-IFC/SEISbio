#!/usr/bin/env bash
set -euo pipefail

# Attach to a running seisbio sandbox container started by the web app
# If no container is found, prints a hint to start one locally.

IMAGE_NAME=${IMAGE_NAME:-seisbio-tutorial-sandbox}
DEFAULT_NAME=${1:-seisbio-sandbox-local}

# Try to find a running container named like seisbio-sandbox-*
container=$(docker ps --filter "name=seisbio-sandbox-" --format "{{.Names}}" | head -n1 || true)

if [[ -z "$container" ]]; then
  echo "No running sandbox container found."
  echo "You can start a local sandbox (detached) with:"
  echo "  bin/build_sandbox_image.sh   # build image (if needed)"
  echo "  docker run -d --name ${DEFAULT_NAME} --tmpfs /home/tutorial:exec,mode=755,size=4g,uid=1000,gid=1000 ${IMAGE_NAME}"
  echo "Then attach with:"
  echo "  docker exec -it ${DEFAULT_NAME} bash"
  exit 1
fi

echo "Attaching to sandbox container: $container"
# Prefer an interactive shell as the tutorial user if available
# Many images use a non-root 'tutorial' user; try exec with that user id (1000)
if docker exec "$container" id tutorial &>/dev/null; then
  docker exec -it --user tutorial "$container" bash
else
  docker exec -it "$container" bash
fi
