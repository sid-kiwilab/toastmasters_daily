@echo off
echo Starting local server for Toastmasters Daily...
echo.

cd public

if exist _temp_server.py del _temp_server.py

echo import http.server > _temp_server.py
echo import socketserver >> _temp_server.py
echo import urllib.parse >> _temp_server.py
echo import os >> _temp_server.py
echo class H(http.server.SimpleHTTPRequestHandler): >> _temp_server.py
echo     def __init__(self, *a, **k): super().__init__(*a, directory=os.getcwd(), **k) >> _temp_server.py
echo     def do_GET(self): >> _temp_server.py
echo         p = urllib.parse.urlparse(self.path).path >> _temp_server.py
echo         if p.startswith('/club/') and p != '/club/index.html' and p != '/club/': >> _temp_server.py
echo             c = p.replace('/club/', '').split('/')[0] >> _temp_server.py
echo             if c: self.path = '/club/index.html?code=' + urllib.parse.quote(c) >> _temp_server.py
echo         return super().do_GET() >> _temp_server.py
echo socketserver.TCPServer(('', 8000), H).serve_forever() >> _temp_server.py

python --version >nul 2>&1
if %errorlevel% == 0 (
    echo Python found. Starting HTTP server on http://localhost:8000
    echo Press Ctrl+C to stop the server
    echo.
    start http://localhost:8000
    python _temp_server.py
    if exist _temp_server.py del _temp_server.py
) else (
    python3 --version >nul 2>&1
    if %errorlevel% == 0 (
        echo Python 3 found. Starting HTTP server on http://localhost:8000
        echo Press Ctrl+C to stop the server
        echo.
        start http://localhost:8000
        python3 _temp_server.py
        if exist _temp_server.py del _temp_server.py
    ) else (
        echo Python not found. Please install Python to use this server.
        if exist _temp_server.py del _temp_server.py
        pause
    )
)

cd ..

