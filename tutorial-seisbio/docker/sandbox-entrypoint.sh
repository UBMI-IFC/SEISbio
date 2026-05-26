#!/usr/bin/env bash
set -euo pipefail

mkdir -p /home/tutorial/.conda/pkgs
mkdir -p /home/tutorial/.conda/envs
mkdir -p /home/tutorial/.conda/conda-bld
chmod -R 700 /home/tutorial/.conda

exec "$@"
