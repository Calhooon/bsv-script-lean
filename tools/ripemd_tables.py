#!/usr/bin/env python3
"""Extract the RIPEMD-160 message-word order and rotation amounts of both lines
from the reference's src/crypto/ripemd160.cpp at the pin (docs/PROVENANCE.md §1)
and print them as Lean lists for lean/BsvScript/Hash/Ripemd160.lean.

A maintainers' route (#177): the reference clone is docs/PROVENANCE.md section 1a's reference.clone,
$BSV_SPEC_REFERENCE_CLONE, from the environment or from tools/host_private.sh (tools/host_vars.py); without either
it stops with one line and exit 2."""
import re, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import host_vars  # noqa: E402
src=open(os.path.join(host_vars.need('$BSV_SPEC_REFERENCE_CLONE','ripemd_tables'),'src/crypto/ripemd160.cpp')).read()
calls=re.findall(r'R([1-5])([12])\(\w+, \w+, \w+, \w+, \w+, w(\d+), (\d+)\);', src)
left=[(int(w),int(s)) for r,l,w,s in calls if l=='1']
right=[(int(w),int(s)) for r,l,w,s in calls if l=='2']
assert len(left)==80 and len(right)==80, (len(left),len(right))
def lean(name, xs): return f"def {name} : List Nat := [" + ", ".join(str(x) for x in xs) + "]"
print(lean('wordsL', [w for w,_ in left])); print(lean('shiftsL', [s for _,s in left]))
print(lean('wordsR', [w for w,_ in right])); print(lean('shiftsR', [s for _,s in right]))
