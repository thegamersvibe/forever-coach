#!/usr/bin/env python3
"""rules/rules.json -> addon/ForeverCoach/Rules.lua (the addon can't read JSON).
desktop/update.go does the same conversion when it downloads a newer rules.json.
Both use real Lua string escaping: UTF-8 stays as raw bytes (Lua 5.1 has no \\u escapes)."""
import json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def lua_str(s):
    out = []
    for ch in s:
        if ch == '\\': out.append('\\\\')
        elif ch == '"': out.append('\\"')
        elif ch == '\n': out.append('\\n')
        elif ch == '\r': out.append('\\r')
        elif ord(ch) < 32 or ord(ch) == 127: out.append('\\%03d' % ord(ch))
        else: out.append(ch)
    return '"' + ''.join(out) + '"'


def lua(v, ind=0):
    p = '  ' * ind
    if isinstance(v, bool): return 'true' if v else 'false'
    if v is None: return 'nil'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return lua_str(v)
    if isinstance(v, list): return '{\n' + ''.join(f'{p}  {lua(x, ind + 1)},\n' for x in v) + p + '}'
    if isinstance(v, dict):
        return '{\n' + ''.join(f'{p}  [{lua_str(k)}] = {lua(x, ind + 1)},\n' for k, x in sorted(v.items())) + p + '}'
    raise TypeError(type(v))


def convert(rules):
    return '-- Generated from rules.json. Do not edit; edit rules.json.\nForeverCoach_Rules = ' + lua(rules) + '\n'


if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'rules', 'rules.json')
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'addon', 'ForeverCoach', 'Rules.lua')
    open(dst, 'w', encoding='utf-8', newline='\n').write(convert(json.load(open(src, encoding='utf-8'))))
    print('wrote', dst)
