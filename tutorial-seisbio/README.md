# SEISbio Tutorial

Interactive bioinformatics tutorial with two modes: a terminal UI (TUI) and a web-based sandbox powered by Docker.

---

## Requirements

| Requirement | Used By |
|---|---|
| Ruby 3.3+ (via `tutorial-env` conda env) | Both modes |
| Bundler | Both modes |
| Docker (daemon running) | Web mode only |

> **Note:** If you installed SEISbio with `--scripts tutorial`, Ruby and Bundler are already configured inside the `tutorial-env` conda environment. You only need to install Docker separately if you want to use the web mode.

---

## Modes

### Mode A — Terminal UI (TUI)

A full interactive tutorial that runs directly in your terminal. No Docker required.

```bash
# 1. Activate the conda environment
conda activate tutorial-env

# 2. Navigate to the tutorial directory
cd ~/tutorial-seisbio

# 3. Start the tutorial
bin/rails tutorial:start
```

Optional wrapper script:
```bash
bin/tutorial
```

### Mode B — Web Interface

A browser-based version of the tutorial. Commands run inside an isolated Docker container (sandbox).

#### Prerequisites (first time only)

Before starting the server, you must build the Docker sandbox image once:

```bash
conda activate tutorial-env
cd ~/tutorial-seisbio

# Build the sandbox image (only needed once)
bin/build_sandbox_image.sh
```

> This creates the Docker image named `seisbio-tutorial-sandbox` that the web server uses to spawn isolated containers per session.

#### Starting the server

```bash
conda activate tutorial-env
cd ~/tutorial-seisbio
bin/rails server
```

Then open your browser at **[http://localhost:3000](http://localhost:3000)**


## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SEISBIO_SANDBOX_IMAGE` | `seisbio-tutorial-sandbox` | Docker image name to use for sandbox containers |
| `SEISBIO_REPO_PATH` | Parent directory of `tutorial-seisbio/` | SEISbio repo path mounted inside the container |
| `SANDBOX_CMD_TIMEOUT` | `600` | Max seconds allowed per command |

---

## Notes

- The sandbox creates one Docker container per session and destroys it on exit.
- Commands with `sudo` work without a password inside the sandbox.
- The `build_sandbox_image.sh` script only needs to run **once** (or after a `Dockerfile` change).
