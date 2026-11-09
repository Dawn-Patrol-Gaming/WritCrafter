<#
.SYNOPSIS
    Copies the addon into the ESO AddOns folder as AddOns\WritCrafter.

.DESCRIPTION
    Mirrors the repo into the destination, leaving out repo-only folders (docs, scripts, tests, .git).
    The destination folder is WritCrafter's own, so files deleted from the repo are deleted there too.
    Saved variables live in ..\SavedVariables and are never touched.
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

robocopy $source $Destination /MIR /XD .git .claude docs scripts tests /XF .gitignore *.md notes_*.txt /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}
Write-Host "Deployed to $Destination"
# robocopy uses 1-7 for success ("files copied" etc.); don't leak that as a failure.
exit 0
