#!/bin/bash

#Uninstallation of SEISbio

USERNAME="seisbio"
BASHRC_PATH="/etc/bash.bashrc"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Function to remove seisbio user

remove_seisbio_user() {
	local username="$1"
	echo "[INFO] Attempting to remove user: $username"

	if id "$username" &>/dev/null; then 
		if userdel -r "$username" 2>/dev/null; then 
			echo "[INFO] User '$username' removed succesfully."
		else 
			echo "[ERROR] Failed to remove user '$username'."
			echo "[ERROR] This might happen if the user is logged in or if processes are running as this user."
			echo "[INFO] Try logging all sessions for user '$username', and try again."
			return 1
		fi
	else 
		echo "[INFO] User '$username' does not exist. Nothing to do."
	fi
}

revert_bashrc_changes() {
	local bashrc_path="$1"
	echo "[INFO] Attempting to revert changes in $bashrc_path"

	if [[ ! -f "$bashrc_path" ]]; then 
		echo "[ERROR] File not found: $bashrc_path. Cannot revert changes."
		return 1
	fi

	# Create a backup before modifying
	if [[ ! -f "${bashrc_path}.seisbio_backup" ]]; then
		cp "$bashrc_path" "${bashrc_path}.seisbio_backup" || {
			echo "[ERROR] Failed to create backup ogf $bashrc_path"
			return 1
		}
		echo "[INFO] Backup created: ${bashrc_path}.seisbio_backup"
	fi

	# Check if SEISbio block exists 
	if grep -q "# --- Added by SEISbio" "$bashrc_path"; then 
		# Remove the SEISbio block using sed 
		sed -i '/# --- Added by SEISbio/,/# <<< conda initialize <<</d' "$bashrc_path"
		echo "[INFO] Changes in $bashrc_path reverted successfully." 
	else
		echo "[INFO] No SEISbio related changes found in $bashrc_path ."
	fi
	
	# Restore backup if exists
	if [[ -f "/etc/bash.bashrc.backup" ]]; then 
		echo "[INFO] Found original backup at /etc/bash.bashrc.backup"
		echo "[INFO] You may to restore it manually if needed"
	fi
}

# Function to remove Debian/Ubuntu packages

remove_debian_packages() {
    local basic_file="$SCRIPT_DIR/../deb/basic_pkgs.txt"
    local bioinfo_file="$SCRIPT_DIR/../deb/bioinfo_pkgs.txt"

    for pkg_file in "$basic_file" "$bioinfo_file"; do
        if [[ ! -f "$pkg_file" ]]; then
            echo "[WARN] Package file not found: $pkg_file, skipping."
            continue
        fi
        echo "[INFO] Removing packages listed in $pkg_file"
        while IFS= read -r line; do
            line=$(echo "$line" | xargs)
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            apt remove -y "$line" 2>/dev/null || echo "[WARN] Could not remove package '$line', skipping."
        done < "$pkg_file"
    done
    echo "[INFO] Running apt autoremove..."
    apt autoremove -y
}

# Function to remove Arch/AUR packages

