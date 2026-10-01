@echo off
setlocal
set "GHPATH=C:\Program Files\GitHub CLI\gh.exe"
set "GITPATH=C:\Program Files\Git\cmd\git.exe"
cd /d "%~dp0"

echo === 1/3 GitHub login ===
"%GHPATH%" auth status >nul 2>&1
if errorlevel 1 (
  echo Откроется браузер - войдите в GitHub.
  "%GHPATH%" auth login --web
)

echo === 2/3 Repository ===
for /f "delims=" %%i in ('"%GHPATH%" api user --jq .login') do set "LOGIN=%%i"
echo Login: %LOGIN%
"%GHPATH%" repo view "%LOGIN%/OpenVK-iOS" >nul 2>&1
if errorlevel 1 (
  echo Creating public repo OpenVK-iOS and pushing...
  "%GHPATH%" repo create OpenVK-iOS --public --source . --remote origin --push
) else (
  echo Repo already exists, pushing...
  "%GITPATH%" push -u origin main
)

echo.
echo === 3/3 Done ===
echo Откройте страницу сборки через 3-5 минут:
echo https://github.com/%LOGIN%/OpenVK-iOS/actions
echo.
pause