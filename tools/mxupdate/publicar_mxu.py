"""publicar_mxu.py - deja MXUPDATE.COM listo para la web: servidor/mxupdate/{MXUPDATE.COM, manifiesto.txt}.

Las placas lo piden desde el propio MXUPDATE (autoactualizacion, antes de mirar las suyas): si la version de aqui es
mayor que la suya, se lo bajan y se relanzan. La version sale del cartel del .COM ("MXUPDATE x.y - "), el mismo que
compara y verifica MXUPDATE, y tiene que coincidir con MXU_VERSION de mxupdate.c.

Cada version nueva de MXUPDATE: subir MXU_VERSION, build.sh, banco/run.sh (todo bien), este script y
    python ota_subir.py mxupdate            (MSXimus_zynq/fpga/zynq/ota: comprueba, sube y relee por https)
y el .COM nuevo a las releases del 60K, del 138K y del MSXnano y a SD_Maker (sd/extras/FPGA).

    python publicar_mxu.py [--dir carpeta_servidor]
"""
import argparse
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
SERVIDOR = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "MSXimus_zynq", "fpga", "zynq", "ota", "servidor"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=SERVIDOR, help="carpeta servidor/ (la de ota_subir.py)")
    a = ap.parse_args()
    com = open(os.path.join(AQUI, "mxupdate.com"), "rb").read()
    fuente = open(os.path.join(AQUI, "mxupdate.c"), encoding="utf-8").read()
    m = re.search(r'#define MXU_VERSION "([0-9.]+)"', fuente)
    carteles = re.findall(rb"MXUPDATE ([0-9]+(?:\.[0-9]+)+) - ", com)
    if not m or len(carteles) != 1 or carteles[0].decode() != m.group(1):
        sys.exit("el cartel del .COM (%s) no es el MXU_VERSION de mxupdate.c (%s): vuelve a compilar"
                 % (carteles, m and m.group(1)))
    version = m.group(1)
    d = os.path.join(a.dir, "mxupdate")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "MXUPDATE.COM"), "wb").write(com)
    man = ("MSXIMUS-UPD 1\nplaca=mxupdate\nversion=%s\nimagen=mxupdate MXUPDATE.COM %d\n"
           "completa=mxupdate MXUPDATE.COM %d\n" % (version, len(com), len(com)))
    open(os.path.join(d, "manifiesto.txt"), "w", newline="\n").write(man)
    print("%s: MXUPDATE %s (%d bytes)" % (d, version, len(com)))


if __name__ == "__main__":
    main()
