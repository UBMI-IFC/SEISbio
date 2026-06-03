![SEISbio banner](assets/seisbio.png)

# SEISbio
Standardized System for Bioinformatics Software Installation

This project provides an automated system to install and manage bioinformatics software through conda/mamba virtual environments and their subsequent packaging into portable Apptainer containers.

## Complete Workflow

> [!NOTE]
> This README is a guide to the full workflow. If you only need one phase, jump to that section below.

### Phase 1: SEISbio System Installation (`bin/install_seisbio.sh`)
### Optional: Environment Backup (`bin/env-backup.sh`)
### Transition: Environment Preparation (`bin/seisbio.sh`)
### Phase 2: Apptainer Container Creation (`bin/utilities/run_container_pipeline.sh`)

## Dependencies

SEISbio supports Debian/Ubuntu and Arch Linux based systems.

### Required

- `bash`, `sudo`, and standard GNU/Linux utilities
- Conda distribution installed by the project (`Miniforge` or `Miniconda`)
- `apptainer` (required to build and run `.sif` containers)

> [!IMPORTANT]
> Phase 2 requires `apptainer`. Install it before running any container build step.

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
3. **Distribution installation**: Downloads and installs Miniforge or Miniconda in `/home/seisbio/` (or your custom `--base-path`)
4. **Base configuration**: Installs base scientific packages (numpy, scipy, pandas, jupyter, R, etc.)
5. **Virtual environment creation**: Installs independent environments for each bioinformatics tool

### Configuration Files

- **`virtual_envs.txt`**: Complete list of bioinformatics environments to create
- **`small_virtual_envs.txt`**: Reduced list for test or limited installations

Each line contains the name of a conda-forge or bioconda package. Version can be specified: `hicexplorer=3.2`

### Usage of install_seisbio.sh 

**Interactive Setup Wizard (Recommended):**
If you run the installation without passing a path flag, SEISbio will automatically detect any mounted external drives (like `/run/media/...`) and present an interactive menu to let you choose where to install the system.

**Syntax:**
```bash
sudo ./bin/install_seisbio.sh [OPTIONS]
```

**Key Options:**
- `--base-path <path>`: Override the interactive menu and install to a specific path (default is `/home`).
- `-d, --distribution`: Select `miniforge` (default) or `miniconda`.
- `-f, --envfile`: Specify environment file.

> [!WARNING]
> This script can install system packages and modify `/etc/bash.bashrc`. Review options before running on shared systems.

### Phase 1 Results

After running `install_seisbio.sh`:
- User `seisbio` created in `/home/seisbio/` (or your chosen custom path)
- Miniforge or Miniconda installed in `/home/seisbio/miniforge/`
- Virtual environments created in `/home/seisbio/miniforge/envs/` (one per tool)
- Conda initialized in `/etc/bash.bashrc` (accessible to all users)
- **Global configuration saved** to `/etc/seisbio.conf` (enables zero-flag usage for all other scripts).
## Interactive Tutorial

SEISbio includes an interactive tutorial to learn and execute bioinformatics commands in a safe, isolated sandbox environment. The tutorial can be run directly in the terminal (TUI) or via a graphical web interface.

### Installation

The tutorial is an **optional** component and is installed alongside other extensions using the `--scripts` flag. You can tell it to specifically install only the tutorial:

```bash
sudo ./bin/install_seisbio.sh --scripts tutorial
```

This will automatically:
1. Create an isolated `tutorial-env` conda environment.
2. Install Ruby and all required dependencies (Rails, Bundler, etc.).
3. Copy the tutorial files to the `seisbio` user home.
4. Configure Docker group permissions.

### Running the Tutorial

To run the tutorial, first switch to the `seisbio` user:

```bash
bin/seisbio.sh
conda activate tutorial-env
cd ~/tutorial-seisbio
```

**Option A — Terminal UI (no Docker needed):**
```bash
bin/rails tutorial:start
```

