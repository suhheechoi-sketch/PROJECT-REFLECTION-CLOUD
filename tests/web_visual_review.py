"""Build an isolated review project; never ship test progression controls in the game."""
from pathlib import Path
import os
import re
import shutil
import subprocess
root = Path(__file__).resolve().parents[1]
project = root / 'work/web-review-project'
project.mkdir(exist_ok=True)
tracked = subprocess.check_output(['git', 'ls-files'], cwd=root, text=True).splitlines()
for name in tracked:
    if name.startswith(('docs/', 'tools/', '.github/')):
        continue
    source = root / name
    if source.is_file():
        target = project / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
shutil.copyfile(root / 'data/build_info.json', project / 'data/build_info.json')
script = (root / 'tests/console_interaction_test.gd').read_text()
script = script.replace('extends SceneTree', 'extends Node').replace('func _initialize()', 'func _ready()')
script = re.sub(r'\broot\b', 'get_tree().root', script)
script = script.replace('await physics_frame', 'await get_tree().physics_frame').replace('await process_frame', 'await get_tree().process_frame')
script = script.replace('var visual := "--visual-review" in OS.get_cmdline_user_args()', 'var visual := true')
start = script.index('\tDirAccess.make_dir_recursive_absolute')
end = script.index('\nfunc structure_hash', start)
script = script[:start] + '''\tawait get_tree().process_frame
\tawait RenderingServer.frame_post_draw
\tJavaScriptBridge.eval("window.reviewReady=" + JSON.stringify(label))
\twhile JavaScriptBridge.eval("window.reviewProceed") != label:
\t\tawait get_tree().create_timer(0.1).timeout
''' + script[end:]
script = script.replace('quit(0 if failures == 0 else 1)', 'JavaScriptBridge.eval("window.reviewFinished="+str(failures))')
(project / 'web_review.gd').write_text(script)
(project / 'web_review.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://web_review.gd" id="1"]\n[node name="WebReview" type="Node"]\nscript = ExtResource("1")\n')
settings = (project / 'project.godot').read_text().replace('res://scenes/ta_demo.tscn', 'res://web_review.tscn')
(project / 'project.godot').write_text(settings)
preset = (project / 'export_presets.cfg').read_text().replace('tests/*,', '')
(project / 'export_presets.cfg').write_text(preset)
engine = os.environ['GODOT']
subprocess.run([engine, '--headless', '--editor', '--path', str(project), '--import'], check=True)
out = root / 'work/web-review'
out.mkdir(exist_ok=True)
subprocess.run([engine, '--headless', '--path', str(project), '--export-release', 'Web', str(out / 'index.html')], check=True)
# This export is evidence only. Production export above retains ta_demo.tscn and excludes tests.
import functools
import http.server
import threading
from playwright.sync_api import sync_playwright
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(out)))
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    with sync_playwright() as p:
        opts = {'headless': True, 'args': ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']}
        if os.environ.get('CHROMIUM_PATH'): opts['executable_path'] = os.environ['CHROMIUM_PATH']
        browser = p.chromium.launch(**opts)
        page = browser.new_page(viewport={'width': 1280, 'height': 720}, has_touch=True)
        messages = []
        page.on('console', lambda msg: messages.append(msg.text))
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
        for label in ['t03_vault_removed', 'a01_station', 'a01_selected', 'a01_deselected', 'a01_pc', 'a02', 'a03_ipad_ratio']:
            page.wait_for_function('(label) => window.reviewReady === label', arg=label, timeout=120000)
            page.screenshot(path=str(root / f'work/validation/web_{label}.png'))
            page.evaluate('(label) => window.reviewProceed=label', label)
        page.wait_for_function('typeof window.reviewFinished === "number"', timeout=30000)
        failures = page.evaluate('window.reviewFinished')
        print('\n'.join(messages))
        assert failures == 0, f'Web review failures: {failures}'
        browser.close()
        print('PASS: isolated web visual review and 48 console checks')
finally:
    server.shutdown()
