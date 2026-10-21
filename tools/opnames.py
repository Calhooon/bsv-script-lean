#!/usr/bin/env python3
"""Regenerate lean/Test/OpNames.lean from the pinned reference: the names
`init_op_names` (src/core_read.cpp:20–35) accepts, from `GetOpName`
(src/script/opcodes.cpp) and the values of src/script/opcodes.h. Run from the
repo root with the pin cloned at ~/bsv/bitcoin-sv (docs/PROVENANCE.md §1)."""
import re, os
ref=os.path.expanduser('~/bsv/bitcoin-sv')
h=open(f'{ref}/src/script/opcodes.h').read()
vals=dict((m.group(1),int(m.group(2),16)) for m in re.finditer(r'(OP_[A-Z0-9_]+)\s*=\s*(0x[0-9a-fA-F]+)',h))
for m in re.finditer(r'(OP_[A-Z0-9_]+)\s*=\s*(OP_[A-Z0-9_]+)',h):   # aliases (OP_NOP2 = OP_CHECKLOCKTIMEVERIFY, OP_NOP7 = OP_LSHIFTNUM, …)
    if m.group(2) in vals: vals[m.group(1)]=vals[m.group(2)]
s=open(f'{ref}/src/script/opcodes.cpp').read(); body=s[s.find('GetOpName'):]
names=re.findall(r'case (OP_[A-Z0-9_]+)\s*:\s*return\s*"([^"]*)"', body)
rows=[]
for op,name in names:
    v=vals[op]
    if v < 0x4c or v >= 0xba or name=='OP_UNKNOWN': continue
    rows.append((name,v))
    if name.startswith('OP_'): rows.append((name[3:],v))
out=['import BsvScript.Opcodes','/-!','# The opcode names of the reference\'s test-script parser','','`ParseScript` (`src/core_read.cpp:37–174`) resolves a word through `init_op_names`','(`core_read.cpp:20–35`): every opcode from `OP_PUSHDATA1` below `FIRST_UNDEFINED_OP_VALUE`','under its `GetOpName` (`src/script/opcodes.cpp`) with and without the `OP_` prefix.','Generated from the pin by `tools/opnames.py`; the values are `opcodes.h`.','-/','namespace BsvScript.Test','def opNames : List (String × Nat) := [']
out.append(',\n'.join(f'  ("{n}", 0x{v:02x})' for n,v in rows))
out.append(']'); out.append('end BsvScript.Test')
open('lean/Test/OpNames.lean','w').write('\n'.join(out)+'\n')
print(len(rows),'names')
