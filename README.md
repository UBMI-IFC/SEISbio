# SEISbio
Sistema Estandarizado de Instalación de Software bioinformático

Este proyecto proporciona un sistema automatizado para instalar y gestionar software bioinformático mediante entornos virtuales de conda/mamba y su posterior empaquetado en contenedores Apptainer portables.

## Flujo de Trabajo Completo

### Fase 1: Instalación del Sistema SEISbio (`install_seisbio.sh`)
### Transición: Preparación del entorno (`seisbio.sh`)
### Fase 2: Creación de Contenedores Apptainer (`create_container.sh` y `build_container.sh`)

## Fase 1: Instalación del Sistema SEISbio

### Descripción

El script `install_seisbio.sh` realiza la instalación completa del sistema SEISbio:

1. **Instalación de paquetes del sistema** (opcional): Instala paquetes básicos y bioinformáticos desde repositorios Debian/Ubuntu
2. **Creación del usuario seisbio**: Crea un usuario dedicado con UID/GID 1015 (configurable)
3. **Instalación de la distribución**: Descarga e instala Miniforge o Miniconda en `/home/seisbio/`
4. **Configuración base**: Instala paquetes científicos base (numpy, scipy, pandas, jupyter, R, etc.)
5. **Creación de entornos virtuales**: Instala entornos independientes para cada herramienta bioinformática

### Archivos de Configuración

- **`virtual_envs.txt`**: Lista completa de entornos bioinformáticos a crear
- **`small_virtual_envs.txt`**: Lista reducida para instalaciones de prueba o limitadas

Cada línea contiene el nombre de un paquete de conda-forge o bioconda. Se puede especificar versión: `hicexplorer=3.2`

### Uso de install_seisbio.sh

**Sintaxis:**
```bash
sudo ./install_seisbio.sh [OPCIONES]
```

### Resultado de la Fase 1

Después de ejecutar `install_seisbio.sh`:
- Usuario `seisbio` creado en `/home/seisbio/`
- Miniforge o Miniconda instalado en `/home/seisbio/miniforge/` o `/home/seisbio/miniconda/`
- Entornos virtuales creados en `/home/seisbio/miniforge/envs/` (uno por herramienta)
- Conda inicializado en `/etc/bash.bashrc` (accesible para todos los usuarios)

## Transición: Preparación del Entorno

### Descripción del script `seisbio.sh`

El script `seisbio.sh` es un auxiliar que facilita la transición entre la Fase 1 (instalación) y la Fase 2 (creación de contenedores). Su propósito es preparar el entorno del usuario `seisbio` con los archivos necesarios.

**Lo que hace:**
1. **Copia archivos necesarios**: Traslada `virtual_envs.txt`, `small_virtual_envs.txt`, `build_container.sh` y `create_container.sh` al directorio `/home/seisbio/`
2. **Cambia al usuario seisbio**: Abre una sesión interactiva como el usuario `seisbio`

### Uso de seisbio.sh

Ejecuta este script después de completar la Fase 1 y antes de iniciar la Fase 2:

```bash
./seisbio.sh
```

Este comando:
- Copiará automáticamente los archivos necesarios a `/home/seisbio/`
- Te posicionará en el directorio `/home/seisbio/`
- Abrirá una sesión como usuario `seisbio`

## Fase 2: Creación de Contenedores Apptainer

### Descripción

Una vez completada la Fase 1, los entornos conda instalados pueden convertirse en contenedores Apptainer portables que funcionan de manera independiente en cualquier sistema con Apptainer instalado.

## Descripción de los Scripts

### `crear_contenedor.sh`

Exporta los entornos conda existentes y crea archivos de definición (`.def`) para construir contenedores Apptainer.

**Lo que hace:**
- Exporta la configuración de cada entorno a un archivo `_environment.yml`
- Crea archivos `.def` con las instrucciones para construir los contenedores
- Guarda todo en la carpeta `ambientes/`

### `construir_contenedores.sh`

Construye los contenedores Apptainer (archivos `.sif`) a partir de los archivos `.def` creados previamente.

**Lo que hace:**
- Lee todos los archivos `.def` en la carpeta `ambientes/`
- Construye cada contenedor usando `apptainer build`
- Genera archivos `.sif` que son contenedores portables y autocontenidos

## Uso

### Paso 1: Dar permisos de ejecución

```bash
chmod +x crear_contenedor.sh construir_contenedores.sh
```

### Paso 2: Crear archivos de definición

**Opción A: Procesar todos los entornos**

```bash
./crear_contenedor.sh
```

Esto procesará todos los entornos conda disponibles (excepto `base`).

**Opción B: Procesar un entorno específico**

```bash
./crear_contenedor.sh -e samtools
./crear_contenedor.sh --env fastqc
```

Esto procesará únicamente el entorno especificado.

**Ver ayuda:**

```bash
./crear_contenedor.sh -h
```

### Paso 3: Construir los contenedores

**Requiere permisos de root (sudo)**

```bash
sudo ./construir_contenedores.sh
```

Este proceso puede tardar bastante tiempo, ya que:
- Descarga la imagen base de Docker (continuumio/miniconda3)
- Instala todas las dependencias dentro de cada contenedor
- Crea contenedores autocontenidos y portables

**Resultado del Paso 3:**

En la carpeta `ambientes/` se crearán:
- `<nombre>.sif` - Contenedor Apptainer listo para usar

## Uso de los Contenedores

Una vez construidos los contenedores, ejecutamos:

### Abrir una shell interactiva

```bash
./ambientes/<nombre>.sif
```

## Estructura de Archivos Resultante

```
ambientes/
├── samtools_environment.yml
├── samtools.def
├── samtools.sif
├── fastqc_environment.yml
├── fastqc.def
├── fastqc.sif
├── star_environment.yml
├── star.def
└── star.sif
.
.
.
```


