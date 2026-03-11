# Testing with incus.sh

`incus.sh` is a universal script for creating VMs and containers with [Incus](https://linuxcontainers.org/incus/), used to test SEISbio across different Linux distributions.

## Requirements

- Incus installed and initialized on the host
- Root/sudo privileges
- Internet access (for downloading images and packages)

## Usage

```bash
sudo ./incus.sh [-c] <name> <distro/version> [cpu] [memory] [disk]
```

## Examples 

## VM's

- Debian 12 VM with defaults (2 CPU, 2GiB RAM, 20GiB disk)
sudo ./incus.sh my-vm debian/12

- Fedora 41 VM with custom resources
sudo ./incus.sh fed-vm fedora/41 4 4GiB 40GiB

- Arch Linux VM
sudo ./incus.sh arch-vm archlinux/current 2 2GiB 30GiB

## Containers

- Debian 12 container
sudo ./incus.sh -c my-ct debian/12

- Arch Linux container
sudo ./incus.sh -c arch-ct archlinux 2 2GiB 30GiB

- Fedora 43 container
sudo ./incus.sh -c fed-ct fedora/43 4 4GiB 40GiB

## Log in as the created user
incus exec <name> -- su - user

## Post-installation Testing

Once the VM or container is running, follow these steps to test SEISbio:

### 1. Clone the repository

```bash
git clone https://github.com/UBMI-IFC/SEISbio.git
cd SEISbio
```

### 2. Switch to the testing branch

```bash
git checkout incus-testing
```

### 3. Run the installer

```bash
sudo scripts/install_seisbio.sh ...
```

### 4. Install Apptainer

```bash
# Debian/Ubuntu
sudo apt-get install -y apptainer

# Fedora / CentOS / Rocky / Alma
sudo dnf install -y apptainer

# Arch Linux
sudo pacman -S apptainer
```

### 5. Verify conda is in PATH

```bash
# Reload shell environment
source ~/.bashrc

# Check conda is accessible
conda --version

# Check conda environments
conda env list
```

### 6. Test cloner.sh with the example yml

Create the example environment from the yml included in the repository, then run the cloner to replicate it to the `seisbio` user and build the Apptainer container.

```bash
# Verify the environment was created (should show muscle-env)
conda env list

# Run cloner.sh targeting the example environment
sudo bash scripts/cloner.sh -e muscle-env
```

### 7. Switch to the seisbio user

```bash
sudo scripts/seisbio.sh
```

This will open a session as the `seisbio` user. From there, run the following checks:

### 8. Verify the cloned environment

```bash
# Should list muscle-env under /home/seisbio/miniforge/envs/
conda env list
```

### 9. Check that the expected directories and files were created

```bash
# ymls/ should contain the exported environment file
ls ~/ymls/
# Expected: muscle-env_environment.yml

# environments/ should contain the Apptainer definition and image files
ls ~/environments/
# Expected: muscle-env.def  muscle-env.sif
```

