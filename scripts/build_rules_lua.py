#!/usr/bin/env python3
"""rules/rules.json -> addon/ForeverCoach/Rules.lua (the addon can't read JSON).
The desktop helper does the same conversion when it downloads a newer rules.json."""
import json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def lua(v, ind=0):
    p = '  ' * ind
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return json.dumps(v)  # JSON string escapes are valid Lua for our ASCII/UTF-8 content
    if isinstance(v, list): return '{\n' + ''.join(f'{p}  {lua(x, ind + 1)},\n' for x in v) + p + '}'
    if isinstance(v, dict):
        return '{\n' + ''.join(f'{p}  [{json.dumps(k)}] = {lua(x, ind + 1)},\n' for k, x in v.items()) + p + '}'
    raise TypeError(type(v))


def convert(rules):
    return '-- Generated from rules.json. Do not edit; edit rules.json.\nForeverCoach_Rules = ' + lua(rules) + '\n'


if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'rules', 'rules.json')
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'addon', 'ForeverCoach', 'Rules.lua')
    open(dst, 'w', encoding='utf-8', newline='\n').write(convert(json.load(open(src, encoding='utf-8'))))
    print('wrote', dst)
