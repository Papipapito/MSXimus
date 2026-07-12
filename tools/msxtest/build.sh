#!/bin/bash
# build.sh — compila ESTE proyecto usando el entorno permanente msx-unapi-env.
#
# Genera <nombre-de-esta-carpeta>.rom en este mismo directorio.
#
# Uso (desde Windows PowerShell/CMD):
#   wsl -d Ubuntu-22.04 bash -c "cd '<ruta>' && bash build.sh"
# o desde una shell WSL ya situada aqui:
#   bash build.sh
#
# 2026-07-12: ruta actualizada tras la reubicacion del workspace
# (C:\Users\alber\msx-unapi-env -> proyectosAI\sdk-tools\msx-unapi-env).
exec bash "/mnt/c/Users/alber/proyectosAI/sdk-tools/msx-unapi-env/msxbuild.sh" "$(cd "$(dirname "$0")" && pwd)"
