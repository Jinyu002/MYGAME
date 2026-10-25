param([string]$GodotPath = 'E:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$target = Join-Path $root ('research_sandbox/pause-probe-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $target | Out-Null
# Only our game content is copied. No study access and no editor addon processes.
foreach ($part in @('app','battle','content','assets')) {
    Copy-Item -LiteralPath (Join-Path $root "game/$part") -Destination $target -Recurse
}
$project = [IO.File]::ReadAllText((Join-Path $root 'game/project.godot'))
$project = [regex]::Replace($project, '(?ms)^\[autoload\].*?(?=^\[)', '')
$project = [regex]::Replace($project, '(?ms)^\[editor_plugins\].*?(?=^\[)', '')
[IO.File]::WriteAllText((Join-Path $target 'project.godot'), $project, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'pause_probe.gd') -Destination $target
$log = Join-Path $root 'artifacts/dd2-pause-probe.log'
$p = Start-Process $GodotPath -ArgumentList "--headless --path `"$target`" --editor --import --quit" -WindowStyle Hidden -Wait -PassThru
if ($p.ExitCode -ne 0) { throw 'Probe import failed' }
$p = Start-Process $GodotPath -ArgumentList "--headless --path `"$target`" --script res://pause_probe.gd --log-file `"$log`"" -WindowStyle Hidden -PassThru
if (-not $p.WaitForExit(30000)) { Stop-Process -Id $p.Id; throw 'Probe timeout' }
$output = Get-Content -LiteralPath $log -Raw -Encoding UTF8
Write-Output $output
if ($p.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:|(?m)^ERROR:') { throw 'Pause probe failed' }
