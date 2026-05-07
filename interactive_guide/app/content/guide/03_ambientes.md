# Ambientes virtuales

Crear ambientes aislados evita conflictos de dependencias y mantiene tus herramientas ordenadas.

```bash
conda create -n samtools-env -c conda-forge -c bioconda samtools
conda activate samtools-env
samtools --help
```

## Modo demostración seguro

En esta guía usamos comandos **solo informativos** (por defecto `--dry-run`) para no modificar tu sistema.  
Si quieres instalar paquetes reales, elimina `--dry-run` y confirma los cambios.
