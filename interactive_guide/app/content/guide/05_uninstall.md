# Desinstalar SEISbio

SEISbio soporta desinstalación **local** (usuario actual) o **sistema completo**.

```bash
# Local (sin root)
./bin/uninstall_seisbio.sh --local

# Sistema completo (con root)
sudo ./bin/uninstall_seisbio.sh
```

> Advertencia: el modo sistema elimina el usuario `seisbio` y su directorio home.
