param([switch]$Editor, [switch]$Test, [switch]$Build)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Join-Path $PSScriptRoot '.tools/Godot_v4.5-stable_win64_console.exe'
if (!(Test-Path $engine)) { throw 'Godot 4.5 is missing. Run setup.ps1 first or open project.godot in Godot 4.5.' }
$env:APPDATA = Join-Path $PSScriptRoot '.tools/user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
if ($Test) {
    & $engine --headless --path . --script tests/test_physics.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $engine --headless --path . --script tests/test_app.gd
} elseif ($Build) {
    & $engine --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $engine --headless --path . --export-release 'Windows Desktop' build/EarthNomad.exe
} elseif ($Editor) {
    & $engine --path . --editor
} else {
    & $engine --path .
}
exit $LASTEXITCODE
