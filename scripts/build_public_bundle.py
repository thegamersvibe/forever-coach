#!/usr/bin/env python3
"""Assemble an explicit Coach-only GitHub asset. No push/publication side effects."""
from pathlib import Path
import argparse,hashlib,json,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--exe',type=Path,required=True);ap.add_argument('--version',default='1.4.0');a=ap.parse_args()
    if not a.exe.is_file() or a.exe.read_bytes()[:2]!=b'MZ':raise SystemExit('Provide the verified Windows native EXE candidate')
    if not __import__('re').fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',a.version):raise SystemExit('Invalid version')
    addon=ROOT/'addon/ForeverCoach'
    toc=(addon/'ForeverCoach.toc').read_text()
    assert '## Title: Relax Coach' in toc and '## Version: '+a.version in toc
    out=ROOT/'dist/public';out.mkdir(parents=True,exist_ok=True)
    pkg=out/'package'
    if pkg.exists():shutil.rmtree(pkg)
    shutil.copytree(addon,pkg/'ForeverCoach',ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    for p in (pkg/'ForeverCoach').rglob('*'):
        if p.is_file() and p.suffix not in {'.lua','.toc','.tga'}:raise SystemExit(f'Unexpected addon asset: {p.name}')
    shutil.copy2(a.exe,pkg/'RelaxCoach.exe')
    shutil.copy2(ROOT/'docs/PUBLIC_README.md',pkg/'README.md')
    shutil.copy2(ROOT/'LICENSE',pkg/'LICENSE')
    rows=[{'path':p.relative_to(pkg).as_posix(),'sha256':digest(p),'bytes':p.stat().st_size} for p in sorted(pkg.rglob('*')) if p.is_file()]
    (pkg/'manifest.json').write_text(json.dumps({'project':'Relax Coach','kind':'coach-public','version':a.version,'files':rows},indent=2)+'\n')
    archive=out/f'RelaxCoach-{a.version}.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for p in sorted(pkg.rglob('*')):
            if p.is_file():z.write(p,p.relative_to(pkg).as_posix())
    shutil.copy2(a.exe,out/'RelaxCoach.exe')
    (out/'SHA256SUMS.txt').write_text('\n'.join(f'{digest(p)}  {p.name}' for p in [archive,out/'RelaxCoach.exe'])+'\n')
    print(json.dumps({'archive':str(archive),'sha256':digest(archive),'fileCount':len(rows)+1,'privateContentIncluded':False},indent=2))

if __name__=='__main__':main()