remove_arch_packages() {
    local arch_file="$SCRIPT_DIR/../arch/arch_pks.txt"
    local aur_file="$SCRIPT_DIR/../arch/aur_pks.txt"

    # Remove AUR packages first (with yay)
    if command -v yay &> /dev/null; then
        if [[ -f "$aur_file" ]]; then
            echo "[INFO] Removing AUR packages listed in $aur_file"
            local aur_pkgs
            while IFS= read -r line; do
                line=$(echo "$line" | xargs)
                [[ -z "$line" || "$line" =~ ^# ]] && continue
                aur_pkgs+=("$line")
            done < "$aur_file"
            for pkg in "${aur_pkgs[@]}"; do
                if [[ -n "$SUDO_USER" ]]; then
                    sudo -u "$SUDO_USER" yay -Rns --noconfirm "$pkg" 2>/dev/null || echo "[WARN] Could not remove AUR package '$pkg', skipping."
                else
                    yay -Rns --noconfirm "$pkg" 2>/dev/null || echo "[WARN] Could not remove AUR package '$pkg', skipping."
                fi
            done
        fi
    else
        echo "[WARN] yay not found. Skipping AUR package removal."
    fi

    # Remove pacman packages
    if [[ -f "$arch_file" ]]; then
        echo "[INFO] Removing pacman packages listed in $arch_file"
        local arch_pkgs=()
        while IFS= read -r line; do
            line=$(echo "$line" | xargs)
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            arch_pkgs+=("$line")
        done < "$arch_file"
        for pkg in "${arch_pkgs[@]}"; do
            pacman -Rns --noconfirm "$pkg" 2>/dev/null || echo "[WARN] Could not remove package '$pkg', skipping."
        done
    else
        echo "[WARN] Arch packages file not found: $arch_file"
    fi
}

# Function to remove containers and enviroments

remove_containers() {
	local home_dir="/home/$USERNAME"

	if [[ -d "$home_dir/environments" ]]; then
		echo "[INFO] Removing Apptainer containers from $home_dir/environments"
		rm -rf "$home_dir/environments"
		echo "[INFO] Containers removed."
	fi

	if [[ -d "$home_dir/ymls" ]]; then 
		echo "[INFO] Removing YAML files from $home_dir/ymls"
		rm -rf "$home_dir/ymls"
		echo "[INFO] YAML files removed"
	fi
}

# Main function
main() {
    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        echo "[ERROR] This script must be run as root. Please use 'sudo'."
        exit 1
    fi
    
    echo "====================================="
    echo "  SEISbio Uninstallation Script"
    echo "====================================="
    echo ""
    
    # Confirm with the user before proceeding
    echo "This will:"
    echo "  - Remove the '$USERNAME' user and their home directory"
    echo "  - Remove Apptainer containers and YAML files"
    echo "  - Revert changes to $BASHRC_PATH"
    echo ""
    read -p "Are you sure you want to uninstall SEISbio? (y/N): " answer
    
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "[INFO] Uninstallation cancelled."
        exit 0
    fi
    
    echo ""
    
    # Ask about debian packages removal if package files exist
    if [[ -f "$SCRIPT_DIR/../deb/basic_pkgs.txt" ]] || [[ -f "$SCRIPT_DIR/../deb/bioinfo_pkgs.txt" ]]; then
        read -p "Do you want to remove Debian/Ubuntu packages installed by SEISbio? (y/N): " answer_deb
        if [[ "$answer_deb" == "y" || "$answer_deb" == "Y" ]]; then
            echo "[INFO] Removing Debian/Ubuntu packages..."
            remove_debian_packages
        else
            echo "[INFO] Skipping Debian/Ubuntu package removal."
        fi
        echo ""
    fi

    # Ask about arch packages removal if package files exist
    if [[ -f "$SCRIPT_DIR/../arch/arch_pks.txt" ]] || [[ -f "$SCRIPT_DIR/../arch/aur_pks.txt" ]]; then
        read -p "Do you want to remove Arch/AUR packages installed by SEISbio? (y/N): " answer_arch
        if [[ "$answer_arch" == "y" || "$answer_arch" == "Y" ]]; then
            echo "[INFO] Removing Arch/AUR packages..."
            remove_arch_packages
        else
            echo "[INFO] Skipping Arch/AUR package removal."
        fi
        echo ""
    fi

    # Remove containers and environments before removing user
    remove_containers
    
    # Remove user
    remove_seisbio_user "$USERNAME"
    
    # Revert bashrc changes
    revert_bashrc_changes "$BASHRC_PATH"
    
    echo ""
    echo "====================================="
    echo "  Uninstallation process completed."
    echo "====================================="
    echo ""
    echo "[INFO] Note: If you installed Apptainer during SEISbio installation,"
    echo "       you may want to remove it manually with:"
    echo "       sudo apt remove apptainer"
}

# Call main function
main
