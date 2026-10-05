# ============================================================================
# medir_area.ps1 — SOLO SINTESIS, para medir el area por modulo sin esperar al
# rutado (2-3 min en vez de 25-40). Es el instrumento de la dieta del 16/09.
#
# Copia fpga/ a un directorio de trabajo (como lanzar_campana.ps1: con la
# config V9968 + VRAM en DDR3 aplicada por sed), quita el `run pnr` del
# build.tcl y lanza gw_sh EN PRIMER PLANO. Al acabar imprime la tabla de LUT /
# FF / ALU / BSRAM por modulo de primer nivel, sacada de
# impl/gwsynthesis/project_syn_rsc.xml, y la deja tambien en <Nombre>_area.txt.
#
# Uso:
#   .\tools\medir_area.ps1 -Nombre base                  # el arbol del repo tal cual
#   .\tools\medir_area.ps1 -Nombre sin_diag -Define "DIETA_SIN_DIAG"
#   .\tools\medir_area.ps1 -Nombre x -Root C:\otra\copia  # otro arbol (una variante)
#
# -Define anade `define <X> al principio de top.v (varios: -Define A,B).
# Los numeros de sintesis NO son los del rutado (el CLS del place es otra
# cosa: ver msximus_cls_congestion_no_area), pero sirven para saber CUANTO
# quita cada cambio y en que dominio, que es lo que hace falta para decidir.
# ============================================================================
param(
    [Parameter(Mandatory=$true)][string] $Nombre,
    [string[]] $Define = @(),
    # dado (PERIOD_MS del dbg_uart) como en lanzar_campana; 0 = el del repo (250).
    # Sirve para comprobar que el dado PERTURBA el netlist: dos sintesis con
    # dados distintos tienen que dar LUTs distintas en u_dbguart.
    [int] $Dado = 0,
    [string] $Root    = 'C:\Users\alber\proyectosAI\msx\MSXimus',
    [string] $Scratch = "$env:LOCALAPPDATA\Temp\claude\area",
    [string] $Gowin   = 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Gowin)) { throw "No esta el gw_sh en $Gowin" }

$dst = Join-Path $Scratch $Nombre
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
New-Item -ItemType Directory -Path "$dst\fpga" -Force | Out-Null
robocopy "$Root\fpga" "$dst\fpga" /E /NFL /NDL /NJH /NJS /NP /XD impl opl4_20k_est zynq /XF build_*.log | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy fallo (codigo $LASTEXITCODE)" }

if ($Dado -gt 0) {
    $pu = "$dst\fpga\src\dbg_uart.v"
    Set-Content -Path $pu -NoNewline -Value ((Get-Content $pu -Raw).Replace('PERIOD_MS = 250', "PERIOD_MS = $Dado"))
    if ((Get-Content $pu -Raw) -notmatch "PERIOD_MS = $Dado") { throw "no se aplico el dado" }
}

# misma config que la campana: V9968 + VRAM en DDR3
$pt = "$dst\fpga\top.v"
$tt = (Get-Content $pt -Raw).
          Replace('//`define ENABLE_V9968_VDP', '`define ENABLE_V9968_VDP').
          Replace('//`define ENABLE_VRAM_DDR3', '`define ENABLE_VRAM_DDR3')
foreach ($d in $Define) { $tt = "``define $d`r`n" + $tt }
Set-Content -Path $pt -NoNewline -Value $tt
$pb = "$dst\fpga\build.tcl"
$tb = (Get-Content $pb -Raw).
          Replace('set USE_V9968 0', 'set USE_V9968 1').
          Replace('set USE_VRAM_DDR3 0', 'set USE_VRAM_DDR3 1')
$tb = $tb -replace '(?m)^run pnr\s*$', '# run pnr   (medir_area: solo sintesis)'
Set-Content -Path $pb -NoNewline -Value $tb

Write-Output ("sintesis '{0}' (defines: {1}) ..." -f $Nombre, ($Define -join ', '))
$t0 = Get-Date
Push-Location (Join-Path $dst 'fpga')
try { & $Gowin build.tcl 2>&1 | Out-File "$dst\syn.log" } finally { Pop-Location }
$xml = "$dst\fpga\impl\gwsynthesis\project_syn_rsc.xml"
if (-not (Test-Path $xml)) {
    Get-Content "$dst\syn.log" | Select-String -Pattern 'ERROR' | Select-Object -First 5
    throw "no hay project_syn_rsc.xml: mira $dst\syn.log"
}
Write-Output ("  {0:n0} s" -f ((Get-Date) - $t0).TotalSeconds)

$py = @'
import xml.etree.ElementTree as ET, sys
t = ET.parse(sys.argv[1]).getroot()
def tot(e, k):
    v = e.get("T_"+k); return int(v.split("(")[0]) if v else 0
rows = sorted(((tot(sm,"Lut"), tot(sm,"Register"), tot(sm,"Alu"), tot(sm,"Bsram"), sm.get("name")) for sm in t), reverse=True)
print(f"TOTAL  LUT {tot(t,'Lut')}  FF {tot(t,'Register')}  ALU {tot(t,'Alu')}  BSRAM {tot(t,'Bsram')}   (propio del top: LUT {t.get('Lut')} FF {t.get('Register')} ALU {t.get('Alu')})")
print(f"{'LUT':>6} {'FF':>6} {'ALU':>5} {'BSR':>4}  modulo")
for l,r,a,b,n in rows:
    if l+r >= 100: print(f"{l:>6} {r:>6} {a:>5} {b:>4}  {n}")
'@
$pyf = Join-Path $dst 'tabla.py'
Set-Content -Path $pyf -Value $py
$tabla = & python $pyf $xml
$tabla | Tee-Object -FilePath (Join-Path $Scratch "$Nombre`_area.txt")
