#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# ------------------------------
# Name:     UninstallSEISbio.py
# Purpose:  Uninstallation of SEISbio
#
# @uthor:      acph - dragopoot@gmail.com
#
# Created:     jue 27 jun 2025
# Copyright:   (c) acph 2025
# Licence:     GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007
# ------------------------------
"""Uninstallation of SEISbio"""

import os
import sys
import re
from subprocess import run, CalledProcessError

def remove_seisbio_user(username="seisbio"):
    """Removes the seisbio user and their home directory."""
    print(f"[INFO] Attempting to remove user: {username}")
    try:
        # -r flag removes the home directory and mail spool
        run(["userdel", "-r", username], check=True)
        print(f"[INFO] User '{username}' removed successfully.")
    except CalledProcessError as e:
        print(f"[ERROR] Failed to remove user '{username}': {e}")
        print("[ERROR] This might happen if the user does not exist or if you don't have sufficient permissions.")
    except FileNotFoundError:
        print("[ERROR] 'userdel' command not found. Make sure it's in your PATH.")

def revert_bashrc_changes(bashrc_path="/etc/bash.bashrc"):
    """Reverts the changes made to /etc/bash.bashrc by SEISbio installation."""
    print(f"[INFO] Attempting to revert changes in {bashrc_path}")
    try:
        with open(bashrc_path, 'r') as f:
            content = f.read()

        # The exact block to remove
        conda_block_pattern = re.compile(
            r"# --- Added by SEISbio\n"
            r"# >>> conda initialize >>>.*?"
            r"# <<< conda initialize <<<",
            re.DOTALL
        )

        new_content = re.sub(conda_block_pattern, "", content)

        if new_content != content:
            with open(bashrc_path, 'w') as f:
                f.write(new_content)
            print(f"[INFO] Changes in {bashrc_path} reverted successfully.")
        else:
            print(f"[INFO] No SEISbio related changes found in {bashrc_path}. Nothing to revert.")

    except FileNotFoundError:
        print(f"[ERROR] File not found: {bashrc_path}. Cannot revert changes.")
    except IOError as e:
        print(f"[ERROR] Error reading or writing {bashrc_path}: {e}")
        print("[ERROR] Make sure you have write permissions (run as root).")

def main():
    if os.geteuid() != 0:
        print("[ERROR] This script must be run as root. Please use 'sudo'.")
        sys.exit(1)

    print("=====================================")
    print("  SEISbio Uninstallation Script")
    print("=====================================")

    # Confirm with the user before proceeding
    answer = input("Are you sure you want to uninstall SEISbio? This will remove the 'seisbio' user and modify /etc/bash.bashrc. (y/N): ")
    if answer.lower() != 'y':
        print("[INFO] Uninstallation cancelled.")
        sys.exit(0)

    remove_seisbio_user()
    revert_bashrc_changes()

    print("=====================================")
    print("  Uninstallation process completed.")
    print("=====================================")

if __name__ == '__main__':
    main()
