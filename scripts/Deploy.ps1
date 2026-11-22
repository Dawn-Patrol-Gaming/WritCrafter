<#
.SYNOPSIS
    Copies the addon into the ESO AddOns folder as AddOns\WritCrafter.

.DESCRIPTION
    Copies exactly what may be uploaded to ESOUI (the manifest, every file it loads, and
    README.md) and removes everything else from the destination, so the installed folder can be
    zipped for an upload as it is. Saved variables live in ..\SavedVariables and are never touched.
#>
param(
    [string]$Destination = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Elder Scrolls Online\live\AddOns\WritCrafter')
)

$source = Split-Path -Parent $PSScriptRoot

if ((Split-Path -Leaf $Destination) -ne 'WritCrafter') {
    throw "Destination must be a folder named WritCrafter: $Destination"
}

# Offline checks first (scripts\check.lua), when LuaJIT is installed: a file that wouldn't load
# in game is never deployed.
$luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
if (-not $luajit) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Programs\LuaJIT\bin\luajit.exe'
    if (Test-Path $candidate) { $luajit = $candidate }
}
if ($luajit) {
    Push-Location $source
    try {
        & $luajit scripts\check.lua
        if ($LASTEXITCODE -ne 0) {
            throw "scripts\check.lua found problems; not deployed"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "LuaJIT not found; skipping scripts\check.lua"
}

# scripts\check_lua.py too, when Python is installed: it has checks check.lua lacks (a local
# function called above its definition, 'a, b = x and f()', tonumber of a call).
# Skips the Microsoft Store stub in WindowsApps, which only says "Python was not found".
$python = Get-Command python -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -notlike '*\Microsoft\WindowsApps\*' } |
    Select-Object -First 1 -ExpandProperty Source
if ($python) {
    Push-Location $source
    try {
        & $python -I scripts\check_lua.py
        if ($LASTEXITCODE -ne 0) {
            throw "scripts\check_lua.py found problems; not deployed"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Python not found; skipping scripts\check_lua.py"
}

# Exactly what may be uploaded to ESOUI: the manifest, every file it loads, and README.md (the
# player guide). The installed folder is what gets zipped for an upload, so nothing else may be
# in it: ESOUI's addon check flags any other file (images, docs, scripts, hidden files).
$manifest = Get-Content -LiteralPath (Join-Path $source 'WritCrafter.txt') -Encoding UTF8
$loaded = $manifest | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' -and -not $_.StartsWith('#') -and -not $_.StartsWith(';') }
if ($loaded | Where-Object { $_ -match '\$\(' }) {
    throw "The manifest uses a path variable such as `$(language); teach Deploy.ps1 about it first"
}
$files = @('WritCrafter.txt', 'README.md') + @($loaded | ForEach-Object { $_ -replace '/', '\' })

$allowed = '.txt', '.lua', '.xml', '.dds', '.md', '.ttf', '.otf'
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $file) -PathType Leaf)) {
        throw "Listed but missing: $file; not deployed"
    }
    if ($allowed -notcontains [IO.Path]::GetExtension($file).ToLowerInvariant()) {
        throw "File type ESOUI doesn't allow: $file; not deployed"
    }
}

$ErrorActionPreference = 'Stop'   # a file that fails to copy stops the deploy
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$keep = @{}
foreach ($file in $files) {
    $target = Join-Path $Destination $file
    $keep[$target.ToLowerInvariant()] = $true
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $target -Force
}

# Anything else in the folder goes: files removed from the add-on, and anything else that got
# in (hidden files included). Then empty folders.
$removed = 0
Get-ChildItem -LiteralPath $Destination -Recurse -File -Force | ForEach-Object {
    if (-not $keep.ContainsKey($_.FullName.ToLowerInvariant())) {
        Remove-Item -LiteralPath $_.FullName -Force -Confirm:$false
        $removed++
    }
}
Get-ChildItem -LiteralPath $Destination -Recurse -Directory -Force |
    Sort-Object { $_.FullName.Length } -Descending |
    Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -Confirm:$false }

Write-Host "Deployed $($files.Count) files to $Destination (removed $removed other file(s))"
Write-Host "Ready to zip for ESOUI: zip the WritCrafter folder itself, so the zip holds one WritCrafter folder."
