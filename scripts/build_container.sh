#!/bin/bash

# Script to build .sif containers from .def files
# REQUIRES sudo to run apptainer build

# Default: build only the most recent .def file
BUILD_ALL=false

# Function to display usage
usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo "Builds Apptainer containers from .def files"
    echo ""
    echo "Options:"
    echo "  -a, --all             Build all .def files"
    echo "  -h, --help            Display this help message and exit"
    echo ""
    echo "By default, builds only the most recently created .def file"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
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

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run with sudo" 
    echo "Usage: sudo ./build_container.sh"
    exit 1
fi

cd environments || exit 1

echo "=== Building Apptainer containers ==="
echo ""

if [ "$BUILD_ALL" = true ]; then
    # Build all .def files
    echo "Building all containers..."
    echo ""
    
    for DEF_FILE in *.def; do
        if [ -f "$DEF_FILE" ]; then
            ENV_NAME="${DEF_FILE%.def}"
            SIF_FILE="${ENV_NAME}.sif"
            
            echo "Building ${SIF_FILE} from ${DEF_FILE}..."
            apptainer build ${SIF_FILE} ${DEF_FILE}
            
            if [ $? -eq 0 ]; then
                echo "  ✓ ${SIF_FILE} created successfully"
            else
                echo "  ✗ Error creating ${SIF_FILE}"
            fi
            echo ""
        fi
    done
else
    # Build only the most recent .def file
    LATEST_DEF=$(ls -t *.def 2>/dev/null | head -n 1)
    
    if [ -z "$LATEST_DEF" ]; then
        echo "[ERROR] No .def files found in environments/ folder"
        exit 1
    fi
    
    ENV_NAME="${LATEST_DEF%.def}"
    SIF_FILE="${ENV_NAME}.sif"
    
    echo "Building most recent container: ${ENV_NAME}"
    echo ""
    echo "Building ${SIF_FILE} from ${LATEST_DEF}..."
    apptainer build ${SIF_FILE} ${LATEST_DEF}
    
    if [ $? -eq 0 ]; then
        echo "  ✓ ${SIF_FILE} created successfully"
    else
        echo "  ✗ Error creating ${SIF_FILE}"
    fi
    echo ""
fi

echo "=== Build completed ==="
echo ""
echo "Containers are in the 'environments/' folder"
echo "To use a container, run: ./environments/<name>.sif"