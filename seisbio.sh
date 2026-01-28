#!/bin/bash

SEISBIO_HOME="/home/seisbio"

if [[ "$(pwd)" != "$SEISBIO_HOME" ]]; then
    echo "[INFO] Copiando archivos..."
    sudo cp virtual_envs.txt small_virtual_envs.txt build_container.sh create_container.sh "$SEISBIO_HOME/"

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

