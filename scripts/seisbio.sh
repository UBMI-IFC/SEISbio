#!/bin/bash

SEISBIO_HOME="/home/seisbio"

if [[ "$(pwd)" != "$SEISBIO_HOME" ]]; then
    echo "[INFO] Copiando archivos..."
    # Get script directory to properly reference files
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    sudo cp "$SCRIPT_DIR/../envs/virtual_envs.txt" "$SCRIPT_DIR/../envs/small_virtual_envs.txt" "$SCRIPT_DIR/build_container.sh" "$SCRIPT_DIR/create_container.sh" "$SCRIPT_DIR/install_seisbio.sh" "$SEISBIO_HOME/"

    echo "[INFO] Abriendo sesión como seisbio..."
    exec sudo -i -u seisbio
else
    echo "[INFO] Verificando instalación de Apptainer..."
    if ! command -v apptainer &> /dev/null; then
        echo "[INFO] Instalando Apptainer..."
        sudo apt update
        sudo apt install -y apptainer
        echo "[INFO] Apptainer instalado correctamente"
    else
        echo "[INFO] Apptainer ya está instalado"
    fi
fi

