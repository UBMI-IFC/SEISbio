#!/bin/bash

# Install snakePipes in its own environment using official channels.
# Quick start channels: conda-forge, bioconda, mpi-ie.

MANAGER=""
DISTRIBUTION=""
HOME_USER=""
ENV_NAME="snakePipes-env"
PACKAGE_SPEC="snakePipes"

usage() {
    echo "Usage: $0 --manager <mamba|conda> --distribution <name> --home <user> [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --manager <mamba|conda>        Conda frontend binary inside the distribution."
    echo "  --distribution <name>          Distribution directory under /home/<user>/ (e.g. miniforge)."
    echo "  --home <user>                  Target Linux user owning the distribution installation."
    echo "  --env-name <name>              Environment name. [default: snakePipes-env]"
    echo "  --package-spec <spec>          Package spec for snakePipes. [default: snakePipes]"
    echo "  -h, --help                     Display this help message and exit."
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --manager)
            MANAGER="$2"
            shift
            ;;
        --distribution)
            DISTRIBUTION="$2"
            shift
            ;;
        --home)
            HOME_USER="$2"
            shift
            ;;
        --env-name)
            ENV_NAME="$2"
            shift
            ;;
        --package-spec)
            PACKAGE_SPEC="$2"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "[ERROR] Unknown parameter: $1"
            usage
            ;;
    esac
    shift
done

if [[ -z "$MANAGER" || -z "$DISTRIBUTION" || -z "$HOME_USER" ]]; then
    echo "[ERROR] Missing required parameters."
    usage
fi

CONDA_BIN="/home/$HOME_USER/$DISTRIBUTION/bin/$MANAGER"

if [[ ! -x "$CONDA_BIN" ]]; then
    echo "[ERROR] Conda manager binary not found or not executable: $CONDA_BIN"
    exit 1
fi

echo "[INFO] Installing snakePipes env '$ENV_NAME' for user '$HOME_USER'"
echo "[INFO] Channels: conda-forge, bioconda, mpi-ie"

echo "[INFO] Package spec: $PACKAGE_SPEC"

create_cmd="cd /home/$HOME_USER && \"$CONDA_BIN\" create -n \"$ENV_NAME\" -c conda-forge -c bioconda -c mpi-ie \"$PACKAGE_SPEC\" -y -q"
clean_cmd="cd /home/$HOME_USER && \"$CONDA_BIN\" clean -a -y"

if [[ "$(id -un)" == "$HOME_USER" ]]; then
    if ! bash -lc "$create_cmd"; then
        echo "[WARN] Initial snakePipes create failed. Cleaning conda cache and retrying once..."
        bash -lc "$clean_cmd"
        bash -lc "$create_cmd"
    fi
else
    if ! sudo -i -u "$HOME_USER" bash -lc "$create_cmd"; then
        echo "[WARN] Initial snakePipes create failed. Cleaning conda cache and retrying once..."
        sudo -i -u "$HOME_USER" bash -lc "$clean_cmd"
        sudo -i -u "$HOME_USER" bash -lc "$create_cmd"
    fi
fi
