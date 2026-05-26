#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

cd "$ROOT_DIR"

exec docker build -f "$ROOT_DIR/docker/Sandbox.Dockerfile" -t seisbio-tutorial-sandbox "$ROOT_DIR"
