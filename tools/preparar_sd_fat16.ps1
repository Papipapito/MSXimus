# ============================================================================
# preparar_sd_fat16.ps1 - deja una SD con particion 1 en FAT16 para el MSX.
#
# POR QUE FAT16 Y NO FAT32. Las CUATRO rutinas del menu que ESCRIBEN la FAT
# (find_free_cluster, mark_cluster_eof, fh2_fat_set y fh2_clus2lba) son solo
# FAT16: no consultan FS32 ni una vez y usan 2 bytes por entrada. El resto del
# menu SI entiende FAT32 (15 sitios), asi que monta y navega tarjetas FAT32 tan
# ricamente... y al DESCARGAR escribe la FAT como si fuera FAT16. Numeros de
# cluster mal, cadenas cruzadas, ficheros pisados.
#   => Para probar descargas, la particion tiene que ser FAT16. Si no, se
#      apila ese bug encima del que se esta cazando y la medida no vale.
#
# FAT16 tiene un techo de 2 GB (32 KB por cluster), asi que en una tarjeta
# grande hay que partirla: particion 1 pequena en FAT16 para el MSX y el resto
# en FAT32 para no tirar capacidad. El MSX lee la primera.
#
# PIDE ADMINISTRADOR (Clear-Disk / New-Partition no van sin el).
#
#   .\tools\preparar_sd_fat16.ps1 -Disco 2                 # solo INFORMA
#   .\tools\preparar_sd_fat16.ps1 -Disco 2 -Adelante       # BORRA Y FORMATEA
# ============================================================================
param(
    [Parameter(Mandatory=$true)][int] $Disco,
    [string] $Letra   = 'E',
    [int]    $TamMB   = 2000,      # < 2048 para no rozar el techo de FAT16
    [switch] $Adelante
)
$ErrorActionPreference = 'Stop'

$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Hace falta PowerShell COMO ADMINISTRADOR."
}

$d = Get-Disk -Number $Disco
# Guardas: esto borra un disco entero. Solo USB extraible, ni sistema ni arranque.
if ($d.BusType -ne 'USB')        { throw "ABORTO: el disco $Disco es $($d.BusType), no USB." }
if ($d.IsSystem -or $d.IsBoot)   { throw "ABORTO: el disco $Disco es de sistema o de arranque." }
if ($d.Size -gt 200GB)           { throw "ABORTO: $([math]::Round($d.Size/1GB,1)) GB es demasiado para ser una SD." }

Write-Output ("disco {0}: {1}  {2} GB  {3}" -f $Disco, $d.FriendlyName, [math]::Round($d.Size/1GB,1), $d.BusType)
Write-Output "lo que hay ahora, Y QUE SE VA A PERDER:"
Get-Partition -DiskNumber $Disco -ErrorAction SilentlyContinue |
    ForEach-Object {
        $v = Get-Volume -Partition $_ -ErrorAction SilentlyContinue
        Write-Output ("   part {0}  {1,8:N0} MB  {2}  {3}" -f $_.PartitionNumber,
            ($_.Size/1MB), $(if($v){$v.FileSystem}else{'sin formato'}), $(if($_.DriveLetter){"$($_.DriveLetter):"}else{''}))
    }

if (-not $Adelante) {
    Write-Output ""
    Write-Output "Esto ha sido SOLO INFORMACION. Para hacerlo de verdad, repite con -Adelante"
    return
}

Clear-Disk -Number $Disco -RemoveData -RemoveOEM -Confirm:$false
Initialize-Disk -Number $Disco -PartitionStyle MBR -ErrorAction SilentlyContinue
$p1 = New-Partition -DiskNumber $Disco -Size ($TamMB * 1MB) -DriveLetter $Letra
Format-Volume -Partition $p1 -FileSystem FAT -NewFileSystemLabel MSXTEST -Confirm:$false | Out-Null
try {
    $p2 = New-Partition -DiskNumber $Disco -UseMaximumSize -AssignDriveLetter
    Format-Volume -Partition $p2 -FileSystem FAT32 -NewFileSystemLabel MSXRESTO -Confirm:$false | Out-Null
} catch {
    Write-Output "AVISO: no se pudo crear la 2a particion ($($_.Exception.Message)). La 1a esta bien igual."
}

Write-Output ""
Write-Output "RESULTADO:"
Get-Partition -DiskNumber $Disco | ForEach-Object {
    $v = Get-Volume -Partition $_ -ErrorAction SilentlyContinue
    Write-Output ("   part {0}  {1,8:N0} MB  {2,-6}  {3}  cluster {4}" -f $_.PartitionNumber,
        ($_.Size/1MB), $(if($v){$v.FileSystem}else{'-'}), $(if($_.DriveLetter){"$($_.DriveLetter):"}else{''}),
        $(if($v){$v.AllocationUnitSize}else{'-'}))
}
Write-Output ""
Write-Output "La particion 1 (FAT16) es la que tiene que ver el MSX. Comprueba que"
Write-Output "arriba pone FAT y NO FAT32 antes de probar ninguna descarga."
