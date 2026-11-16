param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [ValidateRange(10, 7200)][int]$Segundos = 1800
)
$ErrorActionPreference = 'Stop'
$proyecto = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$motor = (Resolve-Path -LiteralPath $Godot).Path
$logs = Join-Path $proyecto '.godot'
$inicio = [DateTime]::UtcNow
$procesos = @()
try {
    foreach ($lado in @('host', 'client')) {
        $argumentos = @('--headless', '--path', ('"' + $proyecto + '"'), '--script',
            'res://Pruebas/Multijugador/prueba_resistencia.gd', '--', "--$lado", "--segundos=$Segundos")
        $p = Start-Process -FilePath $motor -ArgumentList $argumentos -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $logs "resistencia_$lado.log") `
            -RedirectStandardError (Join-Path $logs "resistencia_$lado.error.log")
        $procesos += @{ Lado = $lado; Proceso = $p }
    }
    $limite = $inicio.AddSeconds($Segundos + 120)
    while (@($procesos | Where-Object { -not $_.Proceso.HasExited }).Count) {
        if ([DateTime]::UtcNow -ge $limite) { throw 'Se agotó el plazo de la prueba LAN.' }
        foreach ($entrada in $procesos) {
            if ($entrada.Proceso.HasExited -and $entrada.Proceso.ExitCode -ne 0) {
                throw "Falló $($entrada.Lado). Comprueba que UDP 7000 esté libre y revisa $logs."
            }
        }
        Start-Sleep -Seconds 1
    }
    foreach ($entrada in $procesos) {
        $lado = $entrada.Lado
        $reporte = Get-Item -LiteralPath (Join-Path $logs "resistencia_$lado.json")
        $datos = Get-Content -LiteralPath $reporte.FullName -Raw | ConvertFrom-Json
        $errores = Get-Content -LiteralPath (Join-Path $logs "resistencia_$lado.error.log") -Raw
        if ($entrada.Proceso.ExitCode -ne 0 -or $reporte.LastWriteTimeUtc -lt $inicio -or
            $datos.errores -ne 0 -or $errores -match '(?m)^(SCRIPT ERROR|ERROR):') {
            throw "Falló $lado. Revisa $logs."
        }
        Write-Output "OK: $lado, $($datos.duracion_real_s) segundos, $($datos.muestras.Count) muestras."
    }
} finally {
    foreach ($entrada in $procesos) {
        if (-not $entrada.Proceso.HasExited) {
            # La versión console de Godot crea un hijo; retirar solo los nuestros.
            Get-CimInstance Win32_Process -Filter "ParentProcessId = $($entrada.Proceso.Id)" |
                Where-Object { $_.Name -like 'Godot*' } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
            Stop-Process -Id $entrada.Proceso.Id -ErrorAction SilentlyContinue
        }
    }
}
