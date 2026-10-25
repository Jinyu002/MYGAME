param([string]$GodotPath = 'E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root 'game'
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot executable not found. Supply -GodotPath with your Godot 4.7.2 executable.'
}
# Import only the isolated game root. Never open the legacy workspace project.
$import = Start-Process -FilePath $GodotPath -ArgumentList "--headless --path `"$game`" --editor --import --quit" -WindowStyle Hidden -Wait -PassThru
if ($import.ExitCode -ne 0) { throw "Game import failed: $($import.ExitCode)" }
Start-Process -FilePath $GodotPath -ArgumentList "--path `"$game`"" -WindowStyle Normal
