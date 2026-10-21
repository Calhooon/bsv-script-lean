#!/usr/bin/env python3
"""tools/make_help_check.py: every .PHONY target of the Makefile has its help line (#174).

`make help` (the default goal) prints the line `## <text>` written directly above each target's rule line, grouped by
the `## @group <name>` line before it. This check refuses a .PHONY target with no rule line, no `## ` line directly
above its rule line, or no group line before it, and prints one verdict line (the fmt leg of tools/check.sh runs it).

Usage: tools/make_help_check.py [Makefile]   exit 0 GREEN, 1 RED
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GROUPS = ('verify and build', 'the harness', 'the generators', 'the gates and checks', "the maintainers' routes")


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'Makefile')
    lines = open(path, encoding='utf-8').read().split('\n')
    phony = []
    for line in lines:
        if line.startswith('.PHONY:'):
            phony += line.split()[1:]
    group, rules, bad = None, {}, []
    for i, line in enumerate(lines):
        if line.startswith('## @group '):
            group = line[len('## @group '):].strip()
            if group not in GROUPS:
                bad.append(f'line {i + 1}: unknown group {group!r}')
            continue
        m = re.match(r'^([A-Za-z0-9_.-]+):(?!=)', line)
        if m and m.group(1) in phony and m.group(1) not in rules:
            above = lines[i - 1] if i else ''
            ok = above.startswith('## ') and not above.startswith('## @group') and above[3:].strip()
            rules[m.group(1)] = (ok, group)
    for t in dict.fromkeys(phony):
        if t not in rules:
            bad.append(f'{t}: no rule line')
        elif not rules[t][0]:
            bad.append(f'{t}: no `## ` line directly above its rule line')
        elif rules[t][1] is None:
            bad.append(f'{t}: no `## @group` line before it')
    n = len(dict.fromkeys(phony))
    if bad:
        for b in bad:
            print(f'  {b}')
        print(f'fmt: make help: RED: {len(bad)} of {n} .PHONY targets lack a help line or a group (the list above)')
        sys.exit(1)
    print(f'fmt: make help: GREEN [X]: {n} .PHONY targets, each with its `## ` line and its group (tools/make_help_check.py)')


if __name__ == '__main__':
    main()
