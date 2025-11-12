@echo off
echo Starting local server for Toastmasters Daily...
echo.

cd public

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo Python found. Starting HTTP server on http://localhost:8000
    echo Press Ctrl+C to stop the server
    echo.
    start http://localhost:8000
    python -m http.server 8000
) else (
    REM Check if Python 3 is available
    python3 --version >nul 2>&1
    if %errorlevel% == 0 (
        echo Python 3 found. Starting HTTP server on http://localhost:8000
        echo Press Ctrl+C to stop the server
        echo.
        start http://localhost:8000
        python3 -m http.server 8000
    ) else (
        echo Python not found. Please install Python to use this server.
        echo Alternatively, you can use Node.js http-server or any other HTTP server.
        pause
    )
)

cd ..

