# ============================================================================
# lanzar_campana.ps1 — lanzador de campanas de sintesis del MSXimus.
#
# DOS LINEAS DE BUILD, UN SOLO CODIGO FUENTE:
#
#   COMPLETA (-Slim ausente) : lo que va a PRODUCCION. Todo el audio dentro.
#                              ~90% de CLS, rutado 40-50 min, y ~1 de cada 3
#                              dados no entrega.
#
#   LIGERA   (-Slim)         : carril de DESARROLLO del V9968. Apaga el audio
#                              grande (MoonSound FM+wavetable, MSX-Audio Y8950 +
#                              ADPCM-B, OPLL). ~69% de CLS previsto, rutado de
#                              minutos, dados que entregan siempre.
#
# POR QUE EXISTE LA LIGERA. Al 90% de CLS el rutado tarda 13-23x mas que al 66%
# y uno de cada tres dados se queda clavado. Eso significa que cada intento de
# arreglo cuesta ~1,5 campanas (hora y media) y por eso se cometen errores: no
# se puede permitir uno probar cosas. Con la ligera se prueban cinco ideas en
# una tarde y solo lo que sobrevive se lleva a la completa.
#
# Y ADEMAS ES UN INSTRUMENTO DE DIAGNOSTICO, no solo un atajo: si un fallo
# reproduce en LIGERA es de LOGICA; si solo aparece en COMPLETA es de
# CONTENCION de memoria. Hoy no tenemos ninguna otra forma de separar las dos.
#
# ⚠️ LO QUE LA LIGERA **NO** PUEDE VALIDAR. Quitar el audio quita clientes de la
# DDR3/SDRAM (uopl4pcm streamea de DDR3), asi que baja la presion de memoria.
# Todo defecto cuya MAGNITUD dependa de esa presion hay que REVALIDARLO en la
# completa antes de darlo por curado. En concreto: el desalojo de la sc-cache
# por lecturas del motor de comandos, y el cuelgue de arranque de la rc5.
# Lo que SI cierra la ligera: logica pura (167b7cf), colisiones deterministas
# (el alias SAT/SPT), timing/placement (la ruta de hold del u_double_buffer) y
# pruebas funcionales de modos de pantalla.
#
# LO QUE NO CAMBIA ENTRE LAS DOS LINEAS: el camino de memoria del V9968. Su VRAM
# sigue en DDR3, mismo backend y mismo shim. Solo desaparece el trafico de OTROS
# clientes. Verificado ademas que apagar el audio no puede desviar el mapa de
# memoria: ENABLE_ADPCM_SDRAM se DERIVA de ENABLE_Y8950_ADPCM (top.v:44-52), asi
# que al apagarlo la derivacion se cortocircuita sola y es imposible por
# construccion que aparezca un segundo driver de wv2.
#
# Uso:
#   .\tools\lanzar_campana.ps1 -Campana b167 -Dados 1201,1213,1217
#   .\tools\lanzar_campana.ps1 -Campana s001 -Dados 1223,1229,1231 -Slim
#
# Los dados son NUMEROS PRIMOS que van al PERIOD_MS de dbg_uart.v: perturban el
# placement sin cambiar la funcion (solo el periodo de la telemetria del COM11).
# Serie ya gastada: 457 467 479 491 499 509 521 541 557 563 569 577 1033 1049
# 1061 1129 1151 1163 1171 1181 1187 1193.
# ============================================================================
param(
    [Parameter(Mandatory=$true)][string]   $Campana,
    [Parameter(Mandatory=$true)][int[]]    $Dados,
    [switch] $Slim,
    [string] $Root    = 'C:\Users\alber\proyectosAI\msx\MSX_up',
    [string] $Scratch = "$env:LOCALAPPDATA\Temp\claude\campanas",
    [string] $Gowin   = 'C:\Gowin\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe'
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Gowin)) { throw "No esta el gw_sh Education en $Gowin. Las builds van SIEMPRE con 1.9.11.03 Education." }
if ($Dados.Count -lt 1)      { throw "Hacen falta dados." }

# El audio grande. Se apagan los OCHO juntos porque tienen dependencias entre si
# (ENABLE_OPL4_WAVE requiere WAVE_DDR3 + WAVE_LOADER, ver top.v:28).
# NO se tocan PSG ni SCC: juntos son ~1.300 de logica y sin ellos el software se
# comporta raro, que estorbaria justo a las pruebas de video.
$audio = @(
    'ENABLE_OPLL', 'ENABLE_Y8950', 'ENABLE_Y8950_ADPCM', 'ENABLE_Y8950_IRQ',
    'ENABLE_OPL4FM', 'ENABLE_WAVE_DDR3', 'ENABLE_WAVE_LOADER', 'ENABLE_OPL4_WAVE'
)

