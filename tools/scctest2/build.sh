#!/bin/bash
# build.sh — compila SCCTEST2.ROM con el entorno permanente msx-unapi-env.
#
# Uso (desde Windows PowerShell/CMD):
#   wsl -d Ubuntu-22.04 bash -c "cd '<ruta>' && bash build.sh"
# o desde una shell WSL ya situada aqui:
#   bash build.sh
#
# msxbuild.sh compila bien los targets ROM pero su paso final solo recoge
# .com (targets DOS) y sale con error: se tolera y recogemos el .rom del
# out/ del proyecto dentro de MSXgl.
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(basename "$DIR")"
ROM="$HOME/MSXgl/projects/$PROJ/out/$PROJ.rom"

rm -f "$ROM"   # evita recoger una ROM vieja si la compilacion falla

bash /mnt/c/Users/alber/proyectosAI/sdk-tools/msx-unapi-env/msxbuild.sh "$DIR" || true

if [[ ! -f "$ROM" ]]; then
	echo "[ERR] La compilacion no genero $ROM"
	exit 1
fi
cp "$ROM" "$DIR/$PROJ.rom"
echo "[OK] $DIR/$PROJ.rom ($(wc -c < "$DIR/$PROJ.rom") bytes)"
