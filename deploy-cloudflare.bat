@echo off
echo Building Flutter web...
flutter build web --release

if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Deploying to Cloudflare Pages...
cd build\web
wrangler pages deploy . --project-name=toastmasters-daily --commit-dirty=true

if errorlevel 1 (
    echo Deployment failed!
    cd ..\..
    pause
    exit /b 1
)

cd ..\..
echo.
echo Deployment complete!
pause

