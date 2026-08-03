#!/bin/bash
# ============================================================================
# run_cmdthrash_all.sh — lanza las TRES variantes de run_cmdthrash.sh y resume.
#
# Existe por dos razones practicas, las dos aprendidas a golpes:
#  1) Pasar un bucle con $VAR desde la herramienta PowerShell a wsl.exe NO
#     funciona: la variable llega VACIA aunque se usen comillas simples. Con el
#     bucle dentro de un script en disco el problema desaparece.
#  2) Las tres corridas van EN PARALELO: cada una tarda minutos y en serie no
#     caben en una sola llamada.
#
# Uso:  bash run_cmdthrash_all.sh [segundos_por_corrida]    (por defecto 800)
# ============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SECS="${1:-800}"
cd "$HERE" || exit 1
mkdir -p logs

for V in A B C; do
    ( bash run_cmdthrash.sh "$V" "$SECS" > "logs/ct_$V.out" 2>&1 ) &
done
wait

echo ""
echo "======================= RESUMEN ======================="
for V in A B C; do
    echo ""
    echo "########## VARIANTE $V ##########"
    grep -E 'SETUP|CMDTRAF' "logs/ct_$V.out" | tail -n 3
    grep -E 'SPTEL' "logs/ct_$V.out" | tail -n 6
    grep -E 'SPCLS' "logs/ct_$V.out" | tail -n 6
done
echo ""
echo "logs completos en $HERE/logs/ct_[ABC].out"
