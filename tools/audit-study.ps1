param([switch]$Verify)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$source = Join-Path $workspace 'study'
$output = Join-Path $workspace 'docs/research'
$baseline = Join-Path $output 'study-manifest.csv'
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'study directory missing' }
if ((Get-Item -LiteralPath $source -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked study root refused' }
# Explicit traversal: never recurse through junctions or symlinks.
$pending = New-Object 'System.Collections.Generic.Stack[string]'
$pending.Push($source)
$files = New-Object 'System.Collections.Generic.List[object]'
while ($pending.Count -gt 0) {
    foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Linked entry refused: $($entry.FullName)" }
        if ($entry.PSIsContainer) { $pending.Push($entry.FullName) } else { $files.Add($entry) }
    }
}
$rows = @(foreach ($file in ($files | Sort-Object FullName)) {
    [PSCustomObject]@{
        Path = $file.FullName.Substring($workspace.Length + 1).Replace('\','/')
        Bytes = $file.Length
        Extension = $file.Extension.ToLowerInvariant()
        SHA256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
})
if ($Verify) {
    if (-not (Test-Path -LiteralPath $baseline)) { throw 'No baseline; create it first' }
    $previous = @(Import-Csv -LiteralPath $baseline)
    # User-added DD2 assemblies (2026-10-26) have a separate immutable baseline.
    # Preserve the original DD1 evidence; do not silently regenerate either file.
    $managedBaseline = Join-Path $output 'managed-manifest-2026-10-26.csv'
    if (Test-Path -LiteralPath $managedBaseline) {
        $previous += @(Import-Csv -LiteralPath $managedBaseline)
    }
    $previous += @(Import-Csv -LiteralPath (Join-Path $output 'ui-manifest-2026-10-26.csv'))
    $previous += @(Import-Csv -LiteralPath (Join-Path $output 'html-ui-manifest-2026-10-29.csv'))
    $changes = @(Compare-Object $previous $rows -Property Path,Bytes,SHA256)
    if ($changes.Count -gt 0) { $changes | Format-Table; throw 'study differs from baseline; investigate without modifying reference files' }
    Write-Output "PASS: $($rows.Count) reference files match baseline by path, size and SHA256."
} else {
    if (Test-Path -LiteralPath $baseline) { throw 'Baseline exists; use -Verify. Do not silently replace evidence.' }
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $rows | Export-Csv -LiteralPath $baseline -NoTypeInformation -Encoding UTF8
    $rows | Group-Object Extension | Sort-Object Count -Descending | Select-Object Count,Name | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'study-summary.json') -Encoding UTF8
    Write-Output "Indexed $($rows.Count) files, $(($rows | Measure-Object Bytes -Sum).Sum) bytes."
}
