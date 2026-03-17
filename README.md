# SEISbio
Standardized System for Bioinformatics Software Installation

This project provides an automated system to install and manage bioinformatics software through conda/mamba virtual environments and their subsequent packaging into portable Apptainer containers.

## Complete Workflow

### Phase 1: SEISbio System Installation (`install_seisbio.sh`)
### Transition: Environment Preparation (`seisbio.sh`)
### Phase 2: Apptainer Container Creation (`create_container.sh` and `build_container.sh`)

## Dependencies

SEISbio supports Debian/Ubuntu and Arch Linux based systems.

### Required

- `bash`, `sudo`, and standard GNU/Linux utilities
- Conda distribution installed by the project (`Miniforge` or `Miniconda`)
- `apptainer` (required to build and run `.sif` containers)

### Debian/Ubuntu Package Dependencies

Installed from the lists below (used by `install_seisbio.sh`):

- `deb/basic_pkgs.txt` (system and utility tools):
	`build-essential`, `cmake`, `aptitude`, `tree`, `bc`, `rsync`, `wget`, `curl`, `openssh-server`, `xrdp`, `fd-find`, `fzf`, `ripgrep`, `htop`, `neovim`, `emacs`, etc.
- `deb/bioinfo_pkgs.txt` (bioinformatics tools):
	`emboss`, `ncbi-blast+`, `hmmer`, `t-coffee`, `muscle`, `phylip`, `phyml`, `raxml`, `mrbayes`, `seaview`, `clustalo`, `treeview`, etc.

### Arch Linux Package Dependencies

Installed from the lists below:

- `arch/arch_pks.txt` (official repositories):
	`base-devel`, `cmake`, `tree`, `bc`, `rsync`, `wget`, `curl`, `openssh`, `fd`, `fzf`, `ripgrep`, `htop`, `btop`, `vim`, `emacs`, etc.
- `arch/aur_pks.txt` (AUR):
	`xrdp`, `toilet`, and bioinformatics packages such as `blast+-bin`, `hmmer`, `raxml-ng`, `mrbayes`, `clustal-omega`, etc.

### Conda/Mamba Base Environment Dependencies

Installed from `base/base_packages.txt`:

- Scientific stack: `numpy`, `scipy`, `matplotlib`, `pandas`, `statsmodels`, `seaborn`
- Bioinformatics: `biopython`
- Workflow/network utilities: `networkx`
- Jupyter stack: `jupyter`, `jupyterlab`, `jupyter-lsp`, `jupyterlab-lsp`, `jupyter-lsp-python`

### Environment Package Lists

Tool-specific conda environments are created from:

- `envs/virtual_envs.txt` (full list)
- `envs/small_virtual_envs.txt` (reduced list)
- `envs/structural_biology.txt` (domain-specific list)

Each line in these files is a package name (optionally version-pinned, e.g. `hicexplorer=3.2`).

## Phase 1: SEISbio System Installation

### Description

The `install_seisbio.sh` script performs a complete installation of the SEISbio system:

1. **System package installation** (optional): Installs basic and bioinformatics packages from Debian/Ubuntu repositories
2. **Creation of seisbio user**: Creates a dedicated user with UID/GID 1015 (configurable)
3. **Distribution installation**: Downloads and installs Miniforge or Miniconda in `/home/seisbio/`
4. **Base configuration**: Installs base scientific packages (numpy, scipy, pandas, jupyter, R, etc.)
5. **Virtual environment creation**: Installs independent environments for each bioinformatics tool

### Configuration Files

- **`virtual_envs.txt`**: Complete list of bioinformatics environments to create
- **`small_virtual_envs.txt`**: Reduced list for test or limited installations

Each line contains the name of a conda-forge or bioconda package. Version can be specified: `hicexplorer=3.2`

### Usage of install_seisbio.sh

**Syntax:**
```bash
sudo ./install_seisbio.sh [OPTIONS]
```

### Phase 1 Results

