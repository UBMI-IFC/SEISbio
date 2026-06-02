#!/bin/bash
#
# ------------------------------
# Name:     install_seisbio.sh
# Purpose:  General Instalation of SEISbio
#
# @uthor:      acph - dragopoot@gmail.com
#
# Created:     jue 18 feb 2021 22:18:52 CST (original Python script)
# Migrated:    jun 27 jun 2025
# Copyright:   (c) acph 2021
# Licence:     GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# ------------------------------
# General Instalation of SEISbio

# Default values
DISTRIBUTION="miniforge"
HOME_DIR="seisbio"
HOME_ID=1015
DEBIAN_INSTALL=false
DEB_UPGRADE=false
ARCH_INSTALL=false
AUR_INSTALL=false
ENV_FILE=""
YML_DIR="../ymls"
YML_DIR_PATH=""
INSTALL_YML_ENVS=false
BASE_PACKAGES_FILE="../base/base_packages.txt"
EXTRA_PACKAGES_FILE="../base/extra_packages.txt"
INSTALL_BASE_PACKAGES=false
LOCAL_INSTALL=false
SHARED_EXPORT_GROUP="seisbio-share"
INSTALL_SCRIPTS=false
SCRIPT_FILTER="all"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "General Installation of SEISbio"
    echo ""
    echo "Options:"
    echo "  -d, --distribution <miniforge|miniconda>  Select scientific software distribution. [default: miniforge]"
    echo "  --home <name>                             User and home directory to create for the distribution installation. [default: seisbio]"
    echo "                                            This will be created in /home/"
    echo "  --homeid <UID>                            Distribution user UID and GUID. [default: 1015]"
    echo "  --debian                                  Install basic and bioinformatic packages from Debian/Ubuntu repositories."
    echo "                                            The lists of packages are specified in the dev directory in SEISbio root directory."
    echo "  --debupgrade                              If specified, UPDATE Debian/Ubuntu system."
    echo "  --arch                                    Install packages from ArchLinux official repositories (arch_pks.txt)."
    echo "                                            The list of packages is specified in the arch/ directory in SEISbio root directory."
    echo "  --aur                                     Install AUR packages (aur_pks.txt)."
    echo "                                            The list of packages is specified in the arch/ directory in SEISbio root directory."
    echo "                                            WARNING: AUR packages require yay to be installed."
    echo "  -f, --envfile <file>                      File that specifies the virtual environments to create in SEISbio installation."
    echo "                                            [default: ./envs/virtual_envs.txt]. You can read the file specification in ./envs/virtual_envs.txt"
    echo "  -y, --yml, --yaml [dir]                    Install all conda environments from YAML files in a directory."
    echo "                                            Optional [dir]: folder containing .yml/.yaml files."
    echo "                                            Without [dir], uses default: ./ymls"
    echo "  -b, --base-packages [file]                Install base scientific packages. Optional: specify a custom file."
    echo "                                            Without [file], uses the default: ./base/base_packages.txt"
    echo "                                            Base packages are NOT installed unless this flag is used."
    echo "  --local                                   Prefers a local installation instead of a system wide installation. Does not need root access."
    echo "  -s, --scripts [names]                     Execute optional installation scripts found in the scripts/ directory."
    echo "                                            Without [names], executes all of them."
    echo "                                            Example: --scripts \"tutorial\" or --scripts \"tutorial snakepipes\""
    echo "  -h, --help                                Display this help message and exit."
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -d|--distribution)
            DISTRIBUTION="$2"
            shift
            ;;
        --home)
            HOME_DIR="$2"
            shift
            ;;
        --homeid)
            HOME_ID="$2"
            shift
            ;;
        --debian)
            DEBIAN_INSTALL=true
            ;;
        --debupgrade)
            DEB_UPGRADE=true
            ;;
        --arch)
            ARCH_INSTALL=true
            ;;
        --aur)
            AUR_INSTALL=true
            ;;
        -f|--envfile)
            ENV_FILE="$2"
            shift
            ;;
        -y|--yml|--yaml)
            INSTALL_YML_ENVS=true
            # Directory argument is optional: only consume next arg if it doesn't start with -
            if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
                YML_DIR="$2"
                shift
            fi
            ;;
        -b|--base-packages)
            INSTALL_BASE_PACKAGES=true
            # File argument is optional: only consume next arg if it doesn't start with -
            if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
                BASE_PACKAGES_FILE="$2"
                shift
            fi
            ;;
        --local)
            LOCAL_INSTALL=true
            ;;
        -s|--scripts)
            INSTALL_SCRIPTS=true
            if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
                SCRIPT_FILTER="$2"
                shift
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
    shift
done

# Validate distribution choice
if [[ "$DISTRIBUTION" != "miniforge" && "$DISTRIBUTION" != "miniconda" ]]; then
    echo "[WARN] Unrecognized distribution: $DISTRIBUTION"
    exit 1
fi

# Determine manager based on distribution
if [[ "$DISTRIBUTION" == "miniforge" ]]; then
    MANAGER="mamba"
elif [[ "$DISTRIBUTION" == "miniconda" ]]; then
    MANAGER="conda"
fi

# Auto-detect global bashrc path
if [[ -f "/etc/bash/bashrc" ]]; then
    GLOBAL_BASHRC="/etc/bash/bashrc"        # Gentoo
elif [[ -f "/etc/bashrc" ]]; then
    GLOBAL_BASHRC="/etc/bashrc"             # Fedora / RHEL / openSUSE
elif [[ -f "/etc/bash.bashrc" ]]; then
    GLOBAL_BASHRC="/etc/bash.bashrc"        # Debian / Ubuntu / Arch
else
    GLOBAL_BASHRC="/etc/bash.bashrc"        # fallback
