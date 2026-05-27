#!/bin/bash
# install_snakepipes.sh — SEISbio optional extension script.
# Called automatically by install_seisbio.sh --scripts.
# Received args: --manager <mgr> --distribution <dist> --home <user>

# ── Configuration ────────────────────────────────────────────────────────────
ENV_NAME="snakePipes-env"
PACKAGE="snakePipes"
CHANNELS="-c conda-forge -c bioconda -c mpi-ie"
# ─────────────────────────────────────────────────────────────────────────────

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --manager)      MANAGER="$2";      shift ;;
        --distribution) DISTRIBUTION="$2"; shift ;;
        --home)         HOME_USER="$2";    shift ;;
    esac
    shift
done

CONDA_BIN="/home/$HOME_USER/$DISTRIBUTION/bin/$MANAGER"
[[ ! -x "$CONDA_BIN" ]] && { echo "[ERROR] Conda not found: $CONDA_BIN"; exit 1; }

# Skip if already installed
sudo -i -u "$HOME_USER" bash -c "~/$DISTRIBUTION/bin/conda env list" 2>/dev/null \
    | awk '{print $1}' | grep -qx "$ENV_NAME" \
    && { echo "[INFO] '$ENV_NAME' already exists. Skipping."; exit 0; }

echo "[INFO] Installing '$ENV_NAME' for '$HOME_USER'..."

RUN() { sudo -i -u "$HOME_USER" bash -lc "$1"; }
CMD="\"$CONDA_BIN\" create -n \"$ENV_NAME\" $CHANNELS \"$PACKAGE\" -y -q"

if ! RUN "$CMD"; then
    echo "[WARN] Failed. Cleaning cache and retrying..."
    RUN "\"$CONDA_BIN\" clean -a -y"
    RUN "$CMD" || { echo "[ERROR] Installation failed."; exit 1; }
fi

echo "[OK] '$ENV_NAME' installed."
