#!/bin/bash

TARGET_USER="seisbio"
TARGET_UID=1015
DISTRIBUTION="miniforge"
MANAGER="mamba"
SELECTED_ENV=""
TEMP_DIR="/tmp/seisbio_clone_$$"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Clone conda environments from current user to seisbio user"
    echo ""
    echo "Options:"
    echo "  -e, --env <name>              Clone only the specified environment"
    echo "  -u, --user <name>             Target user to clone environments to [default: seisbio]"
    echo "  -d, --distribution <name>     Distribution name (miniforge/miniconda) [default: miniforge]"
    echo "  -m, --manager <name>          Package manager (mamba/conda) [default: mamba]"
    echo "  -h, --help                    Display this help message and exit"
    echo ""
    echo "Examples:"
    echo "  $0                            # Clone all environments to seisbio"
    echo "  $0 -e fastqc-env              # Clone only fastqc-env to seisbio"
    echo "  $0 -u myuser -d miniconda     # Clone to myuser using miniconda"
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
echo "  SEISbio Environment Cloner"
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

# Check if target distribution is installed
if [[ ! -d "/home/$TARGET_USER/$DISTRIBUTION" ]]; then
    echo "[ERROR] $DISTRIBUTION not installed for user $TARGET_USER"
    echo "[INFO] Expected path: /home/$TARGET_USER/$DISTRIBUTION"
    echo "[INFO] Run install_seisbio.sh first to install $DISTRIBUTION"
    exit 1
fi

echo "[INFO] Using conda: $($CONDA --version)"
echo ""

# Create temporary directory
mkdir -p "$TEMP_DIR"
echo "[INFO] Using temporary directory: $TEMP_DIR"
echo ""

# Get list of environments (exclude base)
if [[ -n "$SELECTED_ENV" ]]; then
    # Verify environment exists
    if "$CONDA" env list | grep -q "^${SELECTED_ENV} "; then
        ENVS="$SELECTED_ENV"
        echo "[INFO] Cloning environment: $SELECTED_ENV"
    else
        echo "[ERROR] Environment '$SELECTED_ENV' does not exist"
        echo "[INFO] Available environments:"
        "$CONDA" env list | grep -v '^#' | awk '{print "  - " $1}' | grep -v '^base$'
        rm -rf "$TEMP_DIR"
        exit 1
    fi
else
    ENVS=$("$CONDA" env list | grep -v '^#' | awk '{print $1}' | grep -v '^base$')
    
    if [[ -z "$ENVS" ]]; then
        echo "[INFO] No conda environments found to clone"
        rm -rf "$TEMP_DIR"
        exit 0
    fi
    
    echo "[INFO] Found environments to clone:"
    for env in $ENVS; do
        echo "  - $env"
    done
fi

echo ""
echo "====================================="
echo "  Starting cloning process"
echo "====================================="
echo ""

# Counter for statistics
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# Get existing environments in target user
echo "[INFO] Checking existing environments in $TARGET_USER..."
TARGET_ENVS=$(sudo -i -u "$TARGET_USER" bash -c "conda env list" 2>/dev/null | grep -v '^#' | awk '{print $1}')

# Clone each environment
for ENV_NAME in $ENVS; do
    TOTAL=$((TOTAL + 1))
    echo "-----------------------------------"
    echo "[${TOTAL}] Processing: $ENV_NAME"
    
    # Check if environment already exists in target
    if echo "$TARGET_ENVS" | grep -q "^${ENV_NAME}$"; then
        echo "[WARN] Environment '$ENV_NAME' already exists in $TARGET_USER"
        read -p "Do you want to recreate it? y/[n]: " ANSWER
        if [[ "$ANSWER" != "y" && "$ANSWER" != "Y" ]]; then
            echo "[SKIP] Skipping $ENV_NAME"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi
        
        # Remove existing environment
        echo "[INFO] Removing existing environment..."
        if ! sudo -i -u "$TARGET_USER" bash -c "~/$DISTRIBUTION/bin/conda env remove -n $ENV_NAME -y" 2>/dev/null; then
            echo "[ERROR] Failed to remove existing environment $ENV_NAME"
            FAILED=$((FAILED + 1))
            continue
        fi
    fi
    
    # Export environment to YAML
    YML_FILE="$TEMP_DIR/${ENV_NAME}_environment.yml"
    echo "[INFO] Exporting $ENV_NAME to YAML..."
    if ! "$CONDA" env export -n "$ENV_NAME" > "$YML_FILE" 2>/dev/null; then
        echo "[ERROR] Failed to export $ENV_NAME"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Copy YAML to target user's home
    TARGET_YML="/home/$TARGET_USER/${ENV_NAME}_temp.yml"
    echo "[INFO] Copying YAML to $TARGET_USER home..."
    if ! sudo cp "$YML_FILE" "$TARGET_YML"; then
        echo "[ERROR] Failed to copy YAML file"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Set ownership
    sudo chown "$TARGET_UID:$TARGET_UID" "$TARGET_YML"
    
    # Create environment in target user
    echo "[INFO] Creating environment in $TARGET_USER..."
    if sudo -i -u "$TARGET_USER" bash -c "~/$DISTRIBUTION/bin/$MANAGER env create -f ~/${ENV_NAME}_temp.yml" 2>&1 | tee /tmp/clone_output_$$.log; then
        echo "[SUCCESS] Environment '$ENV_NAME' cloned successfully!"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "[ERROR] Failed to create environment $ENV_NAME in $TARGET_USER"
        FAILED=$((FAILED + 1))
    fi
    
    # Clean up temporary YAML in target user's home
    sudo rm -f "$TARGET_YML"
    
    echo ""
done

# Clean up temporary directory
echo "[INFO] Cleaning up temporary files..."
rm -rf "$TEMP_DIR"
rm -f /tmp/clone_output_$$.log

# Summary
echo ""
echo "====================================="
echo "  Cloning Summary"
echo "====================================="
echo "Total environments processed: $TOTAL"
echo "Successfully cloned: $SUCCESS"
echo "Failed: $FAILED"
echo "Skipped: $SKIPPED"
echo "====================================="
echo ""

if [[ $SUCCESS -gt 0 ]]; then
    echo "[INFO] Cloned environments are now available in $TARGET_USER"
    echo "[INFO] To verify, run:"
    echo "       sudo -i -u $TARGET_USER"
    echo "       conda env list"
fi

exit 0


