"""Serve the exported game and exercise real browser multi-touch (not Safari certification)."""
import functools
import http.server
import os
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parents[1]
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root / "work/web"))
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
errors = []
try:
    with sync_playwright() as p:
        options = {"headless": True, "args": ["--no-sandbox", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]}
        if os.environ.get("CHROMIUM_PATH"):
            options["executable_path"] = os.environ["CHROMIUM_PATH"]
        browser = p.chromium.launch(**options)
        context = browser.new_context(viewport={"width": 1180, "height": 820}, has_touch=True, device_scale_factor=1)
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
        page.goto(f"http://127.0.0.1:{server.server_port}/index.html")
        page.wait_for_function("typeof Engine !== 'undefined' && Engine.getMissingFeatures({threads: false}).length === 0")
        page.wait_for_function("!document.querySelector('#status')", timeout=120000)
        print("WASM initialized", flush=True)
        page.wait_for_timeout(4000)
        # Canvas logical size remains 1920x1080; convert positions to CSS coordinates.
        print("Capture canvas", flush=True)
        box = page.locator("#canvas").bounding_box()
        def point(x, y, identifier):
            scale = min(box["width"] / 1920, box["height"] / 1080)
            return {"x": box["x"] + (box["width"]-1920*scale)/2 + x*scale, "y": box["y"] + (box["height"]-1080*scale)/2 + y*scale, "id": identifier}
        cdp = context.new_cdp_session(page)
        cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": [point(235, 770, 0), point(850, 550, 1), point(1835, 785, 2)]})
        page.wait_for_timeout(1500)
        print("Multi-touch pressed", flush=True)
        cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        # Toggle help open and closed through touch UI.
        for _ in range(2):
            pt = point(1630, 395, 0)
            page.touchscreen.tap(pt["x"], pt["y"])
            page.wait_for_timeout(200)
        page.screenshot(path=str(root / "work/web-smoke.png"))
        assert not errors, "Browser errors: " + "\n".join(errors)
        browser.close()
        print("PASS: exported WASM boot and browser multi-touch smoke (Chromium)")
finally:
    server.shutdown()
