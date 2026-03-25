#!/bin/bash

# Make pipelines fail if any command in the pipeline fails/interrupted
set -o pipefail

TARGET_USER="seisbio"
TARGET_UID=1015
DISTRIBUTION="miniforge"
MANAGER="mamba"
SELECTED_ENV=""

# Handle interruptions (Ctrl+C / Ctrl+Z / kill)
handle_interrupt() {
    local sig="$1"
    echo ""
    echo "[WARN] Interrupted by signal: $sig"
    echo "[INFO] Stopping export process..."
    exit 130
}

trap 'handle_interrupt INT' INT
trap 'handle_interrupt TERM' TERM
trap 'handle_interrupt TSTP' TSTP

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Export conda environments from current user to YAML files in target user home"
    echo ""
    echo "Options:"
    echo "  -e, --env <name>              Export only the specified environment"
    echo "  -u, --user <name>             Target user where ymls/ will be created [default: seisbio]"
    echo "  -d, --distribution <name>     Distribution name (miniforge/miniconda) [default: auto-detect]"
    echo "  -m, --manager <name>          Package manager (mamba/conda) [default: auto-detect]"
    echo "  -h, --help                    Display this help message and exit"
    echo ""
       exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -e|--env)
            SELECTED_ENV="$2"
            shift
            ;;
        -u|--user)
            TARGET_USER="$2"
            shift
            ;;
        -d|--distribution)
            DISTRIBUTION="$2"
            shift
            ;;
        -m|--manager)
            MANAGER="$2"
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

# Function to detect conda
detect_conda() {
    if [[ -n "$CONDA_EXE" && -x "$CONDA_EXE" ]]; then
        echo "$CONDA_EXE"
        return
    fi

    local conda_path
    conda_path=$(command -v conda 2>/dev/null)

    if [[ -z "$conda_path" ]]; then
        echo "[ERROR] conda not found in PATH" >&2
        exit 1
    fi

    if [[ "$conda_path" == */condabin/conda ]]; then
        echo "$(dirname "$(dirname "$conda_path")")/bin/conda"
        return
    fi

    echo "$conda_path"
}

# Function to detect distribution and manager
detect_distribution_and_manager() {
    local detected_dist=""
    local detected_mgr=""
    
    # Try to detect from conda path
    if [[ -n "$CONDA_EXE" ]]; then
        if [[ "$CONDA_EXE" == *"miniforge"* ]]; then
            detected_dist="miniforge"
        elif [[ "$CONDA_EXE" == *"miniconda"* ]]; then
            detected_dist="miniconda"
        elif [[ "$CONDA_EXE" == *"anaconda"* ]]; then
            detected_dist="miniconda"
        fi
    fi
    
    # If not detected, try from PATH
    if [[ -z "$detected_dist" ]]; then
        local conda_path=$(command -v conda 2>/dev/null)
        if [[ -n "$conda_path" ]]; then
            local conda_dir=$(dirname "$(dirname "$conda_path")")
            if [[ "$conda_dir" == *"miniforge"* ]]; then
                detected_dist="miniforge"
            elif [[ "$conda_dir" == *"miniconda"* ]]; then
                detected_dist="miniconda"
            elif [[ "$conda_dir" == *"anaconda"* ]]; then
                detected_dist="miniconda"
            fi
        fi
    fi
    
    # Detect package manager (mamba or conda)
    # Try mamba first
    if command -v mamba &>/dev/null; then
        detected_mgr="mamba"
    else
        detected_mgr="conda"
    fi
    
    # Return both values separated by space
    echo "${detected_dist:-miniforge} ${detected_mgr:-mamba}"
}

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)

# Detect conda first to ensure it's available
CONDA=$(detect_conda)
if [[ ! -x "$CONDA" ]]; then
    echo "[ERROR] conda not executable: $CONDA"
    exit 1
fi

# Auto-detect distribution and manager from source user
echo "[INFO] Auto-detecting conda distribution and package manager..."
read DETECTED_DIST DETECTED_MGR <<< "$(detect_distribution_and_manager)"

# Use detected values if not overridden by command line
if [[ "$DISTRIBUTION" == "miniforge" ]] && [[ -n "$DETECTED_DIST" ]]; then
    DISTRIBUTION="$DETECTED_DIST"
