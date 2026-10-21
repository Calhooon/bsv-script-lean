#!/usr/bin/env python3
"""Extract the RIPEMD-160 message-word order and rotation amounts of both lines
from the reference's src/crypto/ripemd160.cpp at the pin (docs/PROVENANCE.md §1)
and print them as Lean lists for lean/BsvScript/Hash/Ripemd160.lean.

A maintainers' route (#177): the reference clone is BSV_REFERENCE_CLONE, from the environment or from
tools/host_private.sh; without either it stops with one line and exit 2."""
import re, os, sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def host_var(name):
    v=os.environ.get(name)
    if not v:
        try: src=open(os.path.join(ROOT,'tools','host_private.sh'),encoding='utf-8').read()
        except OSError: src=''
        m=re.search(r'^'+name+r'="([^"]*)"$',src,re.M)
        v=m.group(1).replace('$HOME',os.path.expanduser('~')) if m else None
    if not v:
        print(f"ripemd_tables: a maintainers' route; it needs tools/host_private.sh or {name} (tools/README.md)"); sys.exit(2)
    return v
src=open(os.path.join(host_var('BSV_REFERENCE_CLONE'),'src/crypto/ripemd160.cpp')).read()
calls=re.findall(r'R([1-5])([12])\(\w+, \w+, \w+, \w+, \w+, w(\d+), (\d+)\);', src)
left=[(int(w),int(s)) for r,l,w,s in calls if l=='1']
right=[(int(w),int(s)) for r,l,w,s in calls if l=='2']
assert len(left)==80 and len(right)==80, (len(left),len(right))
def lean(name, xs): return f"def {name} : List Nat := [" + ", ".join(str(x) for x in xs) + "]"
print(lean('wordsL', [w for w,_ in left])); print(lean('shiftsL', [s for _,s in left]))
print(lean('wordsR', [w for w,_ in right])); print(lean('shiftsR', [s for _,s in right]))
