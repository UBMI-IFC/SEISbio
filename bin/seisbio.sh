#!/bin/bash

BASE_PATH="/home"
SEISBIO_USER="seisbio"

if [[ -f "/etc/seisbio.conf" ]]; then
    source /etc/seisbio.conf
fi

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --home)
            SEISBIO_USER="$2"
            shift
            ;;
        --base-path)
            BASE_PATH="$2"
            shift
            ;;
        -h|--help)
            echo "Usage: ./bin/seisbio.sh [OPTIONS]"
            echo "Options:"
            echo "  --home <name>         Override the default 'seisbio' username"
            echo "  --base-path <path>    Override the default '/home' base path"
            echo "  -h, --help            Display this help message"
            exit 0
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
    shift
done

SEISBIO_HOME="$BASE_PATH/$SEISBIO_USER"

if [[ "$(pwd)" != "$SEISBIO_HOME" ]]; then
    echo "[INFO] Copying files..."
    # Get script directory to properly reference files
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    sudo cp "$SCRIPT_DIR/../envs/virtual_envs.txt" "$SCRIPT_DIR/../envs/small_virtual_envs.txt" "$SCRIPT_DIR/utilities/build_container.sh" "$SCRIPT_DIR/utilities/create_container.sh" "$SCRIPT_DIR/utilities/run_container_pipeline.sh" "$SCRIPT_DIR/install_seisbio.sh" "$SEISBIO_HOME/"

    # Copy the tutorial directory only if the tutorial environment exists (meaning it was installed)
    if [[ -d "$SCRIPT_DIR/../tutorial-seisbio" ]] && (sudo -i -u "$SEISBIO_USER" bash -c "conda env list 2>/dev/null | grep -qw tutorial-env" || [[ -d "$SEISBIO_HOME/miniforge/envs/tutorial-env" ]] || [[ -d "$SEISBIO_HOME/miniconda/envs/tutorial-env" ]]); then
        if [[ ! -d "$SEISBIO_HOME/tutorial-seisbio" ]]; then
            echo "[INFO] Copying tutorial-seisbio directory..."
            sudo cp -r "$SCRIPT_DIR/../tutorial-seisbio" "$SEISBIO_HOME/"
            sudo chown -R "$SEISBIO_USER:$SEISBIO_USER" "$SEISBIO_HOME/tutorial-seisbio"
        else
            # Only update files safely without overwriting the installed gems
            if command -v rsync &>/dev/null; then
                sudo rsync -a --exclude='.git' --exclude='tmp/' --exclude='log/' --exclude='vendor/bundle/' "$SCRIPT_DIR/../tutorial-seisbio/" "$SEISBIO_HOME/tutorial-seisbio/"
                sudo chown -R "$SEISBIO_USER:$SEISBIO_USER" "$SEISBIO_HOME/tutorial-seisbio"
            fi
        fi
    fi

    echo "[INFO] Opening session as $SEISBIO_USER..."
    exec sudo -i -u "$SEISBIO_USER"
else
    echo "[INFO] Checking Apptainer installation..."
    if ! command -v apptainer &> /dev/null; then
        echo "[INFO] Installing Apptainer..."
        sudo apt update
        sudo apt install -y apptainer
        echo "[INFO] Apptainer installed successfully"
    else
        echo "[INFO] Apptainer is already installed"
    fi
fi