$base = Join-Path $Scratch $Campana
Write-Output ("LINEA: {0}" -f $(if ($Slim) { 'LIGERA (desarrollo V9968)' } else { 'COMPLETA (produccion)' }))
Write-Output ("campana {0}  dados {1}" -f $Campana, ($Dados -join ', '))
Write-Output ""

$i = 0
foreach ($d in $Dados) {
    $i++
    $c   = "bx_c$i"
    $dst = Join-Path $base $c
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    New-Item -ItemType Directory -Path "$dst\fpga" -Force | Out-Null

    robocopy "$Root\fpga" "$dst\fpga" /E /NFL /NDL /NJH /NJS /NP /XD impl opl4_20k_est /XF build_*.log | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy fallo para $c (codigo $LASTEXITCODE)" }

    # ---- dado ----
    $p = "$dst\fpga\src\dbg_uart.v"
    Set-Content -Path $p -NoNewline -Value ((Get-Content $p -Raw).Replace('PERIOD_MS = 250', "PERIOD_MS = $d"))
    if ((Get-Content $p -Raw) -notmatch "PERIOD_MS = $d") { throw "$c : no se aplico el dado" }

    # ---- config V9968 + VRAM en DDR3 ----
    # La rama main guarda por defecto la config V9958 CLASICA; la del V9968 se
    # produce PARCHEANDO LA COPIA. Son cuatro interruptores que van en sintonia
    # (lo dice build.tcl:114). Sin ellos la sintesis muere en 2 minutos con
    # ERROR (CT1135) ... Can't find object named 'u_vddr3/.../u_dll'.
    $pt = "$dst\fpga\top.v"
    $tt = (Get-Content $pt -Raw).
              Replace('//`define ENABLE_V9968_VDP', '`define ENABLE_V9968_VDP').
              Replace('//`define ENABLE_VRAM_DDR3', '`define ENABLE_VRAM_DDR3')

    # ---- linea LIGERA: fuera el audio grande ----
    if ($Slim) {
        foreach ($a in $audio) {
            $tt = $tt.Replace("``define $a", "//``define $a")
        }
    }
    Set-Content -Path $pt -NoNewline -Value $tt

    $pb = "$dst\fpga\build.tcl"
    Set-Content -Path $pb -NoNewline -Value ((Get-Content $pb -Raw).
              Replace('set USE_V9968 0', 'set USE_V9968 1').
              Replace('set USE_VRAM_DDR3 0', 'set USE_VRAM_DDR3 1'))

    # ---- verificacion ANTES de gastar la campana ----
    $tt = Get-Content $pt -Raw; $tb = Get-Content $pb -Raw
    if ($tt -match '(?m)^//`define ENABLE_V9968_VDP')  { throw "$c : ENABLE_V9968_VDP sigue comentado" }
    if ($tt -match '(?m)^//`define ENABLE_VRAM_DDR3')  { throw "$c : ENABLE_VRAM_DDR3 sigue comentado" }
    if ($tb -notmatch 'set USE_V9968 1')               { throw "$c : USE_V9968 no es 1" }
    if ($tb -notmatch 'set USE_VRAM_DDR3 1')           { throw "$c : USE_VRAM_DDR3 no es 1" }
    foreach ($a in $audio) {
        $on = $tt -match "(?m)^``define $a"
        if ($Slim -and $on)        { throw "$c : $a sigue ENCENDIDO en una build ligera" }
        if ((-not $Slim) -and -not $on) { throw "$c : $a esta APAGADO en una build completa" }
    }

    $pr = Start-Process -FilePath $Gowin -ArgumentList 'build.tcl' -WorkingDirectory "$dst\fpga" `
             -RedirectStandardOutput "$dst\build.log" -RedirectStandardError "$dst\build.err" `
             -PassThru -WindowStyle Hidden
    Write-Output ("  lanzado {0}  dado={1}  pid={2}" -f $c, $d, $pr.Id)
}

Write-Output ""
Write-Output "Bitstream en $base\bx_c*\fpga\impl\pnr\project.fs"
Write-Output ""
Write-Output "GATE: NO lo compruebes a mano. Cuando acaben:"
Write-Output ("    .\tools\gate_check.ps1 -Campana {0}" -f $base)
Write-Output ""
Write-Output "  El criterio es: SETUP 0, y holds solo en la IP DDR3 o FF->BSRAM"
Write-Output "  con |slack| <= 50 ps. Ese suelo es del CHIP, no del diseno:"
Write-Output "  skew 0,197 + tHold 0,037 = 0,234 ns necesarios contra un minimo"
Write-Output "  alcanzable de 0,195 => cualquier FF pegado a una BSRAM viola por"
Write-Output "  ~39 ps, y la propia IP de Gowin lo hace en el 100% de los dados."
Write-Output "  El criterio VIEJO ('holds solo en u_vddr3') rechazaba dados por"
Write-Output "  -0,036 mientras aceptaba -0,043 en el mismo informe: tiraba ~1 de"
Write-Output "  cada 3 tiradas por nada."
