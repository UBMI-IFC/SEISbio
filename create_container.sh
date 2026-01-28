#!/bin/bash

# Valores por defecto
SELECTED_ENV=""

# Función para mostrar uso
usage() {
    echo "Uso: $0 [OPCIONES]"
    echo "Crea archivos .def para contenedores Apptainer desde entornos conda"
    echo ""
    echo "Opciones:"
    echo "  -e, --env <nombre>    Procesar solo el entorno especificado"
    echo "  -h, --help            Mostrar este mensaje de ayuda"
    echo ""
    echo "Si no se especifica -e, se procesan todos los entornos conda disponibles"
    exit 1
}

# Parsear argumentos
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
            echo "Parámetro desconocido: $1"
            usage
            ;;
    esac
    shift
done

# Preparación: copiar archivos necesarios y cambiar al usuario seisbio
CURRENT_DIR=$(pwd)
SEISBIO_HOME="/home/seisbio"

# Si no estamos en /home/seisbio, copiar archivos necesarios
if [[ "$CURRENT_DIR" != "$SEISBIO_HOME" ]]; then
    echo "[INFO] Copiando archivos necesarios a $SEISBIO_HOME..."
    sudo cp virtual_envs.txt small_virtual_envs.txt build_container.sh create_container.sh "$SEISBIO_HOME/" 2>/dev/null
    sudo chown seisbio:seisbio "$SEISBIO_HOME"/{virtual_envs.txt,small_virtual_envs.txt,build_container.sh,create_container.sh} 2>/dev/null
    
    echo "[INFO] Cambiando a directorio $SEISBIO_HOME y usuario seisbio..."
    echo "[INFO] Ejecuta: cd $SEISBIO_HOME && sudo su - seisbio"
    echo "[INFO] Luego ejecuta nuevamente: ./create_container.sh"
    exit 0
fi

# Verificar que somos el usuario seisbio
if [[ "$(whoami)" != "seisbio" ]]; then
    echo "[WARN] Este script debe ejecutarse como usuario 'seisbio'"
    echo "Ejecuta: sudo su - seisbio"
    exit 1
fi

# Carpeta de destino para los env descargados que después serán contenedores
mkdir -p ambientes
mkdir -p ymls

# Obtener lista de los env (no incluye base)
if [[ -n "$SELECTED_ENV" ]]; then
    # Verificar que el entorno existe
    if conda env list | grep -q "^${SELECTED_ENV} "; then
        ENVS="$SELECTED_ENV"
        echo " == Creando contenedor para el entorno: $SELECTED_ENV =="
    else
        echo "[ERROR] El entorno '$SELECTED_ENV' no existe"
        echo "Entornos disponibles:"
        conda env list | grep -v '^#' | awk '{print "  - " $1}' | grep -v '^$' | grep -v 'base'
        exit 1
    fi
else
    ENVS=$(conda env list | grep -v '^#' | awk '{print $1}' | grep -v '^$' | grep -v 'base')
    echo " == Creando contenedores para todos los envs de conda =="
fi

for ENV_NAME in $ENVS; do
	echo "Cargando entorno: $ENV_NAME"
	
	# Exportar .yml del entorno a carpeta ymls
	echo "Exportando .yml a ymls/: "
	conda env export -n $ENV_NAME > ymls/${ENV_NAME}_environment.yml

	# Creando archivo .def
	echo "=== Creando ==="
	cat > ambientes/${ENV_NAME}.def << EOF
Bootstrap: docker 
From: continuumio/miniconda3

%help 
	Contenedor Apptainer con entorno conda "${ENV_NAME}"

%files
	../ymls/${ENV_NAME}_environment.yml /opt/environment.yml

%post 
	echo "Creando entorno conda"
	/opt/conda/bin/conda env create -f /opt/environment.yml

	echo "Se está limpiando la cache"
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

	echo " Archivos cargados "
done

echo "=== Archivos .def creados en carpeta 'ambientes/' ==="
echo ""
echo "Para construir los contenedores, ejecuta:"
echo "  sudo ./build_container.sh"
