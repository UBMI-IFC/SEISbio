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
ENV_FILE="virtual_envs.txt"
LOCAL_INSTALL=false

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
    echo "  -f, --envfile <file>                      File that specifies the virtual environments to create in SEISbio installation."
    echo "                                            [default: ./virtual_envs.txt]. You can read the file specification in ./virtual_envs.txt"
    echo "  --local                                   Prefers a local installation instead of a system wide installation. Does not need root access."
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
        -f|--envfile)
            ENV_FILE="$2"
            shift
            ;;
        --local)
            LOCAL_INSTALL=true
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

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Resolve envfile path
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ "$ENV_FILE" == "virtual_envs.txt" ]]; then
    ENV_FILE_PATH="$SCRIPT_DIR/$ENV_FILE"
    echo "     ... from default file:"
    echo "     ... $ENV_FILE_PATH"
else
    ENV_FILE_PATH="$(pwd)/$ENV_FILE"
    echo "     ... from file:"
    echo "     ... $ENV_FILE_PATH"
fi

# Function to read package lists from file
read_env_file() {
    local fname="$1"
    local pkg_list=()
    while IFS= read -r line; do
        line=$(echo "$line" | xargs) # Trim whitespace
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi
        # For now, only single package per line is supported, similar to Python script
        pkg_list+=("$line")
    done < "$fname"
    echo "${pkg_list[@]}"
}

# Function to install Debian/Ubuntu bioinfo packages
debian_install_bioinfo() {
    local upgrade="$1"
    echo "[INFO] Installing bioinfo basic packages from Debian/Ubuntu repositories."
    echo "WARNING: Only for Debian/Ubuntu"

    if [[ "$upgrade" == "true" ]]; then
        echo "[INFO] Updating and upgrading system (Debian/Ubuntu)"
        sudo apt update
        sudo apt upgrade -y
    fi

    local basic_file="$SCRIPT_DIR/deb/basic_pkgs.txt"
    local bioinfo_file="$SCRIPT_DIR/deb/bioinfo_pkgs.txt"

    local basic_pkgs=$(read_env_file "$basic_file")
    local bioinfo_pkgs=$(read_env_file "$bioinfo_file")

    echo "[INFO] Installing helping packages (Debian/Ubuntu)"
    sudo apt install -y $basic_pkgs

    echo "[INFO] Installing Bioinformatic programs from repositories (Debian/Ubuntu)"
    sudo apt install -y $bioinfo_pkgs
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

    echo "[INFO] Downloading $distribution installer from $url"
    # Use sudo -u to download as the target user
    sudo -u "#$uid" wget -N "$url" -P "/home/$home" || { echo "[ERROR] Failed to download $distribution."; exit 1; }
    echo "$url" | awk -F'/' '{print $NF}' # Return filename
}

# Function to install distribution
install_distribution() {
    local installer="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"

    echo "[INFO] Installing $distribution to /home/$home/$distribution"
    # Run installer as the target user
    sudo -u "#$uid" bash "/home/$home/$installer" -b -p "/home/$home/$distribution" || { echo "[ERROR] Failed to install $distribution."; exit 1; }

    echo "[INFO] Initializing conda for $distribution"
    # Initialize conda as the target user
    sudo -u "#$uid" "/home/$home/$distribution/bin/conda" init || { echo "[ERROR] Failed to initialize conda."; exit 1; }
}

# Function to update distribution
update_distribution() {
    local manager="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"

    echo "[INFO] Updating $distribution using $manager"
    # Run update as the target user
    sudo -u "#$uid" "/home/$home/$distribution/bin/$manager" update -p "/home/$home/$distribution" -y --all -q || { echo "[ERROR] Failed to update $distribution."; exit 1; }
}

# Function to install base scientific packages
install_distribution_base() {
    local manager="$1"
    local distribution="$2"
    local home="$3"
    local uid="$4"

    echo "[INFO] Installing base scientific packages into $distribution base environment"
    # Packages list
    local packages="numpy scipy matplotlib pandas statsmodels seaborn biopython scikit-learn scikit-image networkx jupyter tensorflow keras jupyterlab jupyter-lsp jupyterlab-lsp jupyter-lsp-python r-base r-tidyverse r-irkernel jupyter-lsp-r radian"

    # Run install as the target user
    sudo -u "#$uid" "/home/$home/$distribution/bin/$manager" install -p "/home/$home/$distribution" -y -q $packages || { echo "[ERROR] Failed to install base packages."; exit 1; }
}

