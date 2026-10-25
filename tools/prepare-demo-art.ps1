$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'game/assets/reference'
New-Item -ItemType Directory -Force $out | Out-Null
$records = New-Object 'System.Collections.Generic.List[object]'
function Register-Art($source, $target, $operation) {
    $records.Add([PSCustomObject]@{source=$source; destination=$target; operation=$operation; sha256=(Get-FileHash -LiteralPath (Join-Path $root $source)).Hash; authorization='User explicit local Demo authorization 2026-10-25'; distribution='Third-party redistribution not verified'})
}
function Extract-Pose($family,$name,$skin,$pose,$id) {
    $atlasPath="study/$family/$name/anim/$name.sprite.$pose.atlas"
    $imagePath=if($skin){"study/$family/$name/${name}_$skin/anim/$name.sprite.$pose.png"}else{"study/$family/$name/anim/$name.sprite.$pose.png"}
    $body=Get-Content -LiteralPath (Join-Path $root $atlasPath) -Raw
    $matches=[regex]::Matches($body,'(?m)^([^\s][^\r\n]*)\r?\n  rotate: (true|false)\r?\n  xy: (\d+), (\d+)\r?\n  size: (\d+), (\d+)')
    $region=$matches | Where-Object {$_.Groups[1].Value -ne 'shadow'} | Sort-Object { [int]$_.Groups[5].Value * [int]$_.Groups[6].Value } -Descending | Select-Object -First 1
    if(-not $region){throw "No whole pose: $atlasPath"}
    $x=[int]$region.Groups[3].Value; $y=[int]$region.Groups[4].Value
    $w=[int]$region.Groups[5].Value; $h=[int]$region.Groups[6].Value
    $rotated=$region.Groups[2].Value -eq 'true'
    $src=[Drawing.Bitmap]::FromFile((Join-Path $root $imagePath))
    try {
        $rect=if($rotated){[Drawing.Rectangle]::new($x,$y,$h,$w)}else{[Drawing.Rectangle]::new($x,$y,$w,$h)}
        $crop=$src.Clone($rect,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            if($rotated){$crop.RotateFlip([Drawing.RotateFlipType]::Rotate90FlipNone)}
            $crop.Save((Join-Path $out "$id.png"),[Drawing.Imaging.ImageFormat]::Png)
        } finally {$crop.Dispose()}
    } finally {$src.Dispose()}
    Register-Art $imagePath "game/assets/reference/$id.png" "Extract region $($region.Groups[1].Value); undo atlas rotation; atlas metadata read-only"
}
$actors=@(
    @('heroes','crusader','A','attack_sword','warden'),
    @('heroes','highwayman','A','attack_slice','duelist'),
    @('heroes','arbalest','A','attack_ranged','ranger'),
    @('heroes','vestal','A','attack_heal','mender'),
    @('monsters','skeleton_defender','','attack_axe','guard'),
    @('monsters','skeleton_common','','attack_melee','raider'),
    @('monsters','skeleton_arbalist','','attack_crossbow','bolter')
)
foreach($a in $actors){
    Extract-Pose $a[0] $a[1] $a[2] 'defend' "$($a[4])_idle"
    Extract-Pose $a[0] $a[1] $a[2] $a[3] "$($a[4])_attack"
    if($a[0] -eq 'heroes'){
        $source="study/heroes/$($a[1])/$($a[1])_A/$($a[1])_portrait_roster.png"
        Copy-Item -LiteralPath (Join-Path $root $source) -Destination (Join-Path $out "$($a[4])_portrait.png")
        Register-Art $source "game/assets/reference/$($a[4])_portrait.png" 'Copy PNG only'
        foreach($number in @('one','two','three')){
            $source="study/heroes/$($a[1])/$($a[1]).ability.$number.png"
            Copy-Item -LiteralPath (Join-Path $root $source) -Destination (Join-Path $out "$($a[4])_$number.png")
            Register-Art $source "game/assets/reference/$($a[4])_$number.png" 'Copy PNG only; Demo skill differs from original'
        }
    }
}
Extract-Pose 'heroes' 'crusader' 'B' 'defend' 'warden_variant'
Extract-Pose 'heroes' 'crusader' 'A' 'attack_stun' 'warden_bash'
Extract-Pose 'heroes' 'crusader' 'A' 'attack_banner' 'warden_support'
Extract-Pose 'heroes' 'highwayman' 'A' 'attack_lunge' 'duelist_lunge'
Extract-Pose 'heroes' 'arbalest' 'A' 'attack_artillery' 'ranger_volley'
Extract-Pose 'heroes' 'arbalest' 'A' 'attack_point' 'ranger_mark'
Extract-Pose 'heroes' 'vestal' 'A' 'attack_lectionary' 'mender_spell'
Extract-Pose 'monsters' 'skeleton_arbalist' '' 'attack_bayonet' 'bolter_melee'
$records | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $root 'docs/research/DEMO_ASSET_REGISTER.json')
Write-Output "Prepared $($records.Count) art derivatives; study was only read."