After running `install_seisbio.sh`:
- User `seisbio` created in `/home/seisbio/`
- Miniforge or Miniconda installed in `/home/seisbio/miniforge/` or `/home/seisbio/miniconda/`
- Virtual environments created in `/home/seisbio/miniforge/envs/` (one per tool)
- Conda initialized in `/etc/bash.bashrc` (accessible to all users)

## Alternative: Cloning Existing Environments

### Description of `cloner.sh` script

If you already have conda environments installed in your local user and want to clone them to the `seisbio` user instead of creating them from scratch, you can use the `cloner.sh` script. This script not only clones the environments but also automatically creates portable Apptainer containers.

**What it does:**
1. **Auto-detects**: Automatically detects your conda distribution (miniforge/miniconda) and package manager (mamba/conda)
2. **Exports environments**: Exports your existing conda environments to YAML files
3. **Clones to seisbio**: Recreates those environments in the `seisbio` user
4. **Creates Apptainer containers**: Automatically generates `.def`, `.yml`, and `.sif` files for each environment
5. **Preserves original paths**: Containers use the original environment paths for full compatibility
6. **Handles duplicates**: Asks before overwriting existing environments
7. **Provides statistics**: Shows summary of successful, failed, and skipped clones and containers

### Usage of cloner.sh

**Clone all your environments to seisbio:**
```bash
./cloner.sh
```

**Clone a specific environment:**
```bash
./cloner.sh -e test-env
```

**Clone to a different user:**
```bash
./cloner.sh -u myuser
```

**Force specific distribution and manager:**
```bash
./cloner.sh -d miniconda -m conda
```

**View help:**
```bash
./cloner.sh -h
```

### Cloner Options

- `-e, --env <name>`: Clone only the specified environment
- `-u, --user <name>`: Target user to clone environments to [default: seisbio]
- `-d, --distribution <name>`: Distribution name (miniforge/miniconda) [default: auto-detected]
- `-m, --manager <name>`: Package manager (mamba/conda) [default: auto-detected]
- `-h, --help`: Display help message

### Cloner Results

After running `cloner.sh`, the following files are created in `/home/seisbio/`:

```
ymls/
├── <env_name>_environment.yml     # Exported conda environment configuration

environments/
├── <env_name>.def                 # Apptainer definition file
└── <env_name>.sif                 # Ready-to-use portable container
```

### Using Cloned Containers

The generated containers preserve the original environment paths and are fully functional:

**Run commands directly:**
```bash
sudo -i -u seisbio
./environments/test-env.sif 
./environments/test-env.sif bash -c 'conda list'
```

**Interactive session:**
```bash
./environments/test-env.sif
# Now inside the container
conda list
python --version
```

**Check environment details:**
```bash
./environments/test-env.sif -c 'which python'
./environments/test-env.sif -c 'echo $CONDA_PREFIX'
```

**Note:** This is an alternative to creating environments from scratch with `install_seisbio.sh`. Use `cloner.sh` when you want to replicate your existing setup in the seisbio user and automatically generate portable containers in a single step.

## Transition: Environment Preparation

### Description of `seisbio.sh` script

The `seisbio.sh` script is a helper that facilitates the transition between Phase 1 (installation) and Phase 2 (container creation). Its purpose is to prepare the `seisbio` user's environment with the necessary files.

**What it does:**
1. **Copies necessary files**: Transfers `virtual_envs.txt`, `small_virtual_envs.txt`, `build_container.sh`, `create_container.sh`, and `install_seisbio.sh` to the `/home/seisbio/` directory
2. **Verifies Apptainer installation**: Automatically installs Apptainer if it's not already present on the system
3. **Switches to seisbio user**: Opens an interactive session as the `seisbio` user

### Usage of seisbio.sh

Run this script after completing Phase 1 and before starting Phase 2:

```bash
./seisbio.sh
```

This command will:
- Automatically copy the necessary files to `/home/seisbio/`
- Position you in the `/home/seisbio/` directory
- Open a session as the `seisbio` user

## Phase 2: Apptainer Container Creation

### Description

Once Phase 1 is completed, the installed conda environments can be converted into portable Apptainer containers that work independently on any system with Apptainer installed.

