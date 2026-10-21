"""Lists the Rust crates linked into the app, with their licenses, for the
in-app "Açık kaynak lisansları" page (Flutter's own packages are listed by
Flutter itself). Run after changing Rust dependencies:

    python tools/gen-licenses.py

Writes apps/player/assets/licenses/rust.json.
"""
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
meta = json.loads(subprocess.check_output(
    ['cargo', 'metadata', '--format-version', '1', '--manifest-path', str(root / 'core/crates/kp-bridge/Cargo.toml')],
    cwd=root,
))
nodes = {n['id']: n for n in meta['resolve']['nodes']}
packages = {p['id']: p for p in meta['packages']}
start = next(p['id'] for p in meta['packages'] if p['name'] == 'kp_bridge')

# Crates reachable through normal (not build or dev) dependencies.
seen, todo = set(), [start]
while todo:
    i = todo.pop()
    if i in seen:
        continue
    seen.add(i)
    for d in nodes[i]['deps']:
        if any(k['kind'] is None for k in d['dep_kinds']):
            todo.append(d['pkg'])

ours = {'kp_bridge', 'kp-core'}
crates = sorted(
    (
        {
            'name': packages[i]['name'],
            'version': packages[i]['version'],
            'license': packages[i].get('license') or 'bilinmiyor',
            'repository': packages[i].get('repository') or '',
        }
        for i in seen
        if packages[i]['name'] not in ours
    ),
    key=lambda c: (c['name'], c['version']),
)
out = root / 'apps/player/assets/licenses/rust.json'
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(crates, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
print(f'{len(crates)} crates -> {out.relative_to(root)}')
