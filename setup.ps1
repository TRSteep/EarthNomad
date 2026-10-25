param([switch]$SkipTemplates)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force .tools,build | Out-Null
if (!(Test-Path '.tools/Godot_v4.5-stable_win64_console.exe')) {
    Invoke-WebRequest 'https://downloads.godotengine.org/?version=4.5&flavor=stable&slug=win64.exe.zip' -OutFile .tools/godot-mirror.zip
    Expand-Archive .tools/godot-mirror.zip .tools -Force
}
New-Item -ItemType File -Force .tools/_sc_,build/.gdignore | Out-Null
if (!$SkipTemplates -and !(Test-Path '.tools/templates/windows_release_x86_64.exe')) {
    Invoke-WebRequest 'https://downloads.godotengine.org/?version=4.5&flavor=stable&slug=export_templates.tpz' -OutFile .tools/templates.tpz
    New-Item -ItemType Directory -Force .tools/templates | Out-Null
    $archive = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $PSScriptRoot '.tools/templates.tpz'))
    try {
        foreach ($name in @('windows_release_x86_64.exe','windows_release_x86_64_console.exe','android_debug.apk','android_release.apk','version.txt')) {
            $entry = $archive.GetEntry("templates/$name")
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $PSScriptRoot ".tools/templates/$name"),$true)
        }
    } finally { $archive.Dispose() }
}
$env:APPDATA = Join-Path $PSScriptRoot '.tools/user'
New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
& ./.tools/Godot_v4.5-stable_win64_console.exe --headless --path . --editor --import --quit
exit $LASTEXITCODE
