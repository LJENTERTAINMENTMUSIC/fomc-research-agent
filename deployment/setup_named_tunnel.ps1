# ============================================================
# FOMC Research Agent — Cloudflare Named Tunnel Setup
#
# Run this ONCE to create a permanent Cloudflare Tunnel.
# After setup, use start_cloudflare.ps1 to start the tunnel.
#
# Prerequisites:
#   1. Free Cloudflare account at https://cloudflare.com
#   2. A domain added to Cloudflare (any registrar, free plan OK)
#   3. cloudflared installed (winget install Cloudflare.cloudflared)
#
# Usage:
#   .\deployment\setup_named_tunnel.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$Root        = Split-Path -Parent $PSScriptRoot
$ConfigDir   = Join-Path $PSScriptRoot "cloudflare"
$ConfigFile  = Join-Path $ConfigDir "config.yml"
$TunnelName  = "fomc-research"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   FOMC Research — Cloudflare Permanent Tunnel Setup" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# --- Check cloudflared ---
$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cf) {
    Write-Host "ERROR: cloudflared not found." -ForegroundColor Red
    Write-Host "Install with: winget install Cloudflare.cloudflared" -ForegroundColor Yellow
    exit 1
}

# --- Step 1: Login to Cloudflare ---
Write-Host "STEP 1: Login to Cloudflare" -ForegroundColor Green
Write-Host "A browser window will open. Log in and authorise cloudflared." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to open browser login..."
cloudflared tunnel login
Write-Host ""
Write-Host "Login complete!" -ForegroundColor Green
Write-Host ""

# --- Step 2: Get domain ---
Write-Host "STEP 2: Enter your domain" -ForegroundColor Green
Write-Host "This is the domain you added to Cloudflare (e.g. mysite.com)" -ForegroundColor Yellow
$Domain = Read-Host "Enter your domain"
$Hostname = "fomc.$Domain"
Write-Host ""

# --- Step 3: Create tunnel ---
Write-Host "STEP 3: Creating tunnel '$TunnelName'..." -ForegroundColor Green
$tunnelOutput = cloudflared tunnel create $TunnelName 2>&1
Write-Host $tunnelOutput

# Extract tunnel ID from output
$tunnelId = ($tunnelOutput | Select-String -Pattern "([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})").Matches[0].Value
if (-not $tunnelId) {
    Write-Host "ERROR: Could not extract tunnel ID. Check output above." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "Tunnel ID: $tunnelId" -ForegroundColor Cyan

# Find credentials file
$credPath = "$env:USERPROFILE\.cloudflared\$tunnelId.json"
Write-Host "Credentials: $credPath" -ForegroundColor Cyan
Write-Host ""

# --- Step 4: Write config.yml ---
Write-Host "STEP 4: Writing tunnel config..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

$config = @"
# ============================================================
# Cloudflare Named Tunnel Config — FOMC Research Agent
# Tunnel: $TunnelName ($tunnelId)
# Hostname: $Hostname
# ============================================================

tunnel: $tunnelId
credentials-file: $($credPath -replace '\\', '/')

ingress:
  - hostname: $Hostname
    service: http://localhost:8080
  - service: http_status:404

loglevel: info
"@

Set-Content -Path $ConfigFile -Value $config
Write-Host "Config written to: $ConfigFile" -ForegroundColor Green
Write-Host ""

# --- Step 5: Create DNS route ---
Write-Host "STEP 5: Creating DNS record '$Hostname'..." -ForegroundColor Green
cloudflared tunnel route dns $TunnelName $Hostname
Write-Host ""
Write-Host "DNS record created!" -ForegroundColor Green
Write-Host ""

# --- Done ---
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   Setup Complete!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Tunnel name : $TunnelName" -ForegroundColor White
Write-Host "  Tunnel ID   : $tunnelId" -ForegroundColor White
Write-Host "  Public URL  : https://$Hostname" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start your agent with permanent tunnel, run:" -ForegroundColor Yellow
Write-Host "  .\deployment\start_cloudflare.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Your URL https://$Hostname will be permanent and" -ForegroundColor Green
Write-Host "will work every time you start the agent." -ForegroundColor Green
Write-Host ""