**Option B — Web Interface (requires Docker):**
```bash
# Build the sandbox image once (first time only)
bin/build_sandbox_image.sh

# Start the server
bin/rails server
```

Then open [http://localhost:3000](http://localhost:3000) in your browser.

> For full documentation on lesson YAML schema and environment variables, see the [tutorial-seisbio README](tutorial-seisbio/README.md).

## Optional: Export Existing Environments

### Description of `env-backup.sh` script

If you already have conda environments in your current user and want to reuse them in SEISbio, you can export them first with `bin/env-backup.sh`.

**What it does:**
1. **Auto-detects**: Detects conda distribution (miniforge/miniconda) and package manager (mamba/conda)
2. **Exports environments**: Exports existing conda environments to YAML files
3. **Writes to target user**: Saves YAML files into `/home/<target_user>/ymls`
4. **Handles duplicates**: Asks before overwriting existing YAML files
5. **Provides statistics**: Shows summary of successful, failed, and skipped exports

### Usage of env-backup.sh

**Export all environments to seisbio:**
```bash
./bin/env-backup.sh
```

**Export a specific environment:**
```bash
./bin/env-backup.sh -e test-env
```

**Export to a different user:**
```bash
./bin/env-backup.sh -u myuser
```

> [!TIP]
> Use `-e` to export a single environment first and verify the YAML output before exporting everything.

**Force specific distribution and manager:**
```bash
./bin/env-backup.sh -d miniconda -m conda
```

**View help:**
```bash
./bin/env-backup.sh -h
```

### env-backup Options

- `-e, --env <name>`: Export only the specified environment
- `-u, --user <name>`: Target user where `ymls/` will be created [default: seisbio]
- `-d, --distribution <name>`: Distribution name (miniforge/miniconda) [default: auto-detected]
- `-m, --manager <name>`: Package manager (mamba/conda) [default: auto-detected]
- `-h, --help`: Display help message

### env-backup Results

After running `bin/env-backup.sh`, the following files are created in `/home/seisbio/`:

```
ymls/
├── <env_name>_environment.yml     # Exported conda environment configuration
```

These YAML files can be installed later with:

```bash
sudo ./bin/install_seisbio.sh --yml /home/seisbio/ymls
```

## Transition: Environment Preparation

### Description of `seisbio.sh` script

The `seisbio.sh` script is a helper that facilitates the transition between Phase 1 (installation) and Phase 2 (container creation). Its purpose is to prepare the `seisbio` user's environment with the necessary files.

**What it does:**
1. **Copies necessary files**: Transfers `virtual_envs.txt`, `small_virtual_envs.txt`, Phase 2 utility scripts, and `install_seisbio.sh` to the `/home/seisbio/` directory
2. **Verifies Apptainer installation**: Automatically installs Apptainer if it's not already present on the system
3. **Switches to seisbio user**: Opens an interactive session as the `seisbio` user

> [!NOTE]
> If Apptainer is installed system-wide already, this step simply verifies it and continues.

### Usage of seisbio.sh

Run this script after completing Phase 1 and before starting Phase 2:

```bash
./bin/seisbio.sh
```

This command will:
- Automatically copy the necessary files to `/home/seisbio/`
- Position you in the `/home/seisbio/` directory
- Open a session as the `seisbio` user

## Phase 2: Apptainer Container Creation

### Description

Once Phase 1 is completed, the installed conda environments can be converted into portable Apptainer containers that work independently on any system with Apptainer installed.

## Script Descriptions

### `run_container_pipeline.sh`

Runs the complete Phase 2 workflow in order: creates definition files (`.def`) from conda environments and then builds Apptainer containers (`.sif`).

**What it does:**
- Calls `create_container.sh` first
- Calls `build_container.sh` after successful definition generation
- Supports processing one environment (`-e`) or building all definitions (`-a`)

### `create_container.sh` (internal step)

Exports existing conda environments and creates definition files (`.def`) to build Apptainer containers.

**What it does:**
- Automatically detects the conda/mamba installation
- Auto-detects if running outside `/home/seisbio/` and handles file copying automatically
- Verifies execution as `seisbio` user
- Exports each environment's configuration to an `_environment.yml` file in the `ymls/` folder
- Creates `.def` files with instructions for building the containers in the `environments/` folder
- Creates two directories: `ymls/` for YAML files and `environments/` for definition and container files

### `build_container.sh` (internal step)

Builds the Apptainer containers (`.sif` files) from the previously created `.def` files.

**What it does:**
- Reads all `.def` files in the `environments/` folder
- Builds each container using `apptainer build`
- Generates `.sif` files that are portable and self-contained containers

## Usage

Scripts location in repository:

- `bin/utilities/run_container_pipeline.sh` (recommended)
- `bin/utilities/create_container.sh` (used by pipeline)
- `bin/utilities/build_container.sh` (used by pipeline)

When running `bin/seisbio.sh` or `bin/utilities/run_container_pipeline.sh` from outside `/home/seisbio/`, required scripts are copied automatically into `/home/seisbio/`.

### Step 1: Run the complete pipeline

**Note:** If you run `run_container_pipeline.sh` from outside `/home/seisbio/`, it will automatically copy the necessary files and prompt you to switch to the `seisbio` user. Simply run it again after switching users.

> [!IMPORTANT]
> The pipeline must run as the `seisbio` user; otherwise environment exports and container builds will fail.

**Option A: Process only the latest generated `.def` (default build mode)**

```bash
./bin/utilities/run_container_pipeline.sh
```

This will create `.def` files and build only the most recent `.def` into a `.sif`.

**Option B: Process a specific environment**

```bash
./bin/utilities/run_container_pipeline.sh -e samtools
./bin/utilities/run_container_pipeline.sh --env fastqc
```

This will generate and build only the specified environment.

**Option C: Build all generated `.def` files**

```bash
./bin/utilities/run_container_pipeline.sh -a
```

This processes environments and builds all available `.def` files.

**View help:**

```bash
./bin/utilities/run_container_pipeline.sh -h
```

The process may take quite some time, as it:
- Downloads the Docker base image (continuumio/miniconda3)
- Installs all dependencies inside each container
- Creates self-contained and portable containers

> [!NOTE]
> Build time and disk usage can be significant for large environment lists. Plan storage accordingly.

**Step 1 Results:**

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

> [!WARNING]
> System-wide uninstall removes the `seisbio` user and their home directory. Back up any custom data first.

### Usage of uninstall_seisbio.sh

**System-wide uninstall (requires root):**
```bash
sudo ./bin/uninstall_seisbio.sh
```

### Uninstall Script Flags

- `--local`: Uninstalls a local installation for the current user (no root required).
- `-d, --distribution <name>`: Distribution folder name to remove. Default: `miniforge`.
- `-h, --help`: Shows help and exits.

### Uninstall Examples

**1) Local uninstall for current user:**
```bash
./bin/uninstall_seisbio.sh --local
```

**2) Local uninstall using Miniconda folder:**
```bash
./bin/uninstall_seisbio.sh --local --distribution miniconda
```

**3) System-wide uninstall (default distribution: miniforge):**
```bash
sudo ./bin/uninstall_seisbio.sh
```

**4) System-wide uninstall specifying distribution folder:**
```bash
sudo ./bin/uninstall_seisbio.sh -d miniconda
```

**5) Show script help:**
```bash
./bin/uninstall_seisbio.sh --help
```

**Note:** During system-wide uninstall, the script also prompts whether to remove Debian/Ubuntu and Arch/AUR packages listed in this repository.

## Additional tools

- [`EasyCondaEnv`](https://github.com/Alejandro-Estrada-1/EasyCondaEnv): Helper to quickly create and manage Conda/Mamba environments (useful as a companion tool to SEISbio workflows).