## Script Descriptions

### `create_container.sh`

Exports existing conda environments and creates definition files (`.def`) to build Apptainer containers.

**What it does:**
- Automatically detects the conda/mamba installation
- Auto-detects if running outside `/home/seisbio/` and handles file copying automatically
- Verifies execution as `seisbio` user
- Exports each environment's configuration to an `_environment.yml` file in the `ymls/` folder
- Creates `.def` files with instructions for building the containers in the `environments/` folder
- Creates two directories: `ymls/` for YAML files and `environments/` for definition and container files

### `build_container.sh`

Builds the Apptainer containers (`.sif` files) from the previously created `.def` files.

**What it does:**
- Reads all `.def` files in the `environments/` folder
- Builds each container using `apptainer build`
- Generates `.sif` files that are portable and self-contained containers

## Usage

### Step 1: Grant execution permissions

```bash
chmod +x create_container.sh build_container.sh
```

### Step 2: Create definition files

**Note:** If you run `create_container.sh` from outside `/home/seisbio/`, it will automatically copy the necessary files and prompt you to switch to the `seisbio` user. Simply run it again after switching users.

**Option A: Process all environments**

```bash
./create_container.sh
```

This will process all available conda environments (except `base`).

**Option B: Process a specific environment**

```bash
./create_container.sh -e samtools
./create_container.sh --env fastqc
```

This will process only the specified environment.

**View help:**

```bash
./create_container.sh -h
```

### Step 3: Build the containers

**Requires root permissions (sudo)**

```bash
sudo ./build_container.sh
```

This process may take quite some time, as it:
- Downloads the Docker base image (continuumio/miniconda3)
- Installs all dependencies inside each container
- Creates self-contained and portable containers

**Step 3 Results:**

After the build process:
- `ymls/` folder contains: `<name>_environment.yml` files (exported conda environments)
- `environments/` folder contains: `<name>.def` (definition files) and `<name>.sif` (ready-to-use containers)

## Container Usage

Once the containers are built, we run:

### Open an interactive shell

```bash
./environments/<name>.sif
```

## Resulting File Structure

```
ymls/
├── samtools_environment.yml
├── fastqc_environment.yml
├── star_environment.yml
└── ...

environments/
├── samtools.def
├── samtools.sif
├── fastqc.def
├── fastqc.sif
├── star.def
├── star.sif
└── ...
```
## Uninstallation

The `uninstall_seisbio.sh` script removes the SEISbio installation. It supports two modes: **system-wide** (requires root) and **local** (current user only).

**What it does:**
- Removes the conda/mamba distribution (Miniforge or Miniconda)
- Removes Apptainer containers (`environments/`) and YAML files (`ymls/`)
- Reverts conda initialization blocks added to the system or user bashrc
- Optionally removes Debian/Ubuntu or Arch/AUR packages installed by SEISbio
- Removes the `seisbio` user and their home directory 

### Usage of uninstall_seisbio.sh

**System-wide uninstall (requires root):**
```bash
sudo ./scripts/uninstall_seisbio.sh
```

### Uninstall Script Flags

- `--local`: Uninstalls a local installation for the current user (no root required).
- `-d, --distribution <name>`: Distribution folder name to remove. Default: `miniforge`.
- `-h, --help`: Shows help and exits.

### Uninstall Examples

**1) Local uninstall for current user:**
```bash
./scripts/uninstall_seisbio.sh --local
```

**2) Local uninstall using Miniconda folder:**
```bash
./scripts/uninstall_seisbio.sh --local --distribution miniconda
```

**3) System-wide uninstall (default distribution: miniforge):**
```bash
sudo ./scripts/uninstall_seisbio.sh
```

**4) System-wide uninstall specifying distribution folder:**
```bash
sudo ./scripts/uninstall_seisbio.sh -d miniconda
```

**5) Show script help:**
```bash
./scripts/uninstall_seisbio.sh --help
```

**Note:** During system-wide uninstall, the script also prompts whether to remove Debian/Ubuntu and Arch/AUR packages listed in this repository.

