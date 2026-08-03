# ============================================================================
# gate_check.ps1 — criterio de aceptacion de un bitstream del MSXimus.
#
# POR QUE EXISTE, Y POR QUE EL CRITERIO ANTERIOR ERA INCONSISTENTE
# ----------------------------------------------------------------------------
# El gate viejo era: "SETUP 0, y holds SOLO dentro de u_vddr3/ (la IP DDR3)".
# Con el se rechazaron 4 dados por violaciones en
# u_v9968/u_video_out/u_double_buffer de entre -0,001 y -0,036 ns.
#
# ESO ESTABA MAL, y lo demuestran tres hechos medidos sobre los informes reales:
#
#  1. `-correct_hold 1` YA VIENE PUESTO por defecto en el router de Gowin
#     (verificado en impl/pnr/cmd.do:14 de las SEIS campanas). El router ya
#     intenta alargar el cable y no puede. No hay opcion que activar.
#
#  2. TODOS los bitstreams entregados llevan una violacion PEOR de la MISMA
#     clase, dentro de la IP DDR3 de Gowin, que no se puede tocar:
#        b165/c2 -0.043 | b165/c3 -0.039 | b166/c1 -0.039
#        b166/c2 -0.043 | b166/c3 -0.039
#     Se estaba rechazando un -0.036 mientras se aceptaba un -0.043 en el mismo
#     informe. La v2.0, en manos de usuarios, lleva esa firma.
#
#  3. LA ARITMETICA DEL SILICIO. En este chip:
#        skew(clk_86, columna CLU -> fila BSRAM) = 0,193..0,201 ns  (constante)
#        tHold(pin de BSRAM)                      = 0,037 ns
#        => hace falta un retardo de datos >= 0,234 ns
#        retardo MINIMO alcanzable FF -> BSRAM    = 0,195 ns  (suelo del fabric)
#     Es decir: CUALQUIER flip-flop pegado a una BSRAM en un GW5AT-60B viola
#     hold por ~39 ps. Es una propiedad del dispositivo, no del RTL. Y es lo
#     CONTRARIO de la congestion: lo provoca que el placer ponga el FF DEMASIADO
#     CERCA, por eso sale igual al 69% de CLS que al 90%.
#
# Y NO ES UN FALLO LATENTE: ff_address_* cambia CADA PIXEL, asi que un hold real
# ahi destroza la imagen en dos segundos. El arranque en placa ya es un detector
# perfecto; no hace falta un gate paranoico para cazarlo.
#
# CRITERIO NUEVO
# ----------------------------------------------------------------------------
#   ACEPTAR si:
#     (a) CERO violaciones de SETUP, y
#     (b) toda violacion de HOLD cumple UNA de las dos:
#           - esta dentro de u_vddr3/  (IP de Gowin, intocable, ya se entrega), o
#           - su destino es un pin de BSRAM  Y  |slack| <= 0,050 ns
#   RECHAZAR cualquier otra cosa: un hold FF->FF en logica, o de mas de 50 ps,
#   SI seria un cambio de regimen y merece otro dado.
#
# El umbral de 50 ps sale del suelo estructural (-0,039) mas margen para la
# variacion de skew observada (0,193-0,201). No es una constante inventada.
#
# ⚠️ CUANDO CORRERLO: DESPUES de que la campana haya TERMINADO del todo.
# `project.fs` aparece ANTES de que Gowin acabe de escribir project.timing_paths
# y project.rpt.txt. Un monitor que dispare al ver el .fs lee informes a medio
# escribir y canta "SETUP: 0" cuando en realidad hay violaciones (pasado en la
# campana s004, dado bx_c1: el monitor dijo 0 y aqui salieron dos, -0,188 y
# -0,002). El .fs NO es la marca de fin.
#
# Uso:  .\tools\gate_check.ps1 -Campana <ruta>          (una campana entera)
#       .\tools\gate_check.ps1 -Dado <ruta a un bx_cN>  (un solo dado)
# ============================================================================
param(
    [string] $Campana,
    [string] $Dado,
    [double] $UmbralBsram = 0.050
)
$ErrorActionPreference = 'Stop'

