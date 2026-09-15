# ==============================================================
# FOMC Research Agent — GitHub + Render Deploy Script
#
# This script:
#   1. Initialises git (if needed)
#   2. Creates a GitHub repo via GitHub CLI
#   3. Pushes all code
#   4. Opens Render deploy page pre-filled with your repo
#
# Prerequisites:
#   - GitHub CLI: winget install GitHub.cli
#   - OR: just push manually and follow the Render URL below
#
# Usage:
#   .\deployment\deploy_render.ps1
# ==============================================================

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   FOMC Research Agent — Deploy to Render (Free)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Step 1: Check git ---
$gitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitPath) {
    Write-Host "Installing Git..." -ForegroundColor Yellow
    winget install Git.Git --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# --- Step 2: Init git repo if not already ---
Set-Location $Root
$isGitRepo = Test-Path (Join-Path $Root ".git")
if (-not $isGitRepo) {
    Write-Host "Initialising git repository..." -ForegroundColor Green
    git init
    git add .
    git commit -m "Initial commit: FOMC Research Agent with multi-platform deployment"
    Write-Host "Git repo initialised." -ForegroundColor Green
} else {
    Write-Host "Git repo found. Staging changes..." -ForegroundColor Green
    git add .
    $status = git status --porcelain
    if ($status) {
        git commit -m "Update: FOMC Research Agent deployment configs"
        Write-Host "Changes committed." -ForegroundColor Green
    } else {
        Write-Host "Nothing new to commit." -ForegroundColor Yellow
    }
}
Write-Host ""

# --- Step 3: Push to GitHub (via GitHub CLI if available) ---
$ghCli = Get-Command gh -ErrorAction SilentlyContinue
$repoName = "fomc-research-agent"

if ($ghCli) {
    Write-Host "GitHub CLI found. Creating repo and pushing..." -ForegroundColor Green
    
    # Check if already logged in
    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Logging in to GitHub..." -ForegroundColor Yellow
        gh auth login
    }

    # Create repo (public so Render free tier can access it)
    $existingRemote = git remote get-url origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating GitHub repo '$repoName'..." -ForegroundColor Green
        gh repo create $repoName --public --source=. --remote=origin --push
        $repoUrl = (gh repo view $repoName --json url -q ".url")
    } else {
        Write-Host "Remote already set: $existingRemote" -ForegroundColor Yellow
        git push origin main 2>&1 || git push origin master 2>&1
        $repoUrl = $existingRemote
    }

    Write-Host ""
    Write-Host "Code pushed to GitHub!" -ForegroundColor Green
    Write-Host "Repo: $repoUrl" -ForegroundColor Cyan
    Write-Host ""

    # Open Render deploy URL
    $renderUrl = "https://dashboard.render.com/new/blueprint"
    Write-Host "Opening Render deploy page..." -ForegroundColor Green
    Start-Process $renderUrl

} else {
    Write-Host "GitHub CLI not found. Two options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "OPTION A: Install GitHub CLI and re-run this script" -ForegroundColor Cyan
    Write-Host "  winget install GitHub.cli" -ForegroundColor White
    Write-Host ""
    Write-Host "OPTION B: Push manually" -ForegroundColor Cyan
    Write-Host "  1. Create a repo at https://github.com/new" -ForegroundColor White
    Write-Host "  2. Run:" -ForegroundColor White
    Write-Host "     git remote add origin https://github.com/YOUR_USERNAME/fomc-research-agent.git" -ForegroundColor White
    Write-Host "     git push -u origin main" -ForegroundColor White
    Write-Host ""
    Write-Host "Then deploy to Render:" -ForegroundColor Cyan
    Start-Process "https://dashboard.render.com/new/blueprint"
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Render Deployment Instructions" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "In the Render dashboard:" -ForegroundColor Yellow
Write-Host "  1. Connect your GitHub repo" -ForegroundColor White
Write-Host "  2. Render finds render.yaml automatically" -ForegroundColor White
Write-Host "  3. Add environment variable:" -ForegroundColor White
Write-Host "     GOOGLE_API_KEY = your-key-from-aistudio.google.com" -ForegroundColor Cyan
Write-Host "  4. Click Deploy" -ForegroundColor White
Write-Host ""
Write-Host "Your permanent free URL will be:" -ForegroundColor Green
Write-Host "  https://fomc-research-agent.onrender.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Health check : https://fomc-research-agent.onrender.com/api/health" -ForegroundColor White
Write-Host "  Run agent    : POST https://fomc-research-agent.onrender.com/api/agent/run" -ForegroundColor White
Write-Host ""
