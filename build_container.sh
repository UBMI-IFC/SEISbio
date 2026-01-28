#!/bin/bash

# Script para construir todos los contenedores .sif desde los archivos .def
# REQUIERE sudo para ejecutar apptainer build

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Este script debe ejecutarse con sudo" 
    echo "Uso: sudo ./build_container.sh"
    exit 1
fi

cd ambientes || exit 1

echo "=== Construyendo contenedores Apptainer ==="
echo ""

for DEF_FILE in *.def; do
    if [ -f "$DEF_FILE" ]; then
        ENV_NAME="${DEF_FILE%.def}"
        SIF_FILE="${ENV_NAME}.sif"
        
        echo "Construyendo ${SIF_FILE} desde ${DEF_FILE}..."
        apptainer build ${SIF_FILE} ${DEF_FILE}
        
        if [ $? -eq 0 ]; then
            echo "  ✓ ${SIF_FILE} creado exitosamente"
        else
            echo "  ✗ Error al crear ${SIF_FILE}"
        fi
        echo ""
    fi
done

echo "=== Construcción completada ==="
echo ""
echo "Los contenedores están en la carpeta 'ambientes/'"
echo "Para usar un contenedor, ejecuta: ./ambientes/<nombre>.sif"