# Function to install virtual environments
install_virtual_envs() {
    local pkg_list_str="$1"
    local manager="$2"
    local distribution="$3"
    local home="$4"
    local uid="$5"

    IFS=' ' read -r -a pkg_list <<< "$pkg_list_str" # Convert string back to array

    local manager_path="/home/$home/$distribution/bin/$manager"
    local home_path="/home/$home/"

    echo "[INFO] Installing virtual environments for bioinformatics programs."

    # Get existing environments as the target user
    local env_info=$(sudo -u "#$uid" "$manager_path" env list | awk '{print $1}')

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
            local create_cmd_base="$manager_path create -n $envname -c bioconda -c conda-forge"

            # Conditional cases (similar to Python script)
            if [[ "$envname" == *"hicexplorer"* ]]; then
                pkgs_to_install="$pkg hic2cool"
            elif [[ "$pkg" == "snakePipes" ]]; then
                create_cmd_base="$manager_path create -n snakePipes -c mpi-ie"
                pkgs_to_install="snakePipes"
            fi

            sudo -u "#$uid" "$create_cmd_base" "$pkgs_to_install" -y -q || { echo "[ERROR] Failed to create $envname."; continue; }
        else
            echo "[NOT INSTALLING] $envname: already installed!"
        fi
    done
}

# Function to update /etc/bash.bashrc
update_bashrc() {
    local home="$1"
    local distribution="$2"

    echo "[INFO] Backing up /etc/bash.bashrc to /etc/bash.bashrc.backup"
    sudo cp /etc/bash.bashrc /etc/bash.bashrc.backup || { echo "[ERROR] Failed to backup bash.bashrc."; exit 1; }
    echo -e "\n\n# --- Backup of /bash.bashrc created\n# --- by SEISbio installation" | sudo tee -a /etc/bash.bashrc.backup > /dev/null

    echo "[INFO] Extracting conda initialization script from /home/$home/.bashrc"
    local conda_text=$(sudo -u "#$HOME_ID" cat "/home/$home/.bashrc" | sed -n '/# >>> conda initialize >>>/,/# <<< conda initialize <<<p> {p; /# <<< conda initialize <<<p> q}')

    if [[ -z "$conda_text" ]]; then
        echo "[WARN] Something is wrong with /home/$home/.bashrc file! Could not find conda initialization block."
        echo "[EXIT!] Exiting program."
        exit 1
    fi

    echo "[INFO] Appending conda initialization to /etc/bash.bashrc"
    echo -e "\n\n# --- Added by SEISbio\n$conda_text" | sudo tee -a /etc/bash.bashrc > /dev/null
}

# Main logic
main() {
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
                echo "[INFO] Installing scientific packages."
                install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
            elif [[ "$ANSWER_INSTALLED" == "n" ]]; then
                echo "[INFO] Continue with envs installation!"
            else
                echo "[END] Invalid answer: exit!"
                exit 1
            fi
        else
            echo "[INFO] Updating anaconda and installing basic packages."
            update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
            echo "[INFO] Installing base scientific packages."
            install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        fi

        echo "[INFO] virtual envs."
        ENV_LIST=$(read_env_file "$ENV_FILE_PATH")
        install_virtual_envs "$ENV_LIST" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
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
        debian_install_bioinfo "$DEB_UPGRADE"
    fi

    # Creating seisbio user
    echo "[INFO] Creating $HOME_DIR user if not exists."
    if [[ ! -d "/home/$HOME_DIR" ]]; then
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
            echo "[INFO] Installing base scientific packages."
            install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        elif [[ "$ANSWER_INSTALLED" == "n" ]]; then
            echo "[INFO] Continue with envs installation!"
        else
            echo "[END] Invalid answer: exit!"
            exit 1
        fi
    else
        echo "[INFO] Updating anaconda and installing basic packages."
        update_distribution "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
        echo "[INFO] Installing base scientific packages."
        install_distribution_base "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
    fi

    echo "[INFO] virtual envs."
    ENV_LIST=$(read_env_file "$ENV_FILE_PATH")
    install_virtual_envs "$ENV_LIST" "$MANAGER" "$DISTRIBUTION" "$HOME_DIR" "$HOME_ID"
    echo "[END] All packages installed"
}

# Call main function
main
