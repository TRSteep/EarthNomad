param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$version = (Get-Content VERSION -Raw).Trim()
& "$PSScriptRoot/set-version.ps1" -Version $version -Check
if (!$SkipBuild) {
    & "$root/run.ps1" -Build
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
}
$stage = Join-Path $root "build/package-$version"
New-Item -ItemType Directory -Force "$stage/docs" | Out-Null
New-Item -ItemType Directory -Force "$stage/docs/images" | Out-Null
Copy-Item "build/EarthNomad-$version-Windows.exe" "$stage/EarthNomad.exe" -Force
Copy-Item README.md,CHANGELOG.md,ATTRIBUTION.md,VERSION $stage -Force
Copy-Item docs/PHYSICS.md "$stage/docs/PHYSICS.md" -Force
Copy-Item docs/images/*.png "$stage/docs/images/" -Force
Copy-Item docs/licenses/GODOT-LICENSE.txt,docs/licenses/GODOT-COPYRIGHT.txt $stage -Force
$zip = Join-Path $root "build/EarthNomad-$version-Windows.zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText("$zip.sha256","$hash  $([IO.Path]::GetFileName($zip))`n")
Write-Output "Package: $zip"
Write-Output "SHA256: $hash"
