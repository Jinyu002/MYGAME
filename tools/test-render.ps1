param(
    [string]$GodotPath = 'E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [ValidateSet('2560x1440','3840x2160')][string]$Resolution = '2560x1440',
    [switch]$Benchmark
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'game'
$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force $artifacts | Out-Null
$fullscreen = if ($Resolution -eq '3840x2160') { '--fullscreen' } else { '' }
$mode = if ($Benchmark) { 'benchmark' } else { 'presentation' }
$log = Join-Path $artifacts "$mode-$Resolution.log"
$extra = if ($Benchmark) { '-- --benchmark' } else { '--script res://tests/run_presentation.gd' }
# Run sequentially, without other GPU test processes. The process reads only game/.
$proc = Start-Process $GodotPath -ArgumentList "--path `"$game`" $fullscreen --resolution $Resolution --log-file `"$log`" $extra" -WindowStyle Hidden -PassThru
if (-not $proc.WaitForExit(100000)) {
    Stop-Process -Id $proc.Id
    throw "Render test timed out: $log"
}
$text = Get-Content -LiteralPath $log -Raw -Encoding UTF8
Write-Output $text
if ($proc.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR:|(?m)^ERROR:') { throw "Render test failed: $log" }
