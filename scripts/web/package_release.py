"""Keep Pages hosting, isolate every game asset under its exact commit directory."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1] if len(sys.argv) > 1 else root / 'work/web')
assert (out / 'index.pck').is_file(), 'Export a fresh Godot build before packaging'
info = json.loads((root / 'data/build_info.json').read_text())
sha = info['commit']
release = out / 'builds' / sha
release.mkdir(parents=True, exist_ok=True)
for path in list(out.iterdir()):
    if path.is_file():
        shutil.move(str(path), release / path.name)
info['entry'] = f'builds/{sha}/index.html'
info['files'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in release.iterdir() if p.is_file()}
(out / 'build.json').write_text(json.dumps(info, indent=2) + '\n')
shutil.copyfile(root / 'scripts/web/launcher.html', out / 'index.html')
(out / '.nojekyll').touch()
print('Packaged build:', sha)