fi

if [[ "$MANAGER" == "mamba" ]] && [[ -n "$DETECTED_MGR" ]]; then
    MANAGER="$DETECTED_MGR"
fi

echo "====================================="
echo "  SEISbio Environment Exporter"
echo "====================================="
echo ""
echo "[INFO] Source user: $CURRENT_USER (UID: $CURRENT_UID)"
echo "[INFO] Detected distribution: $DETECTED_DIST"
echo "[INFO] Detected manager: $DETECTED_MGR"
echo "[INFO] Using distribution: $DISTRIBUTION"
echo "[INFO] Using manager: $MANAGER"
echo "[INFO] Target user: $TARGET_USER"
echo ""

# Check if target user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "[ERROR] Target user '$TARGET_USER' does not exist!"
    echo "[INFO] Create the user first or run install_seisbio.sh"
    exit 1
fi

# Get target user UID
TARGET_UID=$(id -u "$TARGET_USER")

echo "[INFO] Using conda: $($CONDA --version)"
echo ""

# Ensure target YAML directory exists
TARGET_YMLS_DIR="/home/$TARGET_USER/ymls"
echo "[INFO] Ensuring target YAML directory exists: $TARGET_YMLS_DIR"
sudo -u "$TARGET_USER" mkdir -p "$TARGET_YMLS_DIR" || {
    echo "[ERROR] Failed to create target directory: $TARGET_YMLS_DIR"
    exit 1
}

# Get list of environments (exclude base)
if [[ -n "$SELECTED_ENV" ]]; then
    # Verify environment exists
    if "$CONDA" env list | grep -q "^${SELECTED_ENV} "; then
        ENVS="$SELECTED_ENV"
        echo "[INFO] Exporting environment: $SELECTED_ENV"
    else
        echo "[ERROR] Environment '$SELECTED_ENV' does not exist"
        echo "[INFO] Available environments:"
        "$CONDA" env list | grep -v '^#' | awk '{print "  - " $1}' | grep -v '^base$'
        exit 1
    fi
else
    ENVS=$("$CONDA" env list | grep -v '^#' | awk '{print $1}' | grep -v '^base$')
    
    if [[ -z "$ENVS" ]]; then
        echo "[INFO] No conda environments found to export"
        exit 0
    fi
    
    echo "[INFO] Found environments to clone:"
    for env in $ENVS; do
        echo "  - $env"
    done
fi

echo ""
echo "====================================="
echo "  Starting export process"
echo "====================================="
echo ""

# Counter for statistics
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# Export each environment to YAML in target user home
for ENV_NAME in $ENVS; do
    TOTAL=$((TOTAL + 1))
    echo "-----------------------------------"
    echo "[${TOTAL}] Processing: $ENV_NAME"
    
    TARGET_YML="$TARGET_YMLS_DIR/${ENV_NAME}_environment.yml"

    # Check if YAML already exists in target
    if [[ -f "$TARGET_YML" ]]; then
        echo "[WARN] YAML file already exists: $TARGET_YML"
        read -p "Do you want to overwrite it? y/[n]: " ANSWER
        if [[ "$ANSWER" != "y" && "$ANSWER" != "Y" ]]; then
            echo "[SKIP] Skipping $ENV_NAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
    fi

    echo "[INFO] Exporting $ENV_NAME to: $TARGET_YML"
    if ! "$CONDA" env export -n "$ENV_NAME" --no-builds | grep -v '^prefix:' | sudo tee "$TARGET_YML" > /dev/null; then
        echo "[ERROR] Failed to export $ENV_NAME"
        FAILED=$((FAILED + 1))
        continue
    fi

    sudo chown "$TARGET_UID:$TARGET_UID" "$TARGET_YML"
    echo "[SUCCESS] YAML created: $TARGET_YML"
    SUCCESS=$((SUCCESS + 1))
    
    echo ""
done

# Summary
echo ""
echo "====================================="
echo "  Export Summary"
echo "====================================="
echo "Total environments processed: $TOTAL"
echo "Successfully exported: $SUCCESS"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo "====================================="
echo ""

if [[ $SUCCESS -gt 0 ]]; then
    echo "[INFO] Exported YAML files are available in:"
    echo "       $TARGET_YMLS_DIR"
fi

exit 0


