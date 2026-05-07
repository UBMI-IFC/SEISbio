# Flujos de SEISbio

SEISbio divide su proceso en **Fase 1** (instalación) y **Fase 2** (contenedores).

## Fase 1: instalación del sistema

- Instala paquetes base y bioinformática (opcional)
- Configura Miniforge/Miniconda
- Crea ambientes por herramienta

```bash
sudo ./bin/install_seisbio.sh
```

## Transición: preparación del usuario

```bash
./bin/seisbio.sh
```

## Fase 2: contenedores Apptainer

```bash
./bin/utilities/run_container_pipeline.sh
```

> Importante: la Fase 2 requiere **apptainer** y debe ejecutarse como el usuario `seisbio`.
