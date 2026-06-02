# Publish docs/wiki/*.md to GitHub Wiki (repo darkgreenos.wiki)
# Requires: gh auth login, git
# Usage: .\scripts\push-wiki.ps1 [-Message "update wiki"]

param(
    [string]$Message = "docs: update wiki from docs/wiki"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$WikiSrc = Join-Path $Root "docs\wiki"
$Tmp = Join-Path $env:TEMP "darkgreenos-wiki-push"

if (-not (Test-Path $WikiSrc)) {
    Write-Error "Missing $WikiSrc"
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Run: gh auth login"
    exit 1
}

if (Test-Path $Tmp) {
    Remove-Item -Recurse -Force $Tmp
}

git clone "https://github.com/DarkGreen-projects/darkgreenos.wiki.git" $Tmp
Copy-Item -Path (Join-Path $WikiSrc "*.md") -Destination $Tmp -Force

Set-Location $Tmp
git add -A
$status = git status --porcelain
if (-not $status) {
    Write-Host "Wiki already up to date."
    exit 0
}

git commit -m $Message
git push origin master 2>&1
if ($LASTEXITCODE -ne 0) {
    git push origin main 2>&1
}
Write-Host "Wiki: https://github.com/DarkGreen-projects/darkgreenos/wiki"
