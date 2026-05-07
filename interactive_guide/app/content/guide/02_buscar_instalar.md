# Buscar e instalar paquetes

## Buscar paquetes

```bash
conda search -c conda-forge numpy
conda search -c bioconda samtools
```

## Instalar paquetes (recomendado)

```bash
conda install -c conda-forge -c bioconda samtools
```

> Tip: evita el canal `defaults` para bioinformática y prioriza `conda-forge` + `bioconda`.
