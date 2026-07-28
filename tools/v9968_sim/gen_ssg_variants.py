#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_ssg_variants.py — genera las TRES variantes de vdp_timing_control_ssg.v que
compara tb_hscroll_sprite.sv (BUG #18 / parche _162, scroll horizontal de los
sprites).

  _fix : el fichero del arbol tal cual (parche _162: resta
         w_horizontal_offset_l_next, el PROXIMO valor del latch de R#27)
  _bug : el parche _120 tal como estaba antes del _162 (resta
         reg_horizontal_offset_l, el R#27 VIVO). Se obtiene sustituyendo ese
         unico operando, que es literalmente el delta del _162.
  _ref : la semantica ORIGINAL de HRA (pre-_120): el registro _120 se
         neutraliza y screen_pos_x_sprite se calcula con la MISMA expresion
         combinacional que tenia vdp_timing_control_sprite.v en el upstream
         (V9968_Cartridge 5978d18, lineas 158-159):
             w_screen_pos_x[13:4] = screen_pos_x[13:4] - { 7'd0, horizontal_offset_l };
             w_screen_pos_x[ 3:0] = screen_pos_x[ 3:0];
         Como screen_pos_x = ff_screen_pos_x y horizontal_offset_l =
         ff_horizontal_offset_l (ambos INTACTOS respecto al upstream), la
         reconstruccion es exacta.

Uso:
    python3 gen_ssg_variants.py <ssg_del_arbol.v> <outdir> [<ssg_pre_162.v>]

El tercer argumento es OPCIONAL: si se pasa un fichero anterior al _162 (por
ejemplo `git show <commit>:fpga/v9968/vdp_timing_control_ssg.v`), la variante
_bug se toma de el en vez de derivarla. Sirve para cruzar que la derivacion
textual y el fichero historico dan EXACTAMENTE los mismos resultados.
"""
import sys, os, re

def rename(src, suffix):
    out = src.replace("module vdp_timing_control_ssg (",
                      "module vdp_timing_control_ssg_%s (" % suffix)
    if out == src:
        sys.exit("ERROR: no encuentro la cabecera del modulo vdp_timing_control_ssg")
    return out

def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    fix_path, outdir = sys.argv[1], sys.argv[2]
    head_path = sys.argv[3] if len(sys.argv) > 3 else None
    os.makedirs(outdir, exist_ok=True)

    src_fix = open(fix_path, encoding='utf-8').read()

    # ---- _fix ---------------------------------------------------------------
    open(os.path.join(outdir, "ssg_fix.v"), "w", encoding='utf-8').write(rename(src_fix, "fix"))

    # ---- _bug ---------------------------------------------------------------
    if head_path:
        bug = rename(open(head_path, encoding='utf-8').read(), "bug")
    else:
        bug = rename(src_fix, "bug")
        n = bug.count("{ 7'd0, w_horizontal_offset_l_next }")
        if n != 1:
            sys.exit("ERROR: esperaba 1 uso de w_horizontal_offset_l_next en la resta, hay %d" % n)
        bug = bug.replace("{ 7'd0, w_horizontal_offset_l_next }",
                          "{ 7'd0, reg_horizontal_offset_l }")
    open(os.path.join(outdir, "ssg_bug.v"), "w", encoding='utf-8').write(bug)

    # ---- _ref ---------------------------------------------------------------
    ref = rename(src_fix, "ref")
    if len(re.findall(r"ff_screen_pos_x_sprite\s*<=", ref)) != 1:
        sys.exit("ERROR: esperaba exactamente 1 asignacion a ff_screen_pos_x_sprite")
    ref = re.sub(r"ff_screen_pos_x_sprite\s*<=[^;]*;",
                 "ff_screen_pos_x_sprite\t<= 14'd0;\t// _ref: registro _120 NEUTRALIZADO",
                 ref)
    old = "assign screen_pos_x_sprite\t= ff_screen_pos_x_sprite;"
    if old not in ref:
        sys.exit("ERROR: no encuentro el assign de screen_pos_x_sprite")
    ref = ref.replace(old,
        "\t//\t_ref: resta COMBINACIONAL, copia literal del upstream de HRA\n"
        "\t//\t(vdp_timing_control_sprite.v:158-159 de V9968_Cartridge 5978d18)\n"
        "\tassign screen_pos_x_sprite\t= { ff_screen_pos_x[13:4] - { 7'd0, ff_horizontal_offset_l }, ff_screen_pos_x[3:0] };")
    open(os.path.join(outdir, "ssg_ref.v"), "w", encoding='utf-8').write(ref)

    print("OK: ssg_ref.v / ssg_bug.v (%s) / ssg_fix.v en %s" %
          ("del fichero historico" if head_path else "derivado", outdir))

if __name__ == "__main__":
    main()
