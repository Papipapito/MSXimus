#!/bin/bash
# muestras de la radiografia de deltas del stream bg (out.log de vdelta)
L=/tmp/vdelta/out.log
echo "=== primeras 12 DELTA tras t=110ms (fase quieta) ==="
grep 'DELTA' $L | awk -F 't=' '{ if ($2+0 > 110000000000 && $2+0 < 130000000000) print }' | head -12
echo "=== primeras 20 DELTA tras t=240ms (fase H-scroll) ==="
grep 'DELTA' $L | awk -F 't=' '{ if ($2+0 > 240000000000) print }' | head -20
echo "=== histograma de valores de delta (todo el run) ==="
grep -o 'd=[-0-9]*' $L | sort | uniq -c | sort -rn | head -12
