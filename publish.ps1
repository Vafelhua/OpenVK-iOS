$ErrorActionPreference = "Stop"
$gh = "C:\Program Files\GitHub CLI\gh.exe"
$repoName = "OpenVK-iOS"

if (-not (Test-Path $gh)) { throw "GitHub CLI не найден: $gh" }

& $gh auth status *>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Войдите в GitHub (откроется браузер)..." -ForegroundColor Cyan
    & $gh auth login --hostname github.com --git-protocol https --web
}

$existing = & $gh repo view "$([string]::Join('/', @((& $gh api user --jq .login), $repoName))") --json name 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Создаю публичный репозиторий $repoName..." -ForegroundColor Cyan
    & $gh repo create $repoName --public --source . --remote origin --push
} else {
    Write-Host "Репозиторий уже существует, пушу..." -ForegroundColor Cyan
    if (-not ((& $git remote) 2>$null)) { }
    & git push -u origin main
}

$login = & $gh api user --jq .login
Write-Host ""
Write-Host "Готово. Откройте страницу сборки:" -ForegroundColor Green
Write-Host "https://github.com/$login/$repoName/actions" -ForegroundColor Green
Write-Host ""
Write-Host "Когда сборка станет зелёной, скачайте артефакт OpenVK-unsigned-ipa:"
Write-Host "https://github.com/$login/$repoName/actions`n"