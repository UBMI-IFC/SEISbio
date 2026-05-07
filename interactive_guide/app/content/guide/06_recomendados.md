# Flujos recomendados y troubleshooting

## Recomendado: instalación ligera

- Usa `envs/small_virtual_envs.txt` para ambientes de ejemplo
- Ejecuta primero en un equipo de prueba
- Mantén `--dry-run` mientras revisas comandos

## Recomendado: instalación completa

- Revisa espacio en disco (contenedores `.sif` pueden ser grandes)
- Confirma que **apptainer** esté instalado antes de Fase 2
- Usa `run_container_pipeline.sh -e <env>` para probar con un solo entorno

## Problemas comunes

- **Conda no está en PATH**: reinicia la terminal o revisa `/etc/bash.bashrc`.
- **Permisos insuficientes**: usa `sudo` solo cuando el script lo requiere.
- **Apptainer no instalado**: instala el paquete antes de crear contenedores.
