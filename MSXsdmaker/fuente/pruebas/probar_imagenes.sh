#!/bin/bash
# probar_imagenes.sh — comprueba MSXsdmaker con herramientas que no son suyas (WSL / Linux):
#   sfdisk (la tabla de particiones), fsck.fat -n (cada particion) y mtools (se extrae la de arranque y se compara con
#   un arbol de referencia hecho con cp desde packs/sd). mtools sin root: apt-get download mtools && dpkg -x en ~/g3tools/mt.
# Uso: bash probar_imagenes.sh [dir de trabajo]      (por defecto ~/sdimg)
set -u
S="$(cd "$(dirname "$0")/.." && pwd)"
SD="$S/../../packs/sd"
W="${1:-$HOME/sdimg}"; mkdir -p "$W"
MT="$HOME/g3tools/mt/usr/bin"
export MTOOLS_SKIP_CHECK=1
fallos=0

referencia() {   # $1 = sistema, $2 = destino: el arbol esperado de la particion 1 con "todos" los programas
    local d="$2"; rm -rf "$d"; mkdir -p "$d"
    case "$1" in
        nextor214) cp -r "$SD/nextor-2.1.4/." "$d/";;
        nextor3)   cp -r "$SD/nextor-3.0.0-beta1/." "$d/";;
        msxdos)    for f in MSXDOS2.SYS COMMAND2.COM MSXDOS.SYS COMMAND.COM; do cp "$SD/nextor-2.1.4/$f" "$d/"; done;;
    esac
    for x in base/MM base/UTIL base/WIFI base/FONTS base/musica extras/SOFARUN extras/hub extras/IA extras/mapper extras/indev.com; do
        cp -r "$SD/$x" "$d/"
    done
    mkdir -p "$d/SAVES" "$d/SETTINGS" "$d/FHUNT" "$d/TMP"
    find "$d" \( -iname 'ruvector.db' -o -iname '*.bak' -o -iname '*.tmp' -o -name '.*' -o -iname 'thumbs.db' \
        -o -iname 'desktop.ini' -o -iname 'nextor.emu' \) -exec rm -rf {} + 2>/dev/null
}

caso() {   # nombre tamano_imagen sistema opciones...
    local n="$1" tam="$2" sis="$3"; shift 3
    local img="$W/$n.img"
    echo "================ $n: $tam, $sis, $*"
    rm -f "$img"
    if ! python3 "$S/MSXsdmaker.py" imagen "$img" --tamano "$tam" --sistema "$sis" "$@" > "$W/$n.log" 2>&1; then
        echo "FALLO: MSXsdmaker"; tail -5 "$W/$n.log"; fallos=$((fallos+1)); return
    fi
    grep -E "ERROR|^ +P[0-9]|sin usar" "$W/$n.log"
    sfdisk -d "$img" 2>&1 | grep -E "^/|label" | sed "s|$W/||"
    local k=0
    while read -r ini tam_p; do
        k=$((k+1))
        dd if="$img" of="$W/p.img" bs=512 skip="$ini" count="$tam_p" status=none conv=sparse
        if fsck.fat -n "$W/p.img" > "$W/fsck.txt" 2>&1; then
            echo "  P$k fsck.fat: OK ($(grep -oE '[0-9]+ files, [0-9/]+ clusters' "$W/fsck.txt"))"
        else
            echo "  P$k fsck.fat: FALLO"; cat "$W/fsck.txt" | head -8; fallos=$((fallos+1))
        fi
        if [ $k -eq 1 ] && [ "$sis" != ninguno ]; then
            rm -rf "$W/sacado"; mkdir -p "$W/sacado"
            "$MT/mcopy" -s -n -m -i "$W/p.img" ::/ "$W/sacado/" 2>/dev/null
            referencia "$sis" "$W/ref"
            rm -f "$W/sacado/AUTOEXEC.BAT"
            if diff -r "$W/ref" "$W/sacado" > "$W/diff.txt" 2>&1; then
                echo "  P1 contenido: IDENTICO a la referencia ($(find "$W/ref" -type f | wc -l) ficheros)"
            else
                echo "  P1 contenido: DISTINTO"; head -8 "$W/diff.txt"; fallos=$((fallos+1))
            fi
            "$MT/mtype" -i "$W/p.img" ::/AUTOEXEC.BAT | tr -d '\r\032' | sed 's/^/     | /' | grep -iE "PATH|mapdrv|Maped|CALL"
            echo "  P1 raiz: $("$MT/mdir" -i "$W/p.img" -b ::/ | tr '\n' ' ' | sed 's|::/||g')"
        fi
    done < <(sfdisk -d "$img" 2>/dev/null | grep -E "^/" | grep -v "type=f" | sed -E 's/.*start= *([0-9]+), size= *([0-9]+).*/\1 \2/')
}

caso a_3x200M 1G nextor214 --esquema fat16-2g --n 3 --tam-particion 200M
caso b_2x2G 6G nextor3 --esquema fat16-2g --n 2 --resto
caso c_1x4G_resto 9G nextor214 --esquema fat16-4g --n 2 --resto
caso d_fat32 16G nextor214 --esquema fat32
caso e_msxdos 1G msxdos --esquema fat16-2g --n 1 --tam-particion 300M --programas todos
caso f_vacia 5G ninguno --esquema fat16-2g --n 2 --programas ninguno
caso g_8part 20G nextor214 --esquema fat16-2g --n 8
echo "PRUEBAS: $fallos fallos"
