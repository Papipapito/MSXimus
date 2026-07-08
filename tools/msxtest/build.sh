#!/bin/bash
# build.sh — compila ESTE proyecto usando el entorno permanente msx-unapi-env.
#
# Genera <nombre-de-esta-carpeta>.com en este mismo directorio.
#
# Uso (desde Windows PowerShell/CMD):
#   wsl -d Ubuntu-22.04 bash -c "cd '<ruta>' && bash build.sh"
# o desde una shell WSL ya situada aqui:
#   bash build.sh
exec bash "/mnt/c/Users/alber/msx-unapi-env/msxbuild.sh" "$(cd "$(dirname "$0")" && pwd)"
