param([switch]$Editor, [switch]$Test, [switch]$RenderTest, [switch]$Build)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Join-Path $PSScriptRoot '.tools/Godot_v4.5-stable_win64_console.exe'
if (!(Test-Path $engine)) { throw 'Godot 4.5 is missing. Run setup.ps1 first or open project.godot in Godot 4.5.' }
$env:APPDATA = Join-Path $PSScriptRoot '.tools/user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
$version = (Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
& (Join-Path $PSScriptRoot 'scripts/set-version.ps1') -Version $version -Check
if ($Test) {
    & $engine --headless --path . --script tests/test_physics.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $engine --headless --path . --script tests/test_satellites.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $engine --headless --path . --script tests/test_app.gd
} elseif ($RenderTest) {
    & $engine --path . --script tests/test_render.gd
} elseif ($Build) {
    & $engine --headless --path . --editor --import --quit
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $engine --headless --path . --export-release 'Windows Desktop' build/EarthNomad.exe
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Copy-Item build/EarthNomad.exe "build/EarthNomad-$version-Windows.exe" -Force
} elseif ($Editor) {
    & $engine --path . --editor
} else {
    & $engine --path .
}
exit $LASTEXITCODE
