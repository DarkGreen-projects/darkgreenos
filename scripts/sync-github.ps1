# Push DarkgreenOS to GitHub (run after: gh auth login)
# Usage: .\scripts\sync-github.ps1 [-Message "fix: description"]

param(
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) not found. Install: winget install GitHub.cli"
}

$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Run once: gh auth login"
    exit 1
}

if (-not (git remote get-url origin 2>$null)) {
    Write-Host "Creating GitHub repo darkgreenos..."
    gh repo create darkgreenos --public --source=. --remote=origin --push
    if ($LASTEXITCODE -ne 0) {
        Write-Host "If name is taken, use: gh repo create YOUR_NAME/darkgreenos --public --source=. --remote=origin --push"
        exit $LASTEXITCODE
    }
    Write-Host "Done: $(gh repo view --json url -q .url)"
    exit 0
}

if ($Message) {
    git add -A
    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nothing to commit."
    } else {
        git commit -m $Message
    }
}

git push origin main
Write-Host "Pushed to origin main."
