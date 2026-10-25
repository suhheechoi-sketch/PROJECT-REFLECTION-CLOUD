"""Exercise the real launcher across deployments while its HTML remains cacheable."""
import functools
import http.server
import json
import os
from pathlib import Path
import shutil
import tempfile
import threading
from playwright.sync_api import sync_playwright
root = Path(__file__).resolve().parents[1]
class CachedHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'public,max-age=31536000')
        super().end_headers()
with tempfile.TemporaryDirectory() as tmp:
    site = Path(tmp)
    shutil.copyfile(root / 'scripts/web/launcher.html', site / 'index.html')
    def publish(sha):
        entry = f'builds/{sha}/index.html'
        (site / entry).parent.mkdir(parents=True, exist_ok=True)
        (site / entry).write_text(f'<html><body>Build: {sha[:7]}</body></html>')
        (site / 'build.json').write_text(json.dumps({'commit': sha, 'entry': entry}))
    old, new = 'a' * 40, 'b' * 40
    publish(old)
    handler = functools.partial(CachedHandler, directory=tmp)
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        with sync_playwright() as p:
            opts = {'headless': True, 'args': ['--no-sandbox']}
            if os.environ.get('CHROMIUM_PATH'): opts['executable_path'] = os.environ['CHROMIUM_PATH']
            browser = p.chromium.launch(**opts)
            page = browser.new_page()
            page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
            page.wait_for_function('current === "' + old + '"')
            assert old in page.frames[1].url
            publish(new)
            page.evaluate('check()')
            page.wait_for_selector('#update:visible')
            # A new deployment never interrupts the current puzzle automatically.
            assert old in page.frames[1].url
            page.click('#update')
            page.wait_for_function('current === "' + new + '"')
            page.wait_for_function('document.querySelector("#game").src.includes("' + new + '")')
            assert new in page.frames[1].url
            browser.close()
            print('PASS: cached launcher discovers changed manifest; update loads only new commit path')
    finally:
        server.shutdown()
