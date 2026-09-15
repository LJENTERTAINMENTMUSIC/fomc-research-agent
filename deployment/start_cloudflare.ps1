# ============================================================
# FOMC Research Agent — Cloudflare Tunnel Launcher
#
# Automatically uses a NAMED (permanent) tunnel if configured,
# otherwise falls back to a QUICK (temporary) tunnel.
#
# Usage:
#   .\deployment\start_cloudflare.ps1
#
# First time with permanent URL?
#   .\deployment\setup_named_tunnel.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# --- Paths ---
$Root       = Split-Path -Parent $PSScriptRoot
$Venv       = Join-Path $Root ".venv\Scripts\python.exe"
$EnvFile    = Join-Path $Root ".env"
$Server     = Join-Path $Root "deployment\serve_cloudrun.py"
$TunnelCfg  = Join-Path $PSScriptRoot "cloudflare\config.yml"
$PORT       = 8080

# Refresh PATH so cloudflared is found after fresh install
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Check .env exists ---
if (-not (Test-Path $EnvFile)) {
    Write-Host ""
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "Copy .env-example to .env and add your GOOGLE_API_KEY." -ForegroundColor Yellow
    Write-Host "Get a free key: https://aistudio.google.com/apikey" -ForegroundColor Cyan
    exit 1
}

# --- Check API key is set ---
$apiKeyLine = (Get-Content $EnvFile | Select-String "^GOOGLE_API_KEY=(.+)$")
$apiKey = if ($apiKeyLine) { $apiKeyLine.Matches[0].Groups[1].Value } else { "" }
if (-not $apiKey -or $apiKey -eq "YOUR_API_KEY_HERE") {
    Write-Host ""
    Write-Host "ERROR: GOOGLE_API_KEY not set in .env!" -ForegroundColor Red
    Write-Host "Get a free key at: https://aistudio.google.com/apikey" -ForegroundColor Yellow
    Write-Host "Then edit: $EnvFile" -ForegroundColor Cyan
    exit 1
}

# --- Check cloudflared is installed ---
$cfInstalled = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cfInstalled) {
    Write-Host "cloudflared not found. Installing..." -ForegroundColor Yellow
    winget install Cloudflare.cloudflared --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# --- Check python venv ---
if (-not (Test-Path $Venv)) {
    Write-Host ""
    Write-Host "ERROR: Python venv not found." -ForegroundColor Red
    Write-Host "Run the following to set up:" -ForegroundColor Yellow
    Write-Host "  cd $Root" -ForegroundColor White
    Write-Host "  uv venv --python 3.12" -ForegroundColor White
    Write-Host "  uv pip install --python .venv python-dotenv fastapi uvicorn google-adk pydantic" -ForegroundColor White
    exit 1
}

# --- Determine tunnel mode ---
$useNamedTunnel = Test-Path $TunnelCfg
if ($useNamedTunnel) {
    # Extract hostname from config for display
    $hostnameMatch = (Get-Content $TunnelCfg | Select-String "hostname: (.+)")
    $publicUrl = if ($hostnameMatch) { "https://$($hostnameMatch.Matches[0].Groups[1].Value)" } else { "your configured hostname" }
    $tunnelMode = "NAMED (permanent)"
} else {
    $publicUrl = "https://xxxx.trycloudflare.com (random, changes each restart)"
    $tunnelMode = "QUICK (temporary)"
}

# --- Banner ---
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   FOMC Research Agent — Cloudflare Tunnel" -ForegroundColor Cyan
Write-Host "   Mode: $tunnelMode" -ForegroundColor $(if ($useNamedTunnel) { "Green" } else { "Yellow" })
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not $useNamedTunnel) {
    Write-Host "TIP: For a permanent URL, run setup first:" -ForegroundColor Yellow
    Write-Host "  .\deployment\setup_named_tunnel.ps1" -ForegroundColor White
    Write-Host ""
}

# --- Start FastAPI server in background ---
Write-Host "Starting FOMC Agent API on port $PORT..." -ForegroundColor Green

$serverJob = Start-Job -ScriptBlock {
    param($python, $server, $port, $root)
    $env:PORT = $port
    Set-Location $root
    & $python $server 2>&1
} -ArgumentList $Venv, $Server, $PORT, $Root

# Wait for server to be ready (up to 30s)
Write-Host "Waiting for server to be ready..." -ForegroundColor Yellow
$maxWait = 30
$waited  = 0
$serverReady = $false

do {
    Start-Sleep -Seconds 1
    $waited++
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:$PORT/api/health" -TimeoutSec 2 -ErrorAction Stop
        $serverReady = $true
    } catch {
        # Still starting...
    }
} while (-not $serverReady -and $waited -lt $maxWait)

if (-not $serverReady) {
    Write-Host ""
    Write-Host "ERROR: Agent server did not start within ${maxWait}s." -ForegroundColor Red
    Write-Host "Recent server logs:" -ForegroundColor Yellow
    Receive-Job $serverJob | Select-Object -Last 20 | Write-Host
    $serverJob | Stop-Job | Remove-Job
    exit 1
}

Write-Host "Agent API ready at http://localhost:$PORT/api/health" -ForegroundColor Green
Write-Host ""
Write-Host "Starting Cloudflare Tunnel..." -ForegroundColor Green

if ($useNamedTunnel) {
    Write-Host ""
    Write-Host "  Public URL : $publicUrl" -ForegroundColor Cyan
    Write-Host "  (permanent — same URL every time)" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  Your public URL will appear below..." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

try {
    if ($useNamedTunnel) {
        cloudflared tunnel --config $TunnelCfg run
    } else {
        cloudflared tunnel --url "http://localhost:$PORT"
    }
} finally {
    Write-Host ""
    Write-Host "Shutting down agent server..." -ForegroundColor Yellow
    $serverJob | Stop-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-Host "Done. Goodbye!" -ForegroundColor Green
}
