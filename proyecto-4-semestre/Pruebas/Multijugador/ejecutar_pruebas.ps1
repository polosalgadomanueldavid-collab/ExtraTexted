param([Parameter(Mandatory = $true)][string]$Godot, [switch]$SoloConexion)
$ErrorActionPreference = 'Stop'
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$motor = (Resolve-Path -LiteralPath $Godot).Path
$logs = Join-Path $proyecto '.godot/qa_lan'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Iniciar-Prueba([string]$Nombre, [string]$Script, [string[]]$Opciones = @()) {
    $argumentos = @('--headless', '--path', ('"' + $proyecto + '"'), '--script', ('res://Pruebas/Multijugador/' + $Script))
    if ($Opciones.Count) { $argumentos += '--'; $argumentos += $Opciones }
    $proceso = Start-Process -FilePath $motor -ArgumentList $argumentos -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs "$Nombre.log") -RedirectStandardError (Join-Path $logs "$Nombre.error.log")
    return @{ Nombre = $Nombre; Proceso = $proceso }
}

function Esperar-Prueba($Prueba) {
    if (-not $Prueba.Proceso.WaitForExit(250000)) {
        $Prueba.Proceso.Kill()
        throw "Tiempo agotado: $($Prueba.Nombre). Revisa $logs"
    }
    $Prueba.Proceso.Refresh()
    $errores = Get-Content -LiteralPath (Join-Path $logs ($Prueba.Nombre + '.error.log')) -Raw
    if ($Prueba.Proceso.ExitCode -ne 0 -or $errores -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "Falló $($Prueba.Nombre). Revisa $logs"
    }
    Write-Output "OK: $($Prueba.Nombre)"
}

if (-not $SoloConexion) {
    Esperar-Prueba (Iniciar-Prueba 'reglas' 'prueba_reglas_lan.gd')
    Esperar-Prueba (Iniciar-Prueba 'menu' 'prueba_menu_lan.gd')
    $salaAnfitrion = Iniciar-Prueba 'sala_anfitrion' 'prueba_menu_lan.gd' @('--sala-host')
    $salaCliente = Iniciar-Prueba 'sala_cliente' 'prueba_menu_lan.gd' @('--sala-client')
    Esperar-Prueba $salaAnfitrion
    Esperar-Prueba $salaCliente
    $anfitrion = Iniciar-Prueba 'anfitrion' 'prueba_lan.gd' @('--host')
    $cliente = Iniciar-Prueba 'cliente' 'prueba_lan.gd' @('--client')
    Esperar-Prueba $anfitrion
    Esperar-Prueba $cliente
}

$servidor = Iniciar-Prueba 'conexion_servidor' 'prueba_conexion.gd' @('--servidor')
Start-Sleep -Milliseconds 700
Esperar-Prueba (Iniciar-Prueba 'version_incompatible' 'prueba_conexion.gd' @('--incompatible'))
$ocupante = Iniciar-Prueba 'ocupante' 'prueba_conexion.gd' @('--ocupar')
Start-Sleep -Seconds 2
Esperar-Prueba (Iniciar-Prueba 'sala_llena' 'prueba_conexion.gd' @('--llena'))
Esperar-Prueba $ocupante
Esperar-Prueba $servidor
Write-Output "Pruebas LAN terminadas. Registros: $logs"
