@echo off
echo Starting server on http://localhost:8080
echo Serving files from: %CD%\public
echo.
echo Press Ctrl+C to stop the server
echo.
cd public
python -m http.server 8080

