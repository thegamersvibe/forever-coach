#!/usr/bin/env python3
"""Rebuild rules.json 'routes' from a Journey guide index (route.json made by the wow-forever-leveling skill).
Only zone names and level bands are kept (facts, no guide text).

  python3 scripts/gen_routes.py /opt/data/skills/gaming/wow-forever-leveling/assets/route.json
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RACES = ['HUMAN', 'DWARF', 'GNOME', 'NIGHTELF', 'ORC', 'TROLL', 'TAUREN', 'SCOURGE', 'SKYBORNE']


def main(src):
    out = []
    for g in json.load(open(src, encoding='utf-8')):
        lo, hi = (int(x) for x in g['levels'].split('-'))
        zone = re.sub(r'^\d+-\d+\s+', '', g['zone'])
        zones = [z.strip() for z in zone.split('/')]
        e = {'id': g['id'], 'zones': zones, 'from': lo, 'to': hi, 'faction': g['faction']}
        rec = (g.get('recommended') or '').upper()
        races = [r for r in RACES if re.search(r'\b' + r + r'\b', rec)]
        if lo <= 6 and races:
            e['races'] = races
        if g['id'].startswith('SKY'):  # Skyborne guides exist once per faction
            e['faction'] = 'Alliance' if g['id'].endswith('A') else 'Horde'
            e['races'] = ['SKYBORNE']
        out.append(e)
    p = os.path.join(ROOT, 'rules', 'rules.json')
    rules = json.load(open(p, encoding='utf-8'))
    rules['routes'] = out
    # Dungeon name -> zone (from DungeonJournal location strings, e.g. "Moonbrook, Westfall")
    dpath = os.path.join(os.path.dirname(src), 'dungeons.json')
    if os.path.exists(dpath):
        parents = rules.setdefault('zoneParents', {})
        known = {z for e in out for z in e['zones']} | set(parents.values())
        for d in json.load(open(dpath, encoding='utf-8')):
            loc = d['location']
            zone = next((z for z in sorted(known, key=len, reverse=True) if z in loc), None)
            if not zone:
                zone = parents.get(loc.split(',')[-1].strip(), loc.split(',')[-1].strip())
            parents.setdefault(d['name'], parents.get(zone, zone))
    json.dump(rules, open(p, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    open(p, 'a').write('\n')
    print(len(out), 'route entries')


if __name__ == '__main__':
    main(sys.argv[1])