fi

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Resolve envfile path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Resolve ENV_FILE_PATH intelligently
if [[ -n "$ENV_FILE" ]]; then
    if [[ "$ENV_FILE" == /* ]]; then
        # Absolute path - use as is
        ENV_FILE_PATH="$ENV_FILE"
        echo "     ... from absolute path:"
        echo "     ... $ENV_FILE_PATH"
    elif [[ "$ENV_FILE" == ../* ]] || [[ "$ENV_FILE" == ../envs/* ]]; then
        # Relative to script directory
        ENV_FILE_PATH="$SCRIPT_DIR/$ENV_FILE"
        echo "     ... from path relative to script:"
        echo "     ... $ENV_FILE_PATH"
    else
        # Relative to current working directory
        ENV_FILE_PATH="$(pwd)/$ENV_FILE"
        echo "     ... from current directory:"
        echo "     ... $ENV_FILE_PATH"
    fi
else
    ENV_FILE_PATH=""
fi

# Resolve YML_DIR_PATH intelligently (only when YAML installation is requested)
if [[ "$INSTALL_YML_ENVS" == "true" ]]; then
    if [[ "$YML_DIR" == /* ]]; then
        # Absolute path - use as is
        YML_DIR_PATH="$YML_DIR"
        echo "     ... YAML dir from absolute path:"
        echo "     ... $YML_DIR_PATH"
    elif [[ "$YML_DIR" == ../* ]]; then
        # Relative to script directory
        YML_DIR_PATH="$SCRIPT_DIR/$YML_DIR"
        echo "     ... YAML dir from path relative to script:"
        echo "     ... $YML_DIR_PATH"
    else
        # Relative to current working directory
        YML_DIR_PATH="$(pwd)/$YML_DIR"
        echo "     ... YAML dir from current directory:"
        echo "     ... $YML_DIR_PATH"
    fi
fi

# Function to read package lists from file
read_env_file() {
    local fname="$1"
    local pkg_list=()
    while IFS= read -r line; do
        # Trim leading/trailing whitespace without using xargs (avoids quote issues)
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi
        pkg_list+=("$line")
    done < "$fname"
    echo "${pkg_list[@]}"
}

# Configure shared group permissions so env-backup.sh can write without sudo.
configure_env_backup_permissions() {
    local home_user="$1"
    local yml_dir="/home/$home_user/ymls"
    local export_group="$SHARED_EXPORT_GROUP"
    local exporter_user=""

    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        exporter_user="$SUDO_USER"
    elif [[ "$CURRENT_USER" != "root" ]]; then
        exporter_user="$CURRENT_USER"
    fi

    echo "[INFO] Configuring shared permissions for env-backup exports"

    if ! getent group "$export_group" >/dev/null; then
        sudo groupadd "$export_group" || {
            echo "[ERROR] Failed to create shared group: $export_group"
            return 1
        }
    fi

    sudo usermod -aG "$export_group" "$home_user" || {
        echo "[ERROR] Failed to add '$home_user' to group '$export_group'"
        return 1
    }

    if [[ -n "$exporter_user" ]] && id "$exporter_user" &>/dev/null; then
        sudo usermod -aG "$export_group" "$exporter_user" || {
            echo "[ERROR] Failed to add '$exporter_user' to group '$export_group'"
            return 1
        }
    fi

    sudo mkdir -p "$yml_dir" || {
        echo "[ERROR] Failed to create directory: $yml_dir"
        return 1
    }

    sudo chown "$home_user:$export_group" "$yml_dir" || {
        echo "[ERROR] Failed to set ownership for: $yml_dir"
        return 1
    }

    # setgid on directory keeps group ownership for new exported files
    sudo chmod 2775 "$yml_dir" || {
        echo "[ERROR] Failed to set permissions for: $yml_dir"
        return 1
    }

    sudo find "$yml_dir" -type d -exec chmod g+s {} + 2>/dev/null || true
    sudo chmod -R g+rwX "$yml_dir" || {
        echo "[ERROR] Failed to apply group rw permissions in: $yml_dir"
        return 1
    }

    echo "[INFO] Shared export directory configured: $yml_dir"
    echo "[INFO] Shared group: $export_group"
    if [[ -n "$exporter_user" ]]; then
        echo "[INFO] Export user added to shared group: $exporter_user"
        echo "[INFO] Re-login may be required for new group membership to apply."
    fi
}

refresh_group_membership_session() {
    local login_user="$1"

    if [[ -z "$login_user" || "$login_user" == "root" ]]; then
        return
    fi

    # Only refresh automatically in interactive terminals.
    if [[ -t 0 && -t 1 ]]; then
        echo "[INFO] Refreshing login session for '$login_user' to apply new group membership..."
        echo "[INFO] If this is not desired, set SEISBIO_SKIP_SESSION_REFRESH=1 before running install."
        if [[ "${SEISBIO_SKIP_SESSION_REFRESH:-0}" != "1" ]]; then
            exec su -l "$login_user"
        fi
    fi
}

# Function to install Debian/Ubuntu bioinfo packages
debian_install_bioinfo() {
    local upgrade="$1"
    echo "[INFO] Installing bioinfo basic packages from Debian/Ubuntu repositories."
    echo "WARNING: Only for Debian/Ubuntu"

    if [[ "$upgrade" == "true" ]]; then
        echo "[INFO] Updating and upgrading system (Debian/Ubuntu)"
        sudo apt update || { echo "[ERROR] Failed to run apt update."; return 1; }
        sudo apt upgrade -y || { echo "[ERROR] Failed to run apt upgrade."; return 1; }
    fi

    local basic_file="$SCRIPT_DIR/../deb/basic_pkgs.txt"
    local bioinfo_file="$SCRIPT_DIR/../deb/bioinfo_pkgs.txt"

    local basic_pkgs=$(read_env_file "$basic_file")
    local bioinfo_pkgs=$(read_env_file "$bioinfo_file")

    echo "[INFO] Installing helping packages (Debian/Ubuntu)"
    IFS=' ' read -r -a basic_pkgs_arr <<< "$basic_pkgs"
    if ! sudo apt install -y "${basic_pkgs_arr[@]}"; then
        echo "[WARN] Bulk install failed, retrying one by one to skip missing packages..."
        for pkg in "${basic_pkgs_arr[@]}"; do
            sudo apt install -y "$pkg" || echo "[WARN] Package '$pkg' could not be installed, skipping."
        done
    fi

    echo "[INFO] Installing Bioinformatic programs from repositories (Debian/Ubuntu)"
    IFS=' ' read -r -a bioinfo_pkgs_arr <<< "$bioinfo_pkgs"
    if ! sudo apt install -y "${bioinfo_pkgs_arr[@]}"; then
        echo "[WARN] Bulk install failed, retrying one by one to skip missing packages..."
        for pkg in "${bioinfo_pkgs_arr[@]}"; do
            sudo apt install -y "$pkg" || echo "[WARN] Package '$pkg' could not be installed, skipping."
        done
    fi
}

# Function to install ArchLinux packages from official repositories
arch_install_packages() {
    echo "[INFO] Installing packages from ArchLinux official repositories."
    echo "WARNING: Only for ArchLinux-based systems"

    local arch_file="$SCRIPT_DIR/../arch/arch_pks.txt"

    local arch_pkgs=$(read_env_file "$arch_file")

    echo "[INFO] Installing packages from official repositories (pacman)"
    IFS=' ' read -r -a arch_pkgs_arr <<< "$arch_pkgs"
    if ! sudo pacman -S --needed --noconfirm "${arch_pkgs_arr[@]}"; then
        echo "[WARN] Bulk install failed, retrying one by one to skip missing packages..."
        for pkg in "${arch_pkgs_arr[@]}"; do
            sudo pacman -S --needed --noconfirm "$pkg" || echo "[WARN] Package '$pkg' could not be installed, skipping."
        done
    fi
}

# Function to install AUR packages
aur_install_packages() {
    echo "[INFO] Installing AUR packages."
    echo "WARNING: Only for ArchLinux-based systems"

    local aur_file="$SCRIPT_DIR/../arch/aur_pks.txt"

    if ! command -v yay &> /dev/null; then
        echo "[WARN] yay is not installed. AUR packages cannot be installed."
        echo "[WARN] Please install yay (https://github.com/Jguer/yay) and re-run with --aur to install AUR packages:"
        echo "       $aur_file"
        echo "[INFO] Skipping AUR package installation."
        return 0
    fi

    local aur_pkgs=$(read_env_file "$aur_file")

    echo "[INFO] Installing AUR packages with yay"
    IFS=' ' read -r -a aur_pkgs_arr <<< "$aur_pkgs"
    if [[ -n "$SUDO_USER" ]]; then
        if ! sudo -u "$SUDO_USER" yay -S --needed --noconfirm "${aur_pkgs_arr[@]}"; then
            echo "[WARN] Bulk AUR install failed, retrying one by one to skip missing packages..."
            for pkg in "${aur_pkgs_arr[@]}"; do
                sudo -u "$SUDO_USER" yay -S --needed --noconfirm "$pkg" || echo "[WARN] AUR package '$pkg' could not be installed, skipping."
            done
        fi
    else
        echo "[WARN] yay cannot run as root and SUDO_USER is not set. Skipping all AUR packages."
        echo "[INFO] Run manually: yay -S --needed ${aur_pkgs_arr[*]}"
    fi
}

# Function to download distribution installer
download_distribution() {
    local distribution="$1"
    local uid="$2"
    local home="$3"
    local urls_miniforge="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
    local urls_miniconda="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    local url=""

    if [[ "$distribution" == "miniforge" ]]; then
        url="$urls_miniforge"
    elif [[ "$distribution" == "miniconda" ]]; then
        url="$urls_miniconda"
    fi

    local filename
    filename=$(basename "$url")
    local dest="/home/$home/$filename"

    echo "[INFO] Downloading $distribution installer from $url" >&2

    # Skip download if file already exists (wget -N behavior)
    if [[ -f "$dest" ]]; then
        echo "[INFO] Installer already present at $dest, skipping download." >&2
        echo "$filename"
        return 0
    fi

    # Prefer curl: --progress-bar (-#) reliably shows progress to stderr in
    # non-TTY contexts (sudo -u, scripts, Incus VMs) without creating log files.
    # -L follows redirects (needed for GitHub releases), -f fails on HTTP errors.
    if command -v curl &>/dev/null; then
        echo "[INFO] Using curl to download..." >&2
        sudo -u "$home" curl -L -f --progress-bar -o "$dest" "$url" || {
            echo "[ERROR] Failed to download $distribution (curl)."
            exit 1
        }
    else
        # Fallback to wget. -q -o /dev/null --show-progress works on most systems;
        # on some distros (Fedora) --show-progress may be silenced in non-TTY shells.
        echo "[INFO] curl not found, falling back to wget..." >&2
        sudo -u "$home" wget -q -o /dev/null --show-progress -O "$dest" "$url" || {
            echo "[ERROR] Failed to download $distribution (wget)."
            exit 1
        }
    fi

    echo "$filename"
}

# Function to install distribution
install_distribution() {
    local installer="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"

    echo "[INFO] Installing $distribution to /home/$home/$distribution"
    sudo -u "$home" bash "/home/$home/$installer" -b -p "/home/$home/$distribution" || { echo "[ERROR] Failed to install $distribution."; exit 1; }

    echo "[INFO] Initializing conda for $distribution"
    sudo -u "$home" "/home/$home/$distribution/bin/conda" init || { echo "[ERROR] Failed to initialize conda."; exit 1; }
    
    echo "[INFO] Disabling automatic conda base activation"
    sudo -u "$home" "/home/$home/$distribution/bin/conda" config --set auto_activate_base false || { echo "[ERROR] Failed to disable auto_activate_base."; exit 1; }
}

# Function to update distribution
update_distribution() {
    local manager="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"

    echo "[INFO] Updating $distribution using $manager"
    # Run update as the target user with login shell using full path
    sudo -i -u "$home" bash -c "~/$distribution/bin/$manager update -y --all -q" || { echo "[ERROR] Failed to update $distribution."; exit 1; }
}

# Function to install base scientific packages
install_distribution_base() {
	local manager="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"
    local packages_file="$5"

    # Resolve relative path if needed
    if [[ "$packages_file" != /* ]]; then
        packages_file="$SCRIPT_DIR/$packages_file"
    fi

    if [[ ! -f "$packages_file" ]]; then
        echo "[ERROR] Base packages file not found: $packages_file"
        return 1
    fi

    echo "[INFO] Reading base packages from: $packages_file"
    local packages=$(read_env_file "$packages_file")
    
    if [[ -z "$packages" ]]; then
        echo "[WARN] No packages found in $packages_file (all commented out or empty)"
        echo "[INFO] Skipping base packages installation."
        return 0
    fi

    echo "[INFO] Installing base scientific packages into $distribution base environment"
    echo "[INFO] Packages to install: $packages"

     # Run install as the target user with login shell
    sudo -i -u "$home" bash -c "~/$distribution/bin/$manager install -y -q $packages" || { echo "[ERROR] Failed to install base packages."; return 1; }    
}

# Function to install extra packages (always installed)
install_extra_packages() {
    local manager="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"
    local packages_file="$5"

    if [[ "$packages_file" != /* ]]; then
        packages_file="$SCRIPT_DIR/$packages_file"
    fi

    if [[ ! -f "$packages_file" ]]; then
        echo "[ERROR] Extra packages file not found: $packages_file"
        return 1
    fi

    echo "[INFO] Reading extra packages from: $packages_file"
    local packages
    packages=$(read_env_file "$packages_file")

    if [[ -z "$packages" ]]; then
        echo "[WARN] No packages found in $packages_file (all commented out or empty)"
        echo "[INFO] Skipping extra packages installation."
        return 0
    fi

    echo "[INFO] Installing extra packages into $distribution base environment"
    echo "[INFO] Packages to install: $packages"
    sudo -i -u "$home" bash -c "~/$distribution/bin/$manager install -y -q -c conda-forge $packages" || {
        echo "[ERROR] Failed to install extra packages."
        return 1
    }
}

# Function to install environment from YAML file
install_env_from_yml() {
    local yml_file="$1"
    local manager="$2"
    local distribution="$3"
    local home="$4"
    local uid="$5"

    echo "[INFO] Installing environment from YAML file: $yml_file"
    
    # Resolve yml file path if relative
    local yml_path="$yml_file"
    if [[ "$yml_file" != /* ]]; then
        yml_path="$(pwd)/$yml_file"
    fi
    
    if [[ ! -f "$yml_path" ]]; then
        echo "[ERROR] YAML file not found: $yml_path"
        return 1
    fi
    
    # Extract environment name from YAML file
    local env_name=$(grep -E '^name:' "$yml_path" | head -1 | awk '{print $2}')
    
    if [[ -z "$env_name" ]]; then
        echo "[ERROR] Could not extract environment name from YAML file."
        echo "[INFO] Make sure the YAML file has a 'name:' field."
        return 1
    fi
    
    echo "[INFO] Environment name from YAML: $env_name"
    
    # Copy YAML file to seisbio's home to avoid permission issues
    local temp_yml="/home/$home/temp_env_${env_name}.yml"
    echo "[INFO] Copying YAML file to $temp_yml"
    sudo cp "$yml_path" "$temp_yml" || {
        echo "[ERROR] Failed to copy YAML file to seisbio home."
        return 1
    }
    sudo chown "$uid:$uid" "$temp_yml" || {
        echo "[ERROR] Failed to set ownership of temporary YAML file."
        return 1
    }
    
    # Check if environment already exists
    local env_info=$(sudo -i -u "$home" bash -c "~/$distribution/bin/conda env list" | awk '{print $1}')
    
    if [[ "$env_info" =~ "$env_name" ]]; then
        echo "[WARN] Environment '$env_name' already exists!"
        read -p "Do you want to remove and recreate it? y/[n]: " ANSWER_RECREATE
        if [[ "$ANSWER_RECREATE" == "y" ]]; then
            echo "[INFO] Removing existing environment: $env_name"
            sudo -i -u "$home" bash -c "~/$distribution/bin/conda env remove -n $env_name -y" || {
                echo "[ERROR] Failed to remove environment $env_name."
                sudo rm -f "$temp_yml"
                return 1
            }
        else
            echo "[INFO] Skipping installation of $env_name."
            sudo rm -f "$temp_yml"
            return 0
        fi
    fi
    
    # Install environment from YAML
    echo "[INFO] Creating environment '$env_name' from YAML file..."
    sudo -i -u "$home" bash -c "~/$distribution/bin/$manager env create -f ~/temp_env_${env_name}.yml" || {
        echo "[ERROR] Failed to create environment from YAML file."
        sudo rm -f "$temp_yml"
        return 1
    }
    
    # Clean up temporary file
    echo "[INFO] Cleaning up temporary YAML file..."
    sudo rm -f "$temp_yml"
    
    echo "[SUCCESS] Environment '$env_name' created successfully!"
    return 0
}

# Function to install environments from all YAML files in a directory
install_envs_from_yml_dir() {
    local yml_dir="$1"
    local manager="$2"
    local distribution="$3"
    local home="$4"
    local uid="$5"

    if [[ ! -d "$yml_dir" ]]; then
        echo "[ERROR] YAML directory not found: $yml_dir"
        return 1
    fi

    local failed=0
    local found=0

    shopt -s nullglob
    local yml_files=("$yml_dir"/*.yml "$yml_dir"/*.yaml)
    shopt -u nullglob

    if [[ ${#yml_files[@]} -eq 0 ]]; then
        echo "[ERROR] No .yml or .yaml files found in: $yml_dir"
        return 1
    fi

    echo "[INFO] Found ${#yml_files[@]} YAML file(s) in $yml_dir"

    for yml_file in "${yml_files[@]}"; do
        found=1
        echo "====================="
        echo "[INFO] Processing YAML file: $yml_file"
        if ! install_env_from_yml "$yml_file" "$manager" "$distribution" "$home" "$uid"; then
            echo "[ERROR] Failed installing environment from: $yml_file"
            failed=1
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        echo "[ERROR] No YAML files were processed."
        return 1
    fi

    if [[ "$failed" -ne 0 ]]; then
        echo "[ERROR] One or more YAML environments failed to install."
        return 1
    fi

    echo "[SUCCESS] All YAML environments installed successfully."
    return 0
}

# Function to install virtual environments
install_virtual_envs() {
    local pkg_list_str="$1"
    local manager="$2"
    local distribution="$3"
    local home="$4"
    local uid="$5"
    local snakepipes_installer="$SCRIPT_DIR/../scripts/install_snakepipes.sh"

    IFS=' ' read -r -a pkg_list <<< "$pkg_list_str" # Convert string back to array

    local home_path="/home/$home/"

    echo "[INFO] Installing virtual environments for bioinformatics programs."

    # Get existing environments as the target user (using login shell)
    local env_info=$(sudo -i -u "$home" bash -c "~/$distribution/bin/conda env list" | awk '{print $1}')

    for pkg in "${pkg_list[@]}"; do
        local envname=""
        if [[ "$pkg" == *"="* ]]; then
            local pkname=$(echo "$pkg" | cut -d'=' -f1)
            local version=$(echo "$pkg" | cut -d'=' -f2 | tr -d '.')
            envname="${pkname}${version}-env"
        else
            envname="${pkg}-env"
        fi

        if [[ ! "$env_info" =~ "$envname" ]]; then
            echo "[INSTALLING] Environment for $envname package"
            local pkgs_to_install="$pkg"
            local channels="-c bioconda -c conda-forge"
            local pkg_base="${pkg%%=*}"

            # Conditional cases (similar to Python script)
            if [[ "$envname" == *"hicexplorer"* ]]; then
                pkgs_to_install="$pkg hic2cool"

            fi

            # Use sudo -i -u to run in a login shell with proper conda initialization
        sudo -i -u "$home" bash -c "cd /home/$home && ~/$distribution/bin/$manager create -n $envname $channels $pkgs_to_install -y -q" || { echo "[ERROR] Failed to create $envname."; continue; }
    else
            echo "[NOT INSTALLING] $envname: already installed!"
        fi
    done
}

# Function to update global bashrc
update_bashrc() {
    local home="$1"
    local distribution="$2"

    echo "[INFO] Detected global bashrc: $GLOBAL_BASHRC"
    echo "[INFO] Backing up $GLOBAL_BASHRC to ${GLOBAL_BASHRC}.backup"
    sudo cp "$GLOBAL_BASHRC" "${GLOBAL_BASHRC}.backup" || { echo "[ERROR] Failed to backup $GLOBAL_BASHRC."; exit 1; }
    echo -e "\n\n# --- Backup of $GLOBAL_BASHRC created\n# --- by SEISbio installation" | sudo tee -a "${GLOBAL_BASHRC}.backup" > /dev/null

    echo "[INFO] Extracting conda initialization script from /home/$home/.bashrc"
    local conda_text=$(sudo -u "$home" cat "/home/$home/.bashrc" | sed -n '/# >>> conda initialize >>>/,/# <<< conda initialize <<</p')

    if [[ -z "$conda_text" ]]; then
        echo "[WARN] Something is wrong with /home/$home/.bashrc file! Could not find conda initialization block."
        echo "[EXIT!] Exiting program."
        exit 1
    fi

    echo "[INFO] Appending conda initialization to $GLOBAL_BASHRC"
    echo -e "\n\n# --- Added by SEISbio\n$conda_text" | sudo tee -a "$GLOBAL_BASHRC" > /dev/null
}

# Function to verify input files before starting installation
verify_input_files() {
    local errors=0
    
    echo "[INFO] Verifying input files..."
    echo "[DEBUG] SCRIPT_DIR = $SCRIPT_DIR"
    
    # Verify ENV_FILE if not empty
    if [[ -n "$ENV_FILE" && "$ENV_FILE" != "" ]]; then
        if [[ ! -f "$ENV_FILE_PATH" ]]; then
            echo "[ERROR] Environment file not found: $ENV_FILE_PATH"
            errors=$((errors + 1))
        else
            echo "[OK] Environment file found: $ENV_FILE_PATH"
        fi
    fi
    
    # Verify BASE_PACKAGES_FILE only if -b was specified
    if [[ "$INSTALL_BASE_PACKAGES" == "true" ]]; then
        local base_pkg_path="$BASE_PACKAGES_FILE"
        # If relative path, prepend SCRIPT_DIR
        if [[ "$BASE_PACKAGES_FILE" != /* ]]; then
            base_pkg_path="$SCRIPT_DIR/$BASE_PACKAGES_FILE"
        fi
        
        if [[ ! -f "$base_pkg_path" ]]; then
            echo "[ERROR] Base packages file not found: $base_pkg_path"
            errors=$((errors + 1))
        else
            echo "[OK] Base packages file found: $base_pkg_path"
        fi
    else
        echo "[INFO] Base packages installation skipped (use -b to enable)"
    fi

    # Verify extra packages file (always required)
    local extra_file="$EXTRA_PACKAGES_FILE"
    if [[ "$extra_file" != /* ]]; then
        extra_file="$SCRIPT_DIR/$extra_file"
    fi
    if [[ ! -f "$extra_file" ]]; then
        echo "[ERROR] Extra packages file not found: $extra_file"
        errors=$((errors + 1))
    else
        echo "[OK] Extra packages file found: $extra_file"
    fi
    
    # Verify YAML directory and its files if --yml/--yaml was specified
    if [[ "$INSTALL_YML_ENVS" == "true" ]]; then
        if [[ ! -d "$YML_DIR_PATH" ]]; then
            echo "[ERROR] YAML directory not found: $YML_DIR_PATH"
            errors=$((errors + 1))
        else
            echo "[OK] YAML directory found: $YML_DIR_PATH"
            shopt -s nullglob
            local yml_files=("$YML_DIR_PATH"/*.yml "$YML_DIR_PATH"/*.yaml)
            shopt -u nullglob
            if [[ ${#yml_files[@]} -eq 0 ]]; then
                echo "[ERROR] No .yml or .yaml files found in: $YML_DIR_PATH"
                errors=$((errors + 1))
            else
                echo "[OK] Found ${#yml_files[@]} YAML file(s) in: $YML_DIR_PATH"
            fi
        fi
    fi
    
    # Verify Debian package files if --debian specified
    if [[ "$DEBIAN_INSTALL" == "true" ]]; then
        local basic_file="$SCRIPT_DIR/../deb/basic_pkgs.txt"
        local bioinfo_file="$SCRIPT_DIR/../deb/bioinfo_pkgs.txt"
        
        if [[ ! -f "$basic_file" ]]; then
            echo "[ERROR] Debian basic packages file not found: $basic_file"
            errors=$((errors + 1))
        else
            echo "[OK] Debian basic packages file found: $basic_file"
        fi
        
        if [[ ! -f "$bioinfo_file" ]]; then
            echo "[ERROR] Debian bioinfo packages file not found: $bioinfo_file"
            errors=$((errors + 1))
        else
            echo "[OK] Debian bioinfo packages file found: $bioinfo_file"
        fi
    fi
    
    # Verify Arch package files if --arch specified
    if [[ "$ARCH_INSTALL" == "true" ]]; then
        local arch_file="$SCRIPT_DIR/../arch/arch_pks.txt"
        
        if [[ ! -f "$arch_file" ]]; then
            echo "[ERROR] Arch packages file not found: $arch_file"
            errors=$((errors + 1))
        else
            echo "[OK] Arch packages file found: $arch_file"
        fi
    fi
    
    # Verify AUR package files if --aur specified
    if [[ "$AUR_INSTALL" == "true" ]]; then
        local aur_file="$SCRIPT_DIR/../arch/aur_pks.txt"
        
        if [[ ! -f "$aur_file" ]]; then
            echo "[ERROR] AUR packages file not found: $aur_file"
            errors=$((errors + 1))
        else
            echo "[OK] AUR packages file found: $aur_file"
        fi
    fi
    
    # Exit if any errors were found
    if [[ $errors -gt 0 ]]; then
        echo ""
        echo "[FATAL] Found $errors error(s) in input files verification."
        echo "[EXIT] Please fix the errors and try again."
        exit 1
    fi
    
    echo "[OK] All input files verified successfully."
    echo ""
}

# Main logic
main() {
    # Verify all input files before starting
    verify_input_files
    
    # Check if YAML directory is specified and seisbio already exists
    if [[ "$INSTALL_YML_ENVS" == "true" ]] && [[ -d "/home/$HOME_DIR" ]] && [[ -d "/home/$HOME_DIR/$DISTRIBUTION" ]]; then
        echo "[INFO] YAML directory specified and SEISbio installation detected."
        echo "[INFO] Installing all environments from YAML directory (no system recreation)."
        echo "====================="
        
        install_envs_from_yml_dir "$YML_DIR_PATH" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        
        if [[ $? -eq 0 ]]; then
            echo "[END] YAML environments installation completed."
        else
            echo "[ERROR] Failed to install environments from YAML directory."
            exit 1
        fi
        exit 0
    fi

    # Check if ENV_FILE is specified and seisbio already exists -> only install envs
    if [[ -n "$ENV_FILE" ]] && [[ -d "/home/$HOME_DIR" ]] && [[ -d "/home/$HOME_DIR/$DISTRIBUTION" ]]; then
        echo "[INFO] Environment file specified and SEISbio installation detected."
        echo "[INFO] Installing only virtual environments (no system recreation)."
        echo "====================="

        ENV_LIST=$(read_env_file "$ENV_FILE_PATH")
        install_virtual_envs "$ENV_LIST" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"

        echo "[END] Virtual environments installation completed."
        exit 0
    fi
    
    # If YAML directory specified but seisbio doesn't exist, warn and proceed with full installation
    if [[ "$INSTALL_YML_ENVS" == "true" ]] && [[ ! -d "/home/$HOME_DIR/$DISTRIBUTION" ]]; then
        echo "[INFO] YAML directory specified but SEISbio not installed yet."
        echo "[INFO] Will perform full SEISbio installation first, then install all YAML environments."
        echo "====================="
    fi
    
    if [[ "$LOCAL_INSTALL" == "true" ]]; then
        echo "[INFO] Installing system locally"
        echo "[INFO] in user $CURRENT_USER (uid: $CURRENT_UID, gid: $CURRENT_GID)"
        HOME_DIR="$CURRENT_USER"
        HOME_ID="$CURRENT_UID"
        # Call local installation function (simplified for now)
        # The original Python script had a separate 'install' function for local,
        # but the core logic is similar. We'll integrate it here.

        echo "[INFO] Downloading $DISTRIBUTION distribution."
        INSTALLER_FILENAME=$(download_distribution "$DISTRIBUTION" "$HOME_ID" "$HOME_DIR")

        if [[ ! -d "/home/$HOME_DIR/$DISTRIBUTION" ]]; then
            echo "[INFO] Installing $DISTRIBUTION."
            install_distribution "$INSTALLER_FILENAME" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
            INSTALLED=false
        else
            INSTALLED=true
            echo "[INFO] $DISTRIBUTION already installed."
        fi

        if [[ "$INSTALLED" == "true" ]]; then
            read -p "Do you want to update base $DISTRIBUTION installation? y/[n]: " ANSWER_INSTALLED
            if [[ "$ANSWER_INSTALLED" == "y" ]]; then
                echo "[INFO] Updating anaconda and installing basic packages."
                update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
                if [[ "$INSTALL_BASE_PACKAGES" == "true" ]]; then
                    echo "[INFO] Installing base scientific packages."
                    install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$BASE_PACKAGES_FILE"
                else
                    echo "[INFO] Skipping base packages installation (use -b to enable)."
                fi
            elif [[ "$ANSWER_INSTALLED" == "n" ]]; then
                echo "[INFO] Continue with envs installation!"
            else
                echo "[END] Invalid answer: exit!"
                exit 1
            fi
        else
            echo "[INFO] Updating anaconda and installing basic packages."
            update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
            if [[ "$INSTALL_BASE_PACKAGES" == "true" ]]; then
                echo "[INFO] Installing base scientific packages."
                install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$BASE_PACKAGES_FILE"
            else
                echo "[INFO] Skipping base packages installation (use -b to enable)."
            fi
        fi

        if ! install_extra_packages "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$EXTRA_PACKAGES_FILE"; then
            exit 1
        fi

        if [[ -n "$ENV_FILE" ]]; then
            echo "[INFO] virtual envs."
            ENV_LIST=$(read_env_file "$ENV_FILE_PATH")
            install_virtual_envs "$ENV_LIST" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        else
            echo "[INFO] No virtual environments file specified, skipping."
        fi
        
        # Install YAML environments if specified
        if [[ "$INSTALL_YML_ENVS" == "true" ]]; then
            echo "====================="
            echo "[INFO] Installing additional environments from YAML directory."
            install_envs_from_yml_dir "$YML_DIR_PATH" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        fi

        # Execute additional scripts if specified
        if [[ "$INSTALL_SCRIPTS" == "true" ]]; then
            echo "====================="
            if [[ "$SCRIPT_FILTER" == "all" ]]; then
                echo "[INFO] Executing all additional scripts in scripts/ directory"
            else
                echo "[INFO] Executing selected scripts containing: '$SCRIPT_FILTER'"
            fi
            
            for script in "$SCRIPT_DIR/../scripts/"*.sh; do
                script_name=$(basename "$script" .sh)
                short_name=${script_name#install_}
                
                if [[ "$SCRIPT_FILTER" != "all" ]]; then
                    if [[ ! "$SCRIPT_FILTER" =~ "$short_name" && ! "$SCRIPT_FILTER" =~ "$script_name" ]]; then
                        continue
                    fi
                fi
                
                if [[ -x "$script" ]]; then
                    echo "[RUN] Executing $(basename "$script")"
                    "$script" \
                        --manager "$MANAGER" \
                        --distribution "$DISTRIBUTION" \
                        --home "$HOME_DIR" || {
                        echo "[ERROR] $(basename "$script") failed."
                    }
                elif [[ -f "$script" ]]; then
                    echo "[WARN] Script not executable: $(basename "$script")"
                fi
            done
        fi
        
        echo "[END] All packages installed"

        exit 0
    else
        if [[ "$CURRENT_UID" -ne 0 ]]; then
            echo "[INFO] You need to be root to install SEIS system wide or use --local flag for local installation."
            echo "       You are $CURRENT_USER!"
            echo "[END] Ending program."
            exit 1
        fi
    fi

    echo "============ Installing as root"
    if [[ "$DEBIAN_INSTALL" == "true" ]]; then
        echo "[START] Installing system packages for Debian/Ubuntu."
        debian_install_bioinfo "$DEB_UPGRADE" || { echo "[ERROR] Debian package installation failed."; exit 1; }
    fi

    if [[ "$ARCH_INSTALL" == "true" ]]; then
        echo "[START] Installing system packages for ArchLinux."
        arch_install_packages || { echo "[ERROR] Arch package installation failed."; exit 1; }
    fi

    if [[ "$AUR_INSTALL" == "true" ]]; then
        echo "[START] Installing AUR packages for ArchLinux."
        aur_install_packages || { echo "[ERROR] AUR package installation failed."; exit 1; }
    fi

    # Creating seisbio user
    echo "[INFO] Creating $HOME_DIR user if not exists."
    if [[ ! -d "/home/$HOME_DIR" ]] && ! id "$HOME_DIR" &>/dev/null; then
        echo "[INFO] Creating $HOME_DIR user and asking for a password."
        echo "====================="
        # useradd only works this way in Debian distros
        # ArchLinux : install adduser-deb from AUR
        # cmd_create = f"""adduser --shell /bin/bash --uid 1015 --gecos '' {args.home}""".split()
        # run(cmd_create)
        sudo useradd -s /bin/bash -u "$HOME_ID" -m "$HOME_DIR" || { echo "[ERROR] Failed to create user $HOME_DIR."; exit 1; }
        # password
        echo "[INFO] Configuring $HOME_DIR user."
        echo "[INPUT] Enter $HOME_DIR user password:"
        sudo passwd "$HOME_DIR" || { echo "[ERROR] Failed to set password for $HOME_DIR."; exit 1; }
        # permissions
        sudo chmod -R go+r "/home/$HOME_DIR" || { echo "[ERROR] Failed to set permissions for $HOME_DIR."; exit 1; }
        sudo chmod go+x "/home/$HOME_DIR" || { echo "[ERROR] Failed to set permissions for $HOME_DIR."; exit 1; }
        
        # Configure sudo access for build_container.sh
        echo "[INFO] Configuring sudo access for build_container.sh"
        sudo bash -c "echo '$HOME_DIR ALL=(ALL) NOPASSWD: /home/$HOME_DIR/build_container.sh' > /etc/sudoers.d/$HOME_DIR"
        sudo chmod 440 "/etc/sudoers.d/$HOME_DIR"

        echo "====================="
        echo "[INFO] $HOME_DIR user created"
        echo "====================="
    else
        echo "[WARN] $HOME_DIR user already exists!!!"
        echo "[INFO] Consider to delete this user: \$ sudo userdel -r $HOME_DIR"
        read -p "Do you want to continue? y/[n]: " ANSWER
        if [[ "$ANSWER" == "y" ]]; then
            echo "[INFO] Continue installation"
        elif [[ "$ANSWER" == "n" ]]; then
            echo "[END] Exit program doing nothing more!"
            exit 0
        else
            echo "[END] Invalid answer: exit!"
            exit 1
        fi
    fi

    configure_env_backup_permissions "$HOME_DIR" || {
        echo "[ERROR] Could not configure shared permissions for env-backup.sh"
        exit 1
    }

    echo "[INFO] Moving to $HOME_DIR home"
    # No need to chdir in bash for subsequent commands if we use absolute paths or sudo -u
    # os.chdir(f'/home/{args.home}/')
    echo "====================="
    echo "[INFO] Downloading $DISTRIBUTION distribution"

    INSTALLER_FILENAME=$(download_distribution "$DISTRIBUTION" "$HOME_ID" "$HOME_DIR")

    if [[ ! -d "/home/$HOME_DIR/$DISTRIBUTION" ]]; then
        echo "[INFO] Installing $DISTRIBUTION."
        install_distribution "$INSTALLER_FILENAME" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        echo "[INFO] Updating /etc/bash.bashrc"
        update_bashrc "$HOME_DIR" "$DISTRIBUTION"
        INSTALLED=false
    else
        INSTALLED=true
        echo "[INFO] $DISTRIBUTION already installed."
    fi

    if [[ "$INSTALLED" == "true" ]]; then
        read -p "Do you want to update base $DISTRIBUTION installation? y/[n]: " ANSWER_INSTALLED
        if [[ "$ANSWER_INSTALLED" == "y" ]]; then
            echo "[INFO] Updating anaconda and installing basic packages."
            update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
            if [[ "$INSTALL_BASE_PACKAGES" == "true" ]]; then
                echo "[INFO] Installing base scientific packages."
                install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$BASE_PACKAGES_FILE"
            else
                echo "[INFO] Skipping base packages installation (use -b to enable)."
            fi
        elif [[ "$ANSWER_INSTALLED" == "n" ]]; then
            echo "[INFO] Continue with envs installation!"
        else
            echo "[END] Invalid answer: exit!"
            exit 1
        fi
    else
        echo "[INFO] Updating anaconda and installing basic packages."
        update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        if [[ "$INSTALL_BASE_PACKAGES" == "true" ]]; then
            echo "[INFO] Installing base scientific packages."
            install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$BASE_PACKAGES_FILE"
        else
            echo "[INFO] Skipping base packages installation (use -b to enable)."
        fi
    fi

    if ! install_extra_packages "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID" "$EXTRA_PACKAGES_FILE"; then
        exit 1
    fi

    if [[ -n "$ENV_FILE" ]]; then
        echo "[INFO] virtual envs."
        ENV_LIST=$(read_env_file "$ENV_FILE_PATH")
        install_virtual_envs "$ENV_LIST" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
    else
        echo "[INFO] No virtual environments file specified, skipping."
    fi
    
    # Install YAML environments if specified
    if [[ "$INSTALL_YML_ENVS" == "true" ]]; then
        echo "====================="
        echo "[INFO] Installing additional environments from YAML directory."
        install_envs_from_yml_dir "$YML_DIR_PATH" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
    fi

    # Execute additional scripts if specified
    if [[ "$INSTALL_SCRIPTS" == "true" ]]; then
        echo "====================="
        if [[ "$SCRIPT_FILTER" == "all" ]]; then
            echo "[INFO] Executing all additional scripts in scripts/ directory"
        else
            echo "[INFO] Executing selected scripts containing: '$SCRIPT_FILTER'"
        fi
        
        for script in "$SCRIPT_DIR/../scripts/"*.sh; do
            script_name=$(basename "$script" .sh)
            short_name=${script_name#install_}
            
            if [[ "$SCRIPT_FILTER" != "all" ]]; then
                if [[ ! "$SCRIPT_FILTER" =~ "$short_name" && ! "$SCRIPT_FILTER" =~ "$script_name" ]]; then
                    continue
                fi
            fi
            
            if [[ -x "$script" ]]; then
                echo "[RUN] Executing $(basename "$script")"
                "$script" \
                    --manager "$MANAGER" \
                    --distribution "$DISTRIBUTION" \
                    --home "$HOME_DIR" || {
                    echo "[ERROR] $(basename "$script") failed."
                }
            elif [[ -f "$script" ]]; then
                echo "[WARN] Script not executable: $(basename "$script")"
            fi
        done
    fi
    
    echo "[END] All packages installed"

    refresh_group_membership_session "$SUDO_USER"
}

# Call main function
main