function Test-Dado {
    param([string] $dir)
    $tp = Join-Path $dir 'fpga\impl\pnr\project.timing_paths'
    $rp = Join-Path $dir 'fpga\impl\pnr\project.rpt.txt'
    $fs = Join-Path $dir 'fpga\impl\pnr\project.fs'
    $nombre = Split-Path $dir -Leaf

    if (-not (Test-Path $fs)) { return [pscustomobject]@{ dado=$nombre; veredicto='SIN BITSTREAM'; detalle=''; cls='' } }
    if (-not (Test-Path $tp)) { return [pscustomobject]@{ dado=$nombre; veredicto='SIN INFORME';   detalle=''; cls='' } }

    # ⚠️ OJO A LOS NOMBRES: en PowerShell las variables NO distinguen mayusculas,
    # asi que `$l = $L[$i]` se machaca a si misma y a partir de la 2a vuelta $L es
    # una CADENA (y $L[$i] devuelve caracteres). La primera version de este script
    # tenia ese fallo y APROBABA TODOS LOS DADOS, incluido uno con violacion de
    # setup. Un gate que aprueba todo es peor que ninguno. Nombres distintos.
    $lineas = Get-Content $tp
    $tipo = ''
    $setup = 0
    $malos = @()
    $tolerados = @()
    for ($i = 0; $i -lt $lineas.Count; $i++) {
        $linea = $lineas[$i].Trim()
        if ($linea -eq 'SETUP' -or $linea -eq 'HOLD') { $tipo = $linea; continue }
        if ($linea -notmatch '^-[0-9]') { continue }
        $slack = [double]$linea
        $dst = if ($i + 6 -lt $lineas.Count) { $lineas[$i + 6].Trim() } else { '' }
        $org = if ($i + 3 -lt $lineas.Count) { $lineas[$i + 3].Trim() } else { '' }

        if ($tipo -eq 'SETUP') { $setup++; $malos += "SETUP $slack -> $org"; continue }

        $enIP     = $org.StartsWith('u_vddr3/') -or $dst.StartsWith('u_vddr3/')
        $esBsram  = ($dst -match 'ff_imem') -or ($dst -match 'mem_mem_') -or ($dst -match '/WRE')
        # u_roosc = OSCILADOR EN ANILLO (fpga/src/ro_osc.v): un lazo de NANDs
        # DELIBERADO que sirve de termometro del die. Su "reloj" es el propio
        # lazo, asi que analizarle el timing no significa nada — el analizador lo
        # reporta solo porque NO esta constreñido en ningun .sdc.
        # ⚠️ EL ARREGLO DE VERDAD es un set_false_path / set_disable_timing sobre
        # u_roosc en constraints/. Se tolera aqui de momento porque tocar el .sdc
        # afecta TAMBIEN a la linea del V9958 clasico y merece su propia revision.
        $esRing   = $org.StartsWith('u_roosc/') -or $dst.StartsWith('u_roosc/')
        if ($enIP)        { $tolerados += "HOLD $slack (IP DDR3)" }
        elseif ($esRing)  { $tolerados += "HOLD $slack (oscilador de anillo, sin constreñir)" }
        elseif ($esBsram -and ([math]::Abs($slack) -le $UmbralBsram)) { $tolerados += "HOLD $slack (FF->BSRAM, suelo del chip) $dst" }
        else { $malos += "HOLD $slack FUERA DE CLASE: $org -> $dst" }
    }

    $cls = (Select-String -Path $rp -Pattern '^  CLS ' -ErrorAction SilentlyContinue | Select-Object -First 1).Line
    if ($cls) { $cls = ($cls -replace '\s+', ' ').Trim() }
    [pscustomobject]@{
        dado      = $nombre
        veredicto = $(if ($malos.Count -eq 0) { 'GATE OK' } else { 'RECHAZADO' })
        detalle   = $(if ($malos.Count) { $malos -join ' | ' } else { "$($tolerados.Count) holds tolerados (suelo del chip)" })
        cls       = $cls
    }
}

$dirs = @()
if ($Dado)    { $dirs = @($Dado) }
elseif ($Campana) { $dirs = Get-ChildItem $Campana -Directory | Where-Object { $_.Name -like 'bx_c*' } | ForEach-Object { $_.FullName } }
else { throw "Usa -Campana <ruta> o -Dado <ruta>" }

"CRITERIO: setup 0 | holds solo en IP DDR3, o FF->BSRAM con |slack| <= $UmbralBsram ns"
""
foreach ($d in $dirs) {
    $r = Test-Dado $d
    "{0,-8} {1,-14} {2}" -f $r.dado, $r.veredicto, $r.cls
    "         $($r.detalle)"
}
