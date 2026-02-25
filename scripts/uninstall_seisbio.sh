#!/bin/bash

#Uninstallation of SEISbio

USERNAME="seisbio"
BASHRC_PATH="/etc/bash.bashrc"

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
