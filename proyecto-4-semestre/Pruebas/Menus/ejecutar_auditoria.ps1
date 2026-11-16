param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [ValidateRange(1, 10)][int]$Repeticiones = 3,
    [switch]$SinRender
)
$ErrorActionPreference = 'Stop'
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$motor = (Resolve-Path -LiteralPath $Godot).Path
$logs = Join-Path $proyecto '.godot/qa_optimizacion'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Ejecutar([string]$Nombre, [string]$Script, [bool]$Headless, [string[]]$Opciones = @()) {
    $argumentos = @('--path', ('"' + $proyecto + '"'), '--script', ('res://Pruebas/Menus/' + $Script))
    if ($Headless) { $argumentos += '--headless' }
    else { $argumentos += @('--rendering-method', 'gl_compatibility') }
    if ($Opciones.Count) { $argumentos += '--'; $argumentos += $Opciones }
    $salida = Join-Path $logs "$Nombre.log"
    $errorLog = Join-Path $logs "$Nombre.error.log"
    $proceso = Start-Process -FilePath $motor -ArgumentList $argumentos -WindowStyle Hidden -PassThru -RedirectStandardOutput $salida -RedirectStandardError $errorLog
    $limite = [DateTime]::UtcNow.AddMinutes(4)
    while (-not $proceso.WaitForExit(1000)) {
        if ([DateTime]::UtcNow -ge $limite) {
            $proceso.Kill()
            throw "Tiempo agotado: $Nombre"
        }
    }
    $proceso.Refresh()
    $errores = Get-Content -LiteralPath $errorLog -Raw
    if ($proceso.ExitCode -ne 0 -or $errores -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "Falló $Nombre. Revisa $logs"
    }
    Write-Output "OK: $Nombre"
}

$mediciones = @()
for ($i = 1; $i -le $Repeticiones; $i++) {
    $modos = @('headless')
    if (-not $SinRender) { $modos += 'render' }
    foreach ($modo in $modos) {
        $nombre = "carga_${modo}_$i"
        Ejecutar $nombre 'prueba_carga.gd' ($modo -eq 'headless') @('--capturas')
        $linea = Get-Content -LiteralPath (Join-Path $logs "$nombre.log") | Where-Object { $_.StartsWith('[AUDITORIA CARGA] ') }
        if (-not $linea) { throw "Falta la medición de $nombre" }
        $mediciones += @{ prueba = $nombre; datos = ($linea.Substring(18) | ConvertFrom-Json) }
    }
}
$mediciones | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $logs 'cargas.json')
Ejecutar 'recuperacion_headless' 'prueba_recuperacion_carga.gd' $true
if (-not $SinRender) { Ejecutar 'recuperacion_render' 'prueba_recuperacion_carga.gd' $false }
Ejecutar 'perfil' 'perfil_rendimiento.gd' ([bool]$SinRender) @('--segundos=3', '--rondas=5', '--calidad=2')
Copy-Item -LiteralPath (Join-Path $proyecto '.godot/perfil_rendimiento.json') -Destination (Join-Path $logs 'perfil_rendimiento.json')
Write-Output "Auditoría terminada: $logs"
