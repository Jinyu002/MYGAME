param([string]$GodotPath = 'E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'game'
$artifacts = Join-Path $root 'artifacts'
New-Item -ItemType Directory -Force $artifacts | Out-Null
$import = Start-Process -FilePath $GodotPath -ArgumentList "--headless --path `"$game`" --editor --import --quit" -WindowStyle Hidden -Wait -PassThru
if ($import.ExitCode -ne 0) { throw 'Import failed' }
foreach ($suite in @('run_tests', 'run_integration', 'run_presentation', 'run_feedback')) {
    $log = Join-Path $artifacts "$suite.log"
    $proc = Start-Process -FilePath $GodotPath -ArgumentList "--headless --path `"$game`" --script res://tests/$suite.gd --log-file `"$log`"" -WindowStyle Hidden -PassThru
    if (-not $proc.WaitForExit(60000)) {
        Stop-Process -Id $proc.Id
        throw "$suite timed out; see $log"
    }
    $text = Get-Content -LiteralPath $log -Raw -Encoding UTF8
    Write-Output $text
    if ($proc.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR:|(?m)^ERROR:') { throw "$suite failed; see $log" }
}
& (Join-Path $PSScriptRoot 'audit-study.ps1') -Verify
