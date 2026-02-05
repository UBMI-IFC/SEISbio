#!/bin/bash

# Script to build all .sif containers from .def files
# REQUIRES sudo to run apptainer build

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run with sudo" 
    echo "Usage: sudo ./build_container.sh"
    exit 1
fi

cd environments || exit 1

echo "=== Building Apptainer containers ==="
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

echo "=== Build completed ==="
echo ""
echo "Containers are in the 'environments/' folder"
echo "To use a container, run: ./environments/<name>.sif"