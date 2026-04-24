#!/usr/bin/env python3
"""
Simple HTTP server with URL rewriting for clubs routes
Works with: python start-server.py
"""
import http.server
import socketserver
import urllib.parse
import os

PORT = 3000

class RewriteHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Parse the path
        parsed_path = urllib.parse.urlparse(self.path)
        path = parsed_path.path
        
        # Handle /clubs/{club_code} routes (not static files like .js / .css under that folder)
        if path.startswith('/clubs/') and path != '/clubs/' and not path.endswith('.html'):
            parts = path.strip('/').split('/')
            if len(parts) >= 2 and parts[0] == 'clubs':
                last = parts[-1]
                if '.' in last and not last.endswith('.html'):
                    pass  # e.g. /clubs/foo.js — serve the real file
                else:
                    self.path = '/clubs/index.html'
                    print(f"Rewrote {path} to /clubs/index.html")
        
        # Handle /meetings/{meeting_id} routes (not .js / .css / etc. next to index.html)
        if path.startswith('/meetings/') and path != '/meetings/' and not path.endswith('.html'):
            parts = path.strip('/').split('/')
            if len(parts) >= 2 and parts[0] == 'meetings':
                last = parts[-1]
                if '.' in last and not last.endswith('.html'):
                    pass  # e.g. /meetings/meeting-app.js — serve the real file
                else:
                    self.path = '/meetings/index.html'
                    print(f"Rewrote {path} to /meetings/index.html")
        
        # Call the parent class to handle the request
        return super().do_GET()
    
    def log_message(self, format, *args):
        # Custom logging
        print(f"{self.address_string()} - {format % args}")

def main():
    # Change to public directory
    os.chdir('public')
    
    with socketserver.TCPServer(("", PORT), RewriteHandler) as httpd:
        print(f"Server starting on http://localhost:{PORT}")
        print(f"Serving files from: {os.getcwd()}")
        print(f"Clubs routes will be rewritten to /clubs/index.html")
        print(f"Meetings routes will be rewritten to /meetings/index.html")
        print(f"\nPress Ctrl+C to stop the server\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nServer stopped.")

if __name__ == "__main__":
    main()

