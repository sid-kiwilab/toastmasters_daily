import http.server 
import socketserver 
import urllib.parse 
import os 
class H(http.server.SimpleHTTPRequestHandler): 
    def __init__(self, *a, **k): super().__init__(*a, directory=os.getcwd(), **k) 
    def do_GET(self): 
        p = urllib.parse.urlparse(self.path).path 
        if p.startswith('/club/') and p != '/club/index.html' and p != '/club/': 
            c = p.replace('/club/', '').split('/')[0] 
            if c: self.path = '/club/index.html?code=' + urllib.parse.quote(c) 
        return super().do_GET() 
socketserver.TCPServer(('', 8000), H).serve_forever() 
