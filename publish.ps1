$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$gh = "C:\Program Files\GitHub CLI\gh.exe"
$git = "C:\Program Files\Git\cmd\git.exe"
if (-not (Test-Path $gh)) { throw "GitHub CLI не найден" }

Write-Host "1/3 GitHub login" -ForegroundColor Cyan
& $gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { & $gh auth login --web }

Write-Host "2/3 Repository" -ForegroundColor Cyan
$login = (& $gh api user --jq .login).Trim()
Write-Host "Login: $login"
& $gh repo view "$login/OpenVK-iOS" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating public repo and pushing..." -ForegroundColor Cyan
    & $gh repo create OpenVK-iOS --public --source . --remote origin --push
} else {
    Write-Host "Repo exists, pushing..." -ForegroundColor Cyan
    & $git push -u origin main
}

Write-Host ""
Write-Host "Готово. Страница сборки (через 3-5 минут):" -ForegroundColor Green
Write-Host "https://github.com/$login/OpenVK-iOS/actions" -ForegroundColor Green
Read-Host "Enter для выхода"