"""Stamp the exact checked-out commit before import/export; never infer it from a PR ref."""
import json
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
info = {'commit': sha, 'version': 'T/A DEMO v1.1', 'main_scene': 'res://scenes/ta_demo.tscn'}
(root / 'data/build_info.json').write_text(json.dumps(info) + '\n')
print('Build:', sha)
