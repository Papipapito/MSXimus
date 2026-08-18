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
# 2026-07-13 (v12): GUARD de desbordamiento — el area plana del Konami-SCC es
# 4000h-BFFFh; si el linker pasa de C000h el codigo queda INALCANZABLE y el
# ROM "compila bien" pero se corrompe en ejecucion (basura/resets, nos paso
# con la v11: Higher=C286). El build FALLA ruidosamente si se desborda.
# NOTA: msxbuild.sh deja la ROM en el arbol de MSXgl (out/), NO aqui. Se copia
# de vuelta al final: sin eso te llevas la ROM VIEJA sin enterarte.
OUT=$(bash "/mnt/c/Users/alber/proyectosAI/sdk-tools/msx-unapi-env/msxbuild.sh" "$(cd "$(dirname "$0")" && pwd)" 2>&1)
RC=$?
echo "$OUT"
HIGHER=$(echo "$OUT" | grep -oE "Higher=[0-9A-Fa-f]+h" | head -1 | sed 's/Higher=//;s/h//')
if [ -n "$HIGHER" ]; then
    if [ $((16#$HIGHER)) -gt $((16#C000)) ]; then
        echo "*** ERROR: ROM DESBORDADA: Higher=${HIGHER}h > C000h (area plana 4000-BFFF) ***"
        echo "*** El codigo por encima de C000 es INALCANZABLE: recorta o banquea ***"
        exit 2
    fi
    echo "[guard] area plana OK: Higher=${HIGHER}h (tope C000h)"
fi
exit $RC

# Traer la ROM recien compilada del arbol de MSXgl a este directorio.
FRESH="$HOME/MSXgl/projects/$(basename "$(cd "$(dirname "$0")" && pwd)")/out/$(basename "$(cd "$(dirname "$0")" && pwd)").rom"
if [ -f "$FRESH" ]; then
    cp "$FRESH" "$(cd "$(dirname "$0")" && pwd)/"
    echo "[rom] copiada desde $FRESH"
else
    echo "*** AVISO: no encuentro la ROM recien compilada en $FRESH ***"
fi
