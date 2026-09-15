# ==============================================================
# FOMC Research Agent — Quick Deploy to Render
# Run this in PowerShell to push to GitHub and deploy to Render
# ==============================================================

# STEP 1: Init git and commit everything
git init
git add .
git commit -m "FOMC Research Agent - multi-platform deployment"

# STEP 2: Login to GitHub (browser will open)
gh auth login

# STEP 3: Create repo and push (public = free Render access)
gh repo create fomc-research-agent --public --source=. --remote=origin --push

# STEP 4: Open Render deploy page
Start-Process "https://dashboard.render.com/new/blueprint"

Write-Host ""
Write-Host "Done! In Render dashboard:" -ForegroundColor Green
Write-Host "  1. Connect your GitHub repo: fomc-research-agent" -ForegroundColor White
Write-Host "  2. Render finds render.yaml automatically" -ForegroundColor White  
Write-Host "  3. Add env var: GOOGLE_API_KEY = your key from aistudio.google.com/apikey" -ForegroundColor Cyan
Write-Host "  4. Click Deploy" -ForegroundColor White
Write-Host ""
Write-Host "Your free permanent URL:" -ForegroundColor Green
Write-Host "  https://fomc-research-agent.onrender.com" -ForegroundColor Cyan
