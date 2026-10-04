#!/bin/bash
# build.sh - compila MXUPDATE.COM con el entorno permanente msx-unapi-env (MSXgl + SDCC, WSL Ubuntu-24.04).
# Desde Windows (Git Bash):
#   MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 bash -lc "cd /mnt/c/Users/alber/proyectosAI/msx/MSXimus/tools/mxupdate && bash build.sh"
exec bash "/mnt/c/Users/alber/proyectosAI/sdk-tools/msx-unapi-env/msxbuild.sh" "$(cd "$(dirname "$0")" && pwd)"
