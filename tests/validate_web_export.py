"""Fail the release if Godot's export is missing or no longer Safari-friendly."""
import json
from pathlib import Path
import re
import sys

folder = Path(sys.argv[1] if len(sys.argv) > 1 else "work/web")
for filename in ("index.html", "index.js", "index.wasm", "index.pck"):
    path = folder / filename
    assert path.is_file() and path.stat().st_size > 0, f"Missing/empty export: {path}"
assert (folder / "index.wasm").read_bytes()[:8] == b"\x00asm\x01\x00\x00\x00", "Invalid WASM header"
html = (folder / "index.html").read_text()
match = re.search(r"const GODOT_CONFIG\s*=\s*({.*?});", html)
assert match, "Godot export configuration not found"
config = json.loads(match.group(1))
assert config.get("ensureCrossOriginIsolationHeaders") is False, "Pages release must not require COOP/COEP"
assert config["executable"] == "index", "Unexpected executable asset prefix"
assert re.search(r"const GODOT_THREADS_ENABLED\s*=\s*false;", html), "Threaded WASM loader is not allowed"
assert not list(folder.glob("*.worker.js")), "Unexpected thread worker in single-thread build"
for filename, size in config["fileSizes"].items():
    assert (folder / filename).stat().st_size == size, f"Truncated or stale asset: {filename}"
# Check the actual WASM memory declaration, not only the preset or JS feature probe.
data = (folder / "index.wasm").read_bytes()
def leb(pos):
    value = shift = 0
    while True:
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
        shift += 7
pos = 8
memories = 0
while pos < len(data):
    section = data[pos]
    length, start = leb(pos + 1)
    if section == 5:
        count, cursor = leb(start)
        for _ in range(count):
            flags, cursor = leb(cursor)
            assert not flags & 2, "Shared WASM memory requires cross-origin isolation"
            _, cursor = leb(cursor)
            if flags & 1:
                _, cursor = leb(cursor)
            memories += 1
    pos = start + length
assert memories, "Expected an internal memory in the static single-thread template"
print("PASS: HTML/JS/PCK/WASM integrity and single-thread Pages configuration")
