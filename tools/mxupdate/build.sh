#!/bin/bash
# build.sh - compila MXUPDATE.COM con el entorno permanente msx-unapi-env (MSXgl + SDCC, WSL Ubuntu-24.04).
# Desde Windows (Git Bash), con el repositorio visible en WSL:
#   MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 bash -lc "cd <repositorio>/tools/mxupdate && bash build.sh"
# MSX_UNAPI_ENV = la carpeta del entorno msx-unapi-env (MSXgl + SDCC); por defecto ~/sdk-tools/msx-unapi-env.
exec bash "${MSX_UNAPI_ENV:-$HOME/sdk-tools/msx-unapi-env}/msxbuild.sh" "$(cd "$(dirname "$0")" && pwd)"
