# ============================================================================
# encadenar_campanas.ps1 — tira campanas UNA TRAS OTRA hasta que un dado pase el
# gate, alternando variantes del build (place_option 1 = default del repo,
# place_option 2 = variante), y para solo. Es el "plan 1+2" del 16/09 noche:
# con el yield al 10-20 % la unica palanca sin ingenieria es tirar mas dados.
#
# Cada campana va por lanzar_campana.ps1 (5 dados, linea completa); cuando no
# queda ningun gw_sh se pasa gate_check.ps1 y se apunta el resultado en
# <Scratch>\encadenadas_<Etiqueta>.txt. Se PARA en cuanto un dado da GATE OK
# (el margen >= 0,4 ns se comprueba a mano despues, con gowin_timing) o al
# agotar las campanas. Pensado para correr de noche: Start-Process -WindowStyle
# Hidden ... y mirar el .txt por la manana.
#
# Uso (la lista va en un JSON, ver -Json):
#   .\tools\encadenar_campanas.ps1 -Etiqueta noche17 -Json campanas.json
#   campanas.json = [ {"Nombre":"v36n","Dados":[3847,3851,3853,3863,3877],"Variante":"po1"},
#                     {"Nombre":"v36o","Dados":[3881,3889,3907,3911,3917],"Variante":"po2"}, ... ]
#   Una entrada con "Root":"<carpeta>" usa ese arbol en vez del repo (campana
#   de control sobre otro commit; la carpeta debe contener fpga\).
#   Una entrada con "SoloGate":true no se lanza: se espera a que acaben los
#   gw_sh que ya corren y se le pasa el gate (para retomar una campana lanzada
#   a mano).
#
# Variantes: 'po1' = el arbol del repo tal cual (place_option 1);
#            'po2' = copia del arbol con `set_option -place_option 2`.
# ============================================================================
param(
    [Parameter(Mandatory=$true)][string] $Etiqueta,
    # JSON con la lista: [{"Nombre":"v36n","Dados":[3847,...],"Variante":"po1"}, ...]
    # (un fichero, porque una lista de hashtables no sobrevive a Start-Process)
    [Parameter(Mandatory=$true)][string] $Json,
    [string] $Root    = 'C:\Users\alber\proyectosAI\msx\MSXimus',
    [string] $Scratch = "$env:LOCALAPPDATA\Temp\claude\campanas",
    [int]    $PollSeg = 120,
    # 17/09 noche: no parar al primer GATE OK (para dejar candidatos de varias campanas)
    [switch] $SinParar
)
$ErrorActionPreference = 'Stop'
$log = Join-Path $Scratch "encadenadas_$Etiqueta.txt"
$Campanas = Get-Content $Json -Raw | ConvertFrom-Json
function Nota([string]$s) { $l = ("{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $s); Add-Content -Path $log -Value $l; Write-Output $l }
# 17/09: el runner de noche17 murio en silencio al pasar de v36n a v36o (la
# carpeta v36o ni se creo). Causa: la variable del bucle se llamaba $root y en
# PowerShell $root y $Root SON LA MISMA: la primera campana po2 machacaba la
# ruta del repo y la siguiente llamada a tools\... apuntaba a la copia. Ahora
# se llama $arbol y cualquier excepcion queda en el log.
trap { Nota ("EXCEPCION: {0}`r`n{1}" -f $_, $_.ScriptStackTrace); break }

# variante place_option 2: copia del arbol con el build.tcl tocado
$rootPo2 = Join-Path $Scratch "root_po2_$Etiqueta"
if ($Campanas | Where-Object { $_.Variante -eq 'po2' }) {
    if (Test-Path $rootPo2) { Remove-Item -LiteralPath $rootPo2 -Recurse -Force }
    New-Item -ItemType Directory -Path (Join-Path $rootPo2 'fpga') -Force | Out-Null
    $rc = & robocopy (Join-Path $Root 'fpga') (Join-Path $rootPo2 'fpga') /E /NFL /NDL /NJH /NJS /NP /XD impl opl4_20k_est zynq /XF build_*.log
    if ($LASTEXITCODE -ge 8) { throw "robocopy fallo ($LASTEXITCODE)" }
    $pb = Join-Path $rootPo2 'fpga\build.tcl'
    $t  = Get-Content $pb -Raw
    if (($t -split [regex]::Escape('set_option -place_option 1')).Count -ne 2) { throw 'no encuentro place_option 1 en build.tcl' }
    Set-Content -Path $pb -NoNewline -Value $t.Replace('set_option -place_option 1', "set_option -place_option 2`r`n# encadenar_campanas: variante po2")
    Nota "variante po2 preparada en $rootPo2"
}

Nota ("arranque: {0} campanas" -f $Campanas.Count)
foreach ($c in $Campanas) {
    if ((Get-Process -Name gw_sh -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) {
        Nota "hay gw_sh corriendo de antes: espero a que acaben"
        while ((Get-Process -Name gw_sh -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) { Start-Sleep -Seconds $PollSeg }
    }
    # "Root" en la entrada = arbol propio (p.ej. una copia de otro commit para
    # una campana de control); si no, po1 = repo, po2 = la copia con place_option 2
    $arbol = if ($c.Root) { $c.Root } elseif ($c.Variante -eq 'po2') { $rootPo2 } else { $Root }
    if ($c.SoloGate) {
        # campana lanzada a mano (o por un runner anterior que murio): no se
        # relanza, solo se espera a que acabe y se pasa el gate
        Nota ("campana {0} ya lanzada: solo espero y paso el gate" -f $c.Nombre)
    } else {
        Nota ("campana {0} ({1}) dados {2}" -f $c.Nombre, $c.Variante, ($c.Dados -join ','))
        & (Join-Path $Root 'tools\lanzar_campana.ps1') -Campana $c.Nombre -Dados ([int[]]$c.Dados) -Root $arbol 2>&1 | Out-Null
        Start-Sleep -Seconds 60
    }
    while ((Get-Process -Name gw_sh -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0) { Start-Sleep -Seconds $PollSeg }
    $gate = & (Join-Path $Root 'tools\gate_check.ps1') -Campana (Join-Path $Scratch $c.Nombre) 2>&1 | Out-String
    Nota ("gate {0}:`r`n{1}" -f $c.Nombre, $gate)
    $ok = ($gate -split "`r?`n") | Where-Object { $_ -match 'GATE OK' }
    if ($ok) {
        Nota ("*** DADO BUENO en {0}: {1}. Comprobar margen >= 0,4 ns con gowin_timing." -f $c.Nombre, ($ok -join ' | '))
        if (-not $SinParar) { Nota "PARO."; break }
    }
}
Nota "fin"
