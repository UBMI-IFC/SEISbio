#!/bin/bash


detect_conda() { 
	if [[ -n "$CONDA_EXE" && -x "$CONDA_EXE" ]]; then 
		echo "$CONDA_EXE"
		return
	fi

	local conda_path
	conda_path=$(command -v conda 2>/dev/null)

	if [[ -z "$conda_path" ]]; then 
		echo "[ERROR] conda no encontrado en PATH" >&2
		exit 1
	fi

	if [[ "$conda_path" == */condabin/conda ]]; then 
		echo "$(dirname "$(dirname "$conda_path")")/bin/conda"
		return
	fi

	echo "$conda_path"
}

CONDA=$(detect_conda)

if [[ ! -x "$CONDA" ]]; then
	echo "[ERROR] conda no ejecutable: $CONDA"
	exit 1
fi

echo "[INFO] Using conda:  $($CONDA --version)"

# Default values
SELECTED_ENV=""

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Creates .def files for Apptainer containers from conda environments"
    echo ""
    echo "Options:"
    echo "  -e, --env <name>      Process only the specified environment"
    echo "  -h, --help            Display this help message and exit"
    echo ""
    echo "If -e is not specified, all available conda environments are processed"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -e|--env)
            SELECTED_ENV="$2"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
    shift
done

# Preparation: copy necessary files and switch to seisbio user
CURRENT_DIR=$(pwd)
SEISBIO_HOME="/home/seisbio"

# If not in /home/seisbio, copy necessary files
if [[ "$CURRENT_DIR" != "$SEISBIO_HOME" ]]; then
    echo "[INFO] Copying necessary files to $SEISBIO_HOME..."
    # Get script directory to properly reference files
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    sudo cp "$SCRIPT_DIR/../envs/virtual_envs.txt" "$SCRIPT_DIR/../envs/small_virtual_envs.txt" "$SCRIPT_DIR/build_container.sh" "$SCRIPT_DIR/create_container.sh" "$SEISBIO_HOME/" 2>/dev/null
    sudo chown seisbio:seisbio "$SEISBIO_HOME"/{virtual_envs.txt,small_virtual_envs.txt,build_container.sh,create_container.sh} 2>/dev/null
    
    echo "[INFO] Switching to $SEISBIO_HOME directory and seisbio user..."
    echo "[INFO] Run: cd $SEISBIO_HOME && sudo su - seisbio"
    echo "[INFO] Then run again: ./create_container.sh"
    exit 0
fi

# Verify we are seisbio user
if [[ "$(whoami)" != "seisbio" ]]; then
    echo "[WARN] This script must be run as 'seisbio' user"
    echo "Run: sudo su - seisbio"
    exit 1
fi

# Destination folders for environments that will become containers
mkdir -p environments
mkdir -p ymls

# Get list of environments (excludes base)
if [[ -n "$SELECTED_ENV" ]]; then
    # Verify that the environment exists
    if "$CONDA" env list | grep -q "^${SELECTED_ENV} "; then
        ENVS="$SELECTED_ENV"
        echo " == Creating container for environment: $SELECTED_ENV =="
    else
        echo "[ERROR] Environment '$SELECTED_ENV' does not exist"
        echo "Available environments:"
        "$CONDA" env list | grep -v '^#' | awk '{print "  - " $1}' | grep -v '^base$'
        exit 1
    fi
else
	ENVS=$("$CONDA" env list | grep -v '^#' | awk '{print $1}' | grep -v '^base$')

    if [[ -z "$ENVS" ]]; then 
	echo "[INFO] No conda environments found"
	exit 0
    fi

    echo "== Creating containers for all conda environments =="
    for env in $ENVS; do
	    echo "  - $env"
    done
fi

for ENV_NAME in $ENVS; do
	echo "Loading environment: $ENV_NAME"
	
	# Export environment .yml to ymls folder
	echo "Exporting .yml to ymls/: "
	"$CONDA" env export -n $ENV_NAME > ymls/${ENV_NAME}_environment.yml

	# Creating .def file
	echo "=== Creating ==="
	cat > environments/${ENV_NAME}.def << EOF
Bootstrap: docker 
From: continuumio/miniconda3

%help 
	Apptainer container with conda environment "${ENV_NAME}"

%files
	../ymls/${ENV_NAME}_environment.yml /opt/environment.yml

%post 
	echo "Creating conda environment"
	/opt/conda/bin/conda env create -f /opt/environment.yml

	echo "Cleaning cache"
	/opt/conda/bin/conda clean -afy

%environment
	export PATH=/opt/conda/envs/${ENV_NAME}/bin:/opt/conda/bin:\$PATH
	export CONDA_DEFAULT_ENV=${ENV_NAME}
	export CONDA_PREFIX=/opt/conda/envs/${ENV_NAME}

%runscript 
	#!/bin/bash
	source /opt/conda/etc/profile.d/conda.sh
	conda activate ${ENV_NAME}

	if [ \$# -eq 0 ]; then 
		exec /bin/bash
	else 
		exec "\$@"
	fi
EOF

	echo " Files loaded "
done

echo "=== .def files created in 'environments/' folder ==="
echo ""
echo "To build the containers, run:"
echo "  sudo ./build_container.sh"
