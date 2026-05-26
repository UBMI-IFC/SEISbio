#!/bin/bash

# Install tutorial-seisbio dependencies (Ruby, Bundler, Rails gems) inside a
# dedicated conda environment and copy the tutorial application to the target
# user's home directory.
#
# This script follows the same convention as install_snakepipes.sh and is
# invoked by install_seisbio.sh when --tutorial is specified.

MANAGER=""
DISTRIBUTION=""
HOME_USER=""
ENV_NAME="tutorial-env"

usage() {
    echo "Usage: $0 --manager <mamba|conda> --distribution <name> --home <user> [OPTIONS]"
    echo ""
    echo "Install the tutorial-seisbio interactive tutorial and its Ruby/Rails"
    echo "dependencies inside a dedicated conda environment."
    echo ""
    echo "Options:"
    echo "  --manager <mamba|conda>        Conda frontend binary inside the distribution."
    echo "  --distribution <name>          Distribution directory under /home/<user>/ (e.g. miniforge)."
    echo "  --home <user>                  Target Linux user owning the distribution installation."
    echo "  --env-name <name>              Environment name. [default: tutorial-env]"
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
TUTORIAL_SRC_DIR=""
TUTORIAL_DEST="/home/$HOME_USER/tutorial-seisbio"

# Locate the tutorial-seisbio source directory relative to this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Try sibling directory (scripts/ -> ../tutorial-seisbio/)
if [[ -d "$SCRIPT_DIR/../tutorial-seisbio" ]]; then
    TUTORIAL_SRC_DIR="$(cd "$SCRIPT_DIR/../tutorial-seisbio" && pwd)"
fi

if [[ ! -x "$CONDA_BIN" ]]; then
    echo "[ERROR] Conda manager binary not found or not executable: $CONDA_BIN"
    exit 1
fi

if [[ -z "$TUTORIAL_SRC_DIR" ]]; then
    echo "[ERROR] Could not locate tutorial-seisbio source directory."
    echo "[INFO]  Expected at: $SCRIPT_DIR/../tutorial-seisbio/"
    exit 1
fi

echo "============================================"
echo "[INFO] Installing tutorial-seisbio"
echo "[INFO] User: $HOME_USER"
echo "[INFO] Environment: $ENV_NAME"
echo "[INFO] Source: $TUTORIAL_SRC_DIR"
echo "============================================"

# ---------- Step 1: Create conda environment with Ruby --------------------

echo ""
echo "[STEP 1/5] Creating conda environment '$ENV_NAME' with Ruby and compilers"

# Check if environment already exists
env_exists=$(sudo -i -u "$HOME_USER" bash -c "~/$DISTRIBUTION/bin/conda env list" 2>/dev/null | awk '{print $1}' | grep -x "$ENV_NAME" || true)

if [[ -n "$env_exists" ]]; then
    echo "[INFO] Environment '$ENV_NAME' already exists. Skipping creation."
else
    create_cmd="cd /home/$HOME_USER && \"$CONDA_BIN\" create -n \"$ENV_NAME\" -c conda-forge ruby compilers -y -q"

    if [[ "$(id -un)" == "$HOME_USER" ]]; then
        bash -lc "$create_cmd" || {
            echo "[ERROR] Failed to create conda environment '$ENV_NAME'."
            exit 1
        }
    else
        sudo -i -u "$HOME_USER" bash -lc "$create_cmd" || {
            echo "[ERROR] Failed to create conda environment '$ENV_NAME'."
            exit 1
        }
    fi
    echo "[OK] Conda environment '$ENV_NAME' created."
fi

# ---------- Step 2: Install Bundler --------------------------------------

echo ""
echo "[STEP 2/5] Installing Bundler inside '$ENV_NAME'"

bundler_cmd="cd /home/$HOME_USER && source ~/$DISTRIBUTION/etc/profile.d/conda.sh && conda activate $ENV_NAME && gem install bundler --no-document"

if [[ "$(id -un)" == "$HOME_USER" ]]; then
    bash -lc "$bundler_cmd" || {
        echo "[ERROR] Failed to install Bundler."
        exit 1
    }
else
    sudo -i -u "$HOME_USER" bash -lc "$bundler_cmd" || {
        echo "[ERROR] Failed to install Bundler."
        exit 1
    }
fi
echo "[OK] Bundler installed."

# ---------- Step 3: Copy tutorial-seisbio to user home --------------------

echo ""
echo "[STEP 3/5] Copying tutorial-seisbio to $TUTORIAL_DEST"

if [[ -d "$TUTORIAL_DEST" ]]; then
    echo "[INFO] Tutorial directory already exists at $TUTORIAL_DEST."
    echo "[INFO] Updating files (rsync)..."
    if command -v rsync &>/dev/null; then
        sudo rsync -a --exclude='.git' --exclude='tmp/' --exclude='log/' --exclude='vendor/bundle/' "$TUTORIAL_SRC_DIR/" "$TUTORIAL_DEST/" || {
            echo "[ERROR] Failed to sync tutorial directory."
            exit 1
        }
    else
        # Fallback to cp
        sudo cp -r "$TUTORIAL_SRC_DIR/." "$TUTORIAL_DEST/" || {
            echo "[ERROR] Failed to copy tutorial directory."
            exit 1
        }
    fi
else
    sudo cp -r "$TUTORIAL_SRC_DIR" "$TUTORIAL_DEST" || {
        echo "[ERROR] Failed to copy tutorial directory."
        exit 1
    }
fi

sudo chown -R "$HOME_USER:$HOME_USER" "$TUTORIAL_DEST"
echo "[OK] Tutorial files copied to $TUTORIAL_DEST"

# ---------- Step 4: Run bundle install -----------------------------------

echo ""
echo "[STEP 4/5] Installing Ruby gems (bundle install)"

bundle_cmd="source ~/$DISTRIBUTION/etc/profile.d/conda.sh && conda activate $ENV_NAME && cd $TUTORIAL_DEST && bundle config set --local path 'vendor/bundle' && bundle install --quiet"

if [[ "$(id -un)" == "$HOME_USER" ]]; then
    bash -lc "$bundle_cmd" || {
        echo "[ERROR] bundle install failed."
        exit 1
    }
else
    sudo -i -u "$HOME_USER" bash -lc "$bundle_cmd" || {
        echo "[ERROR] bundle install failed."
        exit 1
    }
fi
echo "[OK] Ruby gems installed."

# ---------- Step 5: Configure Docker access and build sandbox image -------

echo ""
echo "[STEP 5/5] Configuring Docker access and building sandbox image"

if command -v docker &>/dev/null; then
    # Add user to docker group if not already a member
    if ! id -nG "$HOME_USER" 2>/dev/null | grep -qw docker; then
        echo "[INFO] Adding '$HOME_USER' to the 'docker' group for container access..."
        sudo usermod -aG docker "$HOME_USER" || {
            echo "[WARN] Failed to add '$HOME_USER' to the docker group."
            echo "[INFO] You can do it manually: sudo usermod -aG docker $HOME_USER"
        }
        echo "[OK] User '$HOME_USER' added to docker group."
        echo "[INFO] A re-login may be required for Docker permissions to take effect."
    else
        echo "[INFO] User '$HOME_USER' is already in the docker group."
    fi
    if docker info &>/dev/null 2>&1; then
        echo "[INFO] Docker is available. Building sandbox image..."
        build_script="$TUTORIAL_DEST/bin/build_sandbox_image.sh"
        if [[ -x "$build_script" ]]; then
            bash "$build_script" || {
                echo "[WARN] Docker sandbox image build failed."
                echo "[INFO] You can build it later with:"
                echo "       cd $TUTORIAL_DEST && ./bin/build_sandbox_image.sh"
            }
            echo "[OK] Docker sandbox image built."
        else
            echo "[WARN] build_sandbox_image.sh not found or not executable at: $build_script"
            echo "[INFO] You can build it later manually."
        fi
    else
        echo "[WARN] Docker daemon is not running."
        echo "[INFO] The TUI tutorial (bin/rails tutorial:start) works without Docker."
        echo "[INFO] For the web tutorial, start Docker and build the sandbox image:"
        echo "       cd $TUTORIAL_DEST && ./bin/build_sandbox_image.sh"
    fi
else
    echo "[WARN] Docker is not installed."
    echo "[INFO] The TUI tutorial (bin/rails tutorial:start) works without Docker."
    echo "[INFO] For the web tutorial, install Docker and build the sandbox image:"
    echo "       cd $TUTORIAL_DEST && ./bin/build_sandbox_image.sh"
fi

# ---------- Summary -------------------------------------------------------

echo ""
echo "============================================"
echo "[SUCCESS] tutorial-seisbio installation complete"
echo "============================================"
echo ""
echo "To run the tutorial:"
echo ""
echo "  # Switch to the seisbio user (if not already)"
echo "  sudo -i -u $HOME_USER"
echo ""
echo "  # Activate the tutorial environment"
echo "  conda activate $ENV_NAME"
echo ""
echo "  # Option A: Terminal UI (TUI) tutorial"
echo "  cd ~/tutorial-seisbio && bin/rails tutorial:start"
echo ""
echo "  # Option B: Web tutorial (requires Docker)"
echo "  cd ~/tutorial-seisbio && bin/rails server"
echo "  # Then visit http://localhost:3000"
echo ""
