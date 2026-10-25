param(
    [Parameter(Mandatory)][ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$')][string]$Version,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$parts = $Version.Split('.') | ForEach-Object { [int]$_ }
if ($parts[0] -gt 2000 -or $parts[1] -gt 999 -or $parts[2] -gt 999) { throw 'Version components exceed Android version-code limits.' }
$code = $parts[0] * 1000000 + $parts[1] * 1000 + $parts[2]
if ($code -lt 1) { throw 'Version must be greater than 0.0.0.' }
$projectPath = Join-Path $root 'project.godot'
$presetPath = Join-Path $root 'export_presets.cfg'
$versionPath = Join-Path $root 'VERSION'
$project = [IO.File]::ReadAllText($projectPath)
$presets = [IO.File]::ReadAllText($presetPath)
foreach ($entry in @(@($project,'(?m)^config/version="[^"]*"'),@($presets,'(?m)^version/name="[^"]*"'),@($presets,'(?m)^version/code=\d+'))) {
    if ([regex]::Matches($entry[0],$entry[1]).Count -ne 1) { throw 'Expected exactly one version field in each configuration.' }
}
$expectedProject = [regex]::Replace($project, '(?m)^config/version="[^"]*"', "config/version=`"$Version`"")
$expectedPresets = [regex]::Replace($presets, '(?m)^version/name="[^"]*"', "version/name=`"$Version`"")
$expectedPresets = [regex]::Replace($expectedPresets, '(?m)^version/code=\d+', "version/code=$code")
if ($Check) {
    if ($project -ne $expectedProject -or $presets -ne $expectedPresets -or [IO.File]::ReadAllText($versionPath).Trim() -ne $Version) {
        throw 'Version mismatch between VERSION, project.godot, and export_presets.cfg.'
    }
    Write-Output "Version verified: $Version (Android code $code)"
    return
}
[IO.File]::WriteAllText($projectPath,$expectedProject)
[IO.File]::WriteAllText($presetPath,$expectedPresets)
[IO.File]::WriteAllText($versionPath,"$Version`n")
Write-Output "Version set to $Version (Android code $code). Update CHANGELOG.md and create tag v$Version after tests."
