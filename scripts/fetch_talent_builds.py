#!/usr/bin/env python3
"""Fetch Icy Veins WoW Forever leveling talent orders (level -> talent name only) for every spec.

Each Icy Veins leveling page embeds its build as `data-talentcalculator-pointsurl="#tc-<code>~<version>"`:
one character per point, levels 10..60, each character is a talent's urlId in that version's
talent JSON (static.icy-veins.com/r2/icydb/wowf/talents/<version>/<class>.json).
Validates rank limits and tree requirements, then writes research/talent_builds.json.
Usage: python3 scripts/fetch_talent_builds.py
"""
import concurrent.futures as cf
import json
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

H = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
     "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", "Accept-Language": "en-US,en;q=0.9"}
SPECS = {"WARRIOR": ["arms", "fury", "protection"], "PALADIN": ["retribution", "holy", "protection"],
         "HUNTER": ["beast-mastery", "marksmanship", "survival"], "ROGUE": ["combat", "assassination", "subtlety"],
         "PRIEST": ["shadow", "discipline", "holy"], "SHAMAN": ["elemental", "enhancement", "restoration"],
         "MAGE": ["frost", "arcane", "fire"], "WARLOCK": ["affliction", "demonology", "destruction"],
         "DRUID": ["feral", "balance", "restoration"]}
# Specs without their own Icy Veins leveling guide reuse a related one (stated in the source label).
ALIASES = {"DRUID:bear": ("DRUID:feral", "Icy Veins: Feral Druid leveling (cat/bear build)")}


def get(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=H), timeout=30).read().decode("utf-8", "replace")


def page(job):
    cls, spec = job
    url = f"https://www.icy-veins.com/wow-forever/{spec}-{cls.lower()}-leveling"
    h = get(url)
    codes = re.findall(r'data-talentcalculator-pointsurl=["\']#tc-([^"\']+)', h)
    title = re.search(r"<title>([^<]*)", h).group(1)
    return cls, spec, url, codes, title


def main():
    out, problems, talentdb = {}, [], {}
    jobs = [(c, s) for c, ss in SPECS.items() for s in ss]
    for cls, spec, url, codes, title in cf.ThreadPoolExecutor(8).map(page, jobs):
        if not codes:
            problems.append(f"{cls}:{spec}: no talent calculator on page")
            continue
        code, ver = codes[0].rsplit("~", 1)
        if (ver, cls) not in talentdb:
            talentdb[(ver, cls)] = json.loads(get(f"https://static.icy-veins.com/r2/icydb/wowf/talents/{ver}/{cls.lower()}.json"))
        ids = {}
        for g in talentdb[(ver, cls)]["talentGroups"]:
            for t in g["talents"]:
                if t:
                    ids[t["urlId"]] = (g["name"], t["name"], t["maxRank"], t.get("requiredPoints", 0))
        seq = [ids.get(ch) for ch in code]
        if None in seq or len(seq) != 51:
            problems.append(f"{cls}:{spec}: undecodable build ({len(seq)} points)")
            continue
        rank, tree = Counter(), Counter()
        for i, (tr, name, mx, req) in enumerate(seq):
            if tree[tr] < req:
                problems.append(f"{cls}:{spec}: {name} at {10 + i} before {req} points in {tr}")
            rank[name] += 1
            tree[tr] += 1
            if rank[name] > mx:
                problems.append(f"{cls}:{spec}: {name} over max rank")
        guide = re.sub(r"^.*?Forever\s+|\s+Guide.*$", "", title).strip()  # e.g. "Feral Druid Leveling"
        out[f"{cls}:{spec.replace('-', '_')}"] = {
            "source": f"Icy Veins: {guide.replace(' Leveling', ' leveling')}", "url": url, "guideVersion": ver,
            "tree": tree.most_common(1)[0][0], "order": [[10 + i, s[1]] for i, s in enumerate(seq)]}
    for key, (src, label) in ALIASES.items():
        if src in out:
            out[key] = dict(out[src], source=label)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)
    dest = Path(__file__).resolve().parent.parent / "research" / "talent_builds.json"
    dest.write_text(json.dumps(dict(sorted(out.items())), indent=1))
    print(f"{len(out)} builds -> {dest}")


if __name__ == "__main__":
    main()
