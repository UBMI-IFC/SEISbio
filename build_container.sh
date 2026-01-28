#!/bin/bash

# Script para construir todos los contenedores .sif desde los archivos .def
# Usa sudo apptainer para cada construcción

cd ambientes || exit 1

echo "=== Construyendo contenedores Apptainer ==="
echo ""

for DEF_FILE in *.def; do
    if [ -f "$DEF_FILE" ]; then
        ENV_NAME="${DEF_FILE%.def}"
        SIF_FILE="${ENV_NAME}.sif"
        
        echo "Construyendo ${SIF_FILE} desde ${DEF_FILE}..."
        sudo apptainer build ${SIF_FILE} ${DEF_FILE}
        
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
