#!/bin/bash

# Orchestrates: 1) create .def files from conda envs, 2) build .sif containers.

set -e

SELECTED_ENV=""
BUILD_ALL=false
SEISBIO_USER="seisbio"
BASE_PATH="/home"

if [[ -f "/etc/seisbio.conf" ]]; then
    source /etc/seisbio.conf
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CREATE_SCRIPT="${SCRIPT_DIR}/create_container.sh"
BUILD_SCRIPT="${SCRIPT_DIR}/build_container.sh"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Runs create_container.sh and build_container.sh in sequence"
    echo ""
    echo "Options:"
    echo "  -e, --env <name>      Process only the specified conda environment"
    echo "  -a, --all             Build all .def files (default: only latest)"
    echo "  --base-path <path>    Override the default '/home' base path"
    echo "  --home <name>         Override the default 'seisbio' username"
    echo "  -h, --help            Display this help message and exit"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -e|--env)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "[ERROR] Missing value for $1"
                usage
            fi
            SELECTED_ENV="$2"
            shift
            ;;
        --base-path)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "[ERROR] Missing value for $1"
                usage
            fi
            BASE_PATH="$2"
            shift
            ;;
        --home)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "[ERROR] Missing value for $1"
                usage
            fi
            SEISBIO_USER="$2"
            shift
            ;;
        -a|--all)
            BUILD_ALL=true
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


if [[ ! -x "$CREATE_SCRIPT" ]]; then
    echo "[ERROR] Missing or non-executable script: $CREATE_SCRIPT"
    exit 1
fi


if [[ ! -x "$BUILD_SCRIPT" ]]; then
    echo "[ERROR] Missing or non-executable script: $BUILD_SCRIPT"
    exit 1
fi


echo "=== SEISbio container pipeline ==="


CREATE_ARGS=()
if [[ -n "$SELECTED_ENV" ]]; then
    CREATE_ARGS+=("-e" "$SELECTED_ENV")
fi
if [[ "$SEISBIO_USER" != "seisbio" ]]; then
    CREATE_ARGS+=("--home" "$SEISBIO_USER")
fi
if [[ "$BASE_PATH" != "/home" ]]; then
    CREATE_ARGS+=("--base-path" "$BASE_PATH")
fi


echo "[STEP 1/2] Creating .def files..."
"$CREATE_SCRIPT" "${CREATE_ARGS[@]}"


# create_container.sh can exit successfully after copying files and asking for rerun.
if [[ "$(pwd)" != "$BASE_PATH/$SEISBIO_USER" || "$(whoami)" != "$SEISBIO_USER" ]]; then
    if [[ "$(whoami)" == "$SEISBIO_USER" && -x "$BASE_PATH/$SEISBIO_USER/create_container.sh" ]]; then
        echo ""
        echo "[INFO] Re-running creation step from $BASE_PATH/$SEISBIO_USER as $SEISBIO_USER..."
        cd "$BASE_PATH/$SEISBIO_USER" || exit 1
        "$BASE_PATH/$SEISBIO_USER/create_container.sh" "${CREATE_ARGS[@]}"
    else
        echo ""
        echo "[INFO] Initial setup done."
        echo "[INFO] Follow create_container.sh instructions, then rerun this script from $BASE_PATH/$SEISBIO_USER as user $SEISBIO_USER."
        exit 0
    fi
fi


BUILD_ARGS=()
if [[ "$BUILD_ALL" = true ]]; then
    BUILD_ARGS+=("-a")
fi


echo ""
echo "[STEP 2/2] Building .sif containers..."
if [[ "$EUID" -eq 0 ]]; then
    "$BUILD_SCRIPT" "${BUILD_ARGS[@]}"
else
    sudo "$BUILD_SCRIPT" "${BUILD_ARGS[@]}"
fi


echo ""
echo "=== Pipeline completed successfully ==="
