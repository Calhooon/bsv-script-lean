#!/usr/bin/env python3
"""The axiom check (CLAUDE.md rule 7): runs `lake env lean AxiomCheck.lean` in lean/
and verifies that every `#print axioms` line depends only on the axioms listed in
lean/AXIOMS-ALLOWED. Exit 1 on any other axiom, on a missing theorem, or on zero
theorems checked (the tripwire must always have something to check).

The output is parsed WHOLE: Lean wraps a long axiom list across lines (`'X' depends on axioms: [propext,` and
the rest on the lines below), and until 2026-09-27 this tool read one line at a time, so a wrapped entry was
printed but never judged. The tripwire's planted-axiom negative test found it: with a domain axiom planted in
one listed theorem, five listed theorems depended on it and the tool judged one (four lists wrapped;
`docs/records/20260927-165519-make-check-modal.txt`). Since then every entry is judged whatever its lines,
and the leg is RED unless the entries judged equal the `#print axioms` lines of AxiomCheck.lean, one each.

THE WALK (lean #32's second lens, its re-lenses 2 to 4; S1's `lean/AxiomCheck.lean`): the same Lean run prints one line
`axiom walk: <m> modules of BsvScript, BsvChain, Bsvs and Test.OpNames, <c> constants, <t> theorems, <a> axioms, <o> compiler
overrides (implemented_by, extern, init, a hand-made _unsafe_rec), <d> dependencies outside Lean's three`, read from the
environment, never the text: every theorem of the walked modules through `collectAxioms`, every `axiom` among their
constants, and every constant whose compiled code is not its definition's (`Lean.Compiler.getImplementedBy?`,
`Lean.isExtern`, `Lean.hasInitAttr`, and an `_unsafe_rec` that is not the elaborator's partial copy), however the
attribute was set. The walked modules are those AxiomCheck.lean imports, the libraries' modules of `BsvScript`, `BsvChain` and `Bsvs`
and the table `Test.OpNames`: every source below but `lean/Bsvs/Main.lean`, the executable's root, whose olean only
`lake build bsvs` writes (its re-lens 3, C3N-1; its text is still scanned). The leg is RED unless that line appears once,
with 0 axioms, 0 compiler overrides and 0 dependencies outside, with as many modules as the sources other than
`lean/Bsvs/Main.lean` and at least as many theorems as the list holds; each `axiom walk: NOT ALLOWED:` line is RED. The
walk's own text, AxiomCheck.lean after its last `#print axioms` line, must have the SHA-256 `WALK_SHA256` holds, updated
with the walk under both owners' tags (C3N-8), as AXIOMS-ALLOWED is pinned (C-14); and every line before it must be a
comment, a blank, one of the file's seven imports (`AXIOMCHECK_IMPORTS`) or a `#print axioms` line (C4N-5), so no macro or
import placed among the list can change what the pinned walk prints. So a theorem, an axiom or a compiler override a
spelling hides from the text scan below is still judged.

THE COVERAGE (lean #32's second lens, finding C-1, 2026-09-29; its re-lenses, CN-2, C2N-1, C2N-2, C2N-9, C3N-3, C3N-9):
every `theorem` declared under `lean/BsvScript` or `lean/BsvChain`, in either library root, under `lean/Bsvs` and in `lean/Test/OpNames.lean`
must be on AxiomCheck.lean's list; the leg is RED otherwise, the unlisted theorems named. Until then 51 were off it, 2
of them checked by nothing. The scan follows Lean's tokenizer (`Lean/Parser/Basic.lean`): comments (block comments
nest), strings, raw strings, `«…»` names, and a char literal wherever a token starts (after a symbol too, `!'"'`; a
`'` inside an identifier continues it); an interpolated string after a keyword that takes one (`s!`, `m!`, `f!`,
`println!`, `throwError`, `dbg_trace` and the grind reporters), its `{…}` read as code (`Lean/Parser/StrInterpolation.lean:17–46`);
and every `namespace`, `section` and `mutual` scope. It fails closed: a source it ends inside a string, a comment or a
`«…»` name; a string elsewhere whose plain and interpolated readings end apart (the other macros that take an
interpolated string, `throwErrorAt`, `trace[…]`, `throwNamedError` and their kin, follow a term or a name the scan
cannot place); a code line that carries `theorem` or `lemma` and does not parse as a declaration; a scope line it
cannot read whole; and a scope word after another command on its line: each is RED, named.

THE PIN AND THE REFUSALS (C-14; its re-lenses, CN-3, C2N-3, C2N-4, C3N-4, C3N-5, C3N-6, C4N-2, C4N-3, C4N-4): the leg is
RED when `AXIOMS-ALLOWED` names other than Lean's three, and when the sources (the same files, read with `newline=""` so a
lone CR stays a CR, comments and string contents blanked, and read a second time with every string's braces as code) hold
one of the refusal WORDS: a kernel bypass (`skipKernelTC`, `addDecl`), a compiler override by its spelling
(`implemented_by`, `extern` in any attribute, `init` or `tactic` in an attribute list, `_unsafe_rec`), a native-evaluation
or compiler-trusting spelling (`native_decide`, `decide +native` or `+«native»`, `native :=` or `«native» :=` anything but
`false`, `bv_decide`, `bv_check`, `ofReduceBool`, `ofReduceNat`, `trustCompiler`), the word `axiom`, or a command or
function that runs code at elaboration or writes the environment (`#eval`, `run_cmd`, `run_elab`, `run_meta`,
`run_tac`, `by_elab`, `elab`, `elab_rules`, `initialize`, `unsafe`, `setEnv`, `modifyEnv`, `setImplementedBy`,
`implementedByAttr`, `externAttr`, `simproc`, `dsimproc`, `command_elab`, `term_elab`, `builtin_…`, `withOptions`,
`mkAux…`), none of which the sources use. The words are a list of spellings, not a proof: a macro's expansion and code
run at elaboration are not text the scan reads. So every `macro`, `macro_rules` or `syntax` command must be a block
`ALLOWED_MACROS` pins by its SHA-256 (the one the sources hold is the tactic macro `impl_descend`,
`BsvScript/Impl/State.lean:529–530`), and a declaration added with the kernel's check skipped carries no axiom, so neither
`#print axioms` nor the walk names it: only the pinned toolchain's `leanchecker`, which replays every declaration through
the kernel, would, and it is not run here. `#print axioms` names the native tactics' axioms only in a listed theorem's
dependencies; the walk names every axiom the walked modules declare, a native tactic's in a definition or a theorem
included, every theorem's dependencies and every compiler override; neither sees an `example`, nor `ofReduceBool`,
`ofReduceNat` or `trustCompiler` in a definition no theorem uses, nor anything in `lean/Bsvs/Main.lean`, where the text
scan is the guard. And the leg is RED on any `lean/lakefile.lean` (Lake reads it before the TOML,
`Lake/Load/Package.lean:108–113`), and when `lean/lakefile.toml`, decoded by Python's `tomllib` (3.11 or later: the
Studio's and the box's `python3` are 3.14, Modal's image adds 3.11), names `skipKernelTC` in any key or string, or loads
native code into the compiling `lean` (`plugins`, `dynlibs`, `--plugin`, `--load-dynlib`, `Lake/Config/LeanConfig.lean:261`,
`:266`).

THE SCOPE (the owner's P2, 2026-10-05, `docs/records/20261005-224016-owner-rulings-32-p.md`): the Lean sources named
above, `AXIOMS-ALLOWED` and the lakefile, nothing else. The wrapper `eval/bsvs` and the Rust harness under `harness/` are outside it;
their own legs check them (the eval leg's self-test, the harness leg). Widening this checker to them is a new finding,
not a change to this one.

Run directly (`python3 tools/axiom_check.py`) it reads the last build, since `lake env` builds nothing;
`tools/check.sh axioms` builds StaleRunCheck before the check (#120) and reads the last build of everything else;
`make axioms` builds before it (C-13), and AxiomCheck.lean imports only modules `lake build` builds.

Exit 1 on: an axiom outside AXIOMS-ALLOWED; an entry count or order that differs from AxiomCheck.lean's lines; zero
entries; the walk's line absent, repeated or not clean, a walk line NOT ALLOWED, the walk's text off its pin, or a line
before the walk that is not a comment, an import or the list; a declared theorem off the list; a place the scan cannot
read; AXIOMS-ALLOWED other than Lean's three; a refusal word or a macro command outside `ALLOWED_MACROS` in the sources; a
refusal in the lakefile; `lake env lean AxiomCheck.lean` failing.

`python3 tools/axiom_check.py --self-test` runs, without Lean, seven parts: (1) the output parser on a fixed sample (a
wrapped list with a planted axiom among single-line ones, a primed name, `sorryAx`, a position-prefixed line) and the
walk's line; (2) the declaration scan on a fixed source holding the spellings above (the modified and dotted sections
among them), a char literal after `!`, an interpolated string holding a quote, and a `«…»` name with a space; (3) six
crafted sources, an unterminated raw string, a scope line with a second command and a theorem after garbage, each refused,
and a `«…»` name holding a quote, a char literal after `⟨` and two theorems a block comment alone separates from their
keyword (`theorem/--/hid`), each read, then three more refused, a string that reads two
ways, a scope word after a command, and a `trace[…]` string with a quote in its braces; (4) the list comparison,
`listed()`, the head check and the scan agreeing on a `«…»` name with a space, the pin, the walk's pin (`walk_pin_ok` on a text off it), `walked()` and the head check; (5)
each refusal word planted (some with a block comment as their only separator, `axiom/--/bad`), a char literal holding a line break or a lone CR before a bypass among them, and the same
words inside comments and strings and look-alike names, which must not trip it; (6) the lakefile refusal on crafted
lakefiles; (7) the macro allowlist. It exits 0 only if every part judges as it must; `sources()`, the coverage
difference, the zero-entry guard and the Lean-failure exit run in a full run only."""
import hashlib, os, re, subprocess, sys, tempfile

# A name may carry an apostrophe (`foo'`; C-10): a name character is any but a newline, and a quote only when
# the verdict text does not follow it.
ENTRY = re.compile(r"'((?:[^'\n]|'(?! (?:depends on axioms|does not depend)))+)' "
                   r"(?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", re.S)
LEAN3 = {"propext", "Classical.choice", "Quot.sound"}
BYPASS = re.compile(r"skipKernelTC|implemented_by|\bextern\b|addDecl|native_decide|\+«?native\b»?|«?native»?\s*:=(?!\s*false\b)"
                    r"|\bbv_decide\b|\bbv_check\b|ofReduceBool|ofReduceNat|trustCompiler|\baxiom\b"
                    r"|#eval|\brun_cmd\b|\brun_elab\b|\brun_meta\b|\brun_tac\b|\bby_elab\b|\belab\b|\belab_rules\b"
                    r"|initialize|\bunsafe\b|_unsafe_rec|\bsetEnv\b|\bmodifyEnv\b|setImplementedBy|implementedByAttr|externAttr"
                    r"|\bsimproc\b|\bdsimproc\b|\bcommand_elab\b|\bterm_elab\b|\bbuiltin_\w+|\bwithOptions\b|\bmkAux\w*"
                    r"|(?:@|\battribute\s*)\[[^\]]*\b(?:init|tactic)\b")
WALK = re.compile(r"axiom walk: (\d+) modules of BsvScript, BsvChain, Bsvs and Test\.OpNames, (\d+) constants, (\d+) theorems, "
                  r"(\d+) axioms, (\d+) compiler overrides \(implemented_by, extern, init, a hand-made _unsafe_rec\), "
                  r"(\d+) dependencies outside Lean's three")
# the macro commands the sources may hold, each pinned by the SHA-256 of its block (its first line to the next blank line;
# C4N-2): a macro only produces syntax, but the expansion is not text the scan reads, so each one is read once and pinned
MACRO_WORD = re.compile(r"\b(macro|macro_rules|syntax)\b")
ALLOWED_MACROS = {("lean/BsvScript/Impl/State.lean", "a62e3f4127dc5af16050bb31f70ca57c58f3885ed5734d066d7090ba856a4d65")}
# AxiomCheck.lean before its walk: comments, blank lines, these imports and the `#print axioms` list alone (C4N-5)
# #120 (2026-10-14): the stale run, the Lake library StaleRunCheck outside the BsvChain root, is the seventh.
AXIOMCHECK_IMPORTS = {"BsvScript", "BsvChain", "BsvChain.Properties.StaleRun", "Bsvs.Trace", "Bsvs.Corpus", "Bsvs.Run",
                      "Bsvs.SelfTest"}
# The SHA-256 of AxiomCheck.lean's text after its last `#print axioms` line (the walk; C3N-8): updated with the walk,
# under both owners' tags (S1's walk, S3's checker).
WALK_SHA256 = "acb3f0ec88209fe4ee6e8726495d4565099d61c6eaf1876f90b39aebdaaf8404"
SCOPE_WORD = re.compile(r"\s*(?:@\[[^\]]*\]\s*|(?:public|noncomputable|meta)\s+)*(namespace|section|end|mutual)\b")
SCOPE_ANYWHERE = re.compile(r"(?<![\w.'!?])(?:namespace|section|end|mutual)(?![\w'!?])")
# the keywords after which Lean reads a string as interpolated (`Init/Data/ToString/Macro.lean:14`, `Lean/Message.lean:854`,
# `Init/Data/Format/Macro.lean:16`, `Init/System/IO.lean:1814`, `Lean/Exception.lean:259`, `Lean/Parser/Term.lean:1003`,
# `Lean/Parser/Do.lean:261`, `Lean/Meta/Sym/SymM.lean:485`, `:499`, `Lean/Meta/Tactic/Grind/EMatch.lean:490`)
INTERP_KEYWORDS = ("s!", "m!", "f!", "println!", "throwError", "dbg_trace", "reportIssue!", "reportDbgIssue!",
                   "reportEMatchIssue!")
# a listed name: `«…»` components read whole, a space inside one among them (C3N-7); `listed()`, the head check and the
# declaration scan (`_decl_name`) read a name the same way (the applied set's lens, Sol and Astra)
NAME = r"(?:«[^»\n]*»|[^\s«])+"
LISTED = re.compile(r"(?m)^#print axioms\s+(" + NAME + ")")


def is_letter_like(v):
    return ((0x3b1 <= v <= 0x3c9 and v != 0x3bb) or (0x391 <= v <= 0x3a9 and v not in (0x3a0, 0x3a3))
            or 0x3ca <= v <= 0x3fb or 0x1f00 <= v <= 0x1ffe or 0x2100 <= v <= 0x214f or 0x1d49c <= v <= 0x1d59f
            or (0xc0 <= v <= 0xff and v not in (0xd7, 0xf7)) or 0x100 <= v <= 0x17f)


def is_id_first(c):
    """Lean's `isIdFirst` (`Init/Meta/Defs.lean:120–121`): an ASCII letter, `_`, or a letter-like character."""
    return (c.isascii() and c.isalpha()) or c == "_" or is_letter_like(ord(c))


def is_id_rest(c):
    """Lean's `isIdRest` (`Init/Meta/Defs.lean:133–134`): an ASCII letter or digit, `_`, `'`, `!`, `?`, a letter-like
    character, or a subscript one (`isSubScriptAlnum`, `111–118`: U+2080–2089, U+2090–209C, U+1D62–1D6A, U+2C7C)."""
    v = ord(c)
    subscript = 0x2080 <= v <= 0x2089 or 0x2090 <= v <= 0x209c or 0x1d62 <= v <= 0x1d6a or v == 0x2c7c
    return (c.isascii() and c.isalnum()) or c in "_'!?" or is_letter_like(v) or subscript


def in_ident(src, i):
    """Whether position `i` continues an identifier: the identifier characters just before it hold one that can
    start an identifier. After a symbol (`!`, `?`) or a number a token starts at `i` (`Lean/Parser/Basic.lean:1027–1045`)."""
    k = i - 1
    while k >= 0 and is_id_rest(src[k]):
        k -= 1
    return any(is_id_first(c) for c in src[k + 1:i])


def judge(out, allowed):
    """Every entry of the output, whatever its lines: [(name, axioms, extra)], and the text left unparsed."""
    entries, rest, pos = [], [], 0
    for m in ENTRY.finditer(out):
        rest.append(out[pos:m.start()])
        pos = m.end()
        axioms = [a.strip() for a in (m.group(2) or "").replace("\n", " ").split(",") if a.strip()]
        entries.append((m.group(1), axioms, [a for a in axioms if a not in allowed]))
    rest.append(out[pos:])
    return entries, "".join(rest)


def listed(path):
    """The theorems AxiomCheck.lean asks about, in order; a `«…»` component read whole (C3N-7)."""
    return LISTED.findall(open(path, encoding="utf-8").read())


def _blank(t):
    return "".join("\n" if c == "\n" else " " for c in t)


def _plain_end(src, i):
    """The index of the quote that closes the plain string opened at `i`, or len(src)."""
    j, n = i + 1, len(src)
    while j < n and src[j] != '"':
        j += 2 if src[j] == "\\" else 1
    return min(j, n)


def _after_keyword(src, i):
    """Whether the string opened at `i` follows one of `INTERP_KEYWORDS` as its own token (whitespace between)."""
    k = i
    while k > 0 and src[k - 1] in " \t\r\n":
        k -= 1
    for kw in INTERP_KEYWORDS:
        s0 = k - len(kw)
        if s0 >= 0 and src[s0:k] == kw and (s0 == 0 or not (is_id_rest(src[s0 - 1]) or src[s0 - 1] in ".«»")):
            return True
    return False


def _scan(src, i, res, report, interp_all, until_brace):
    """Code from `i`: appends to `res` and returns the index where it stopped (the unmatched `}` under `until_brace`,
    else len(src))."""
    n, depth, braces = len(src), 0, 0
    while i < n:
        if src.startswith("/-", i):
            # a comment separates tokens, so the outermost one leaves a space: `axiom/--/bad` is `axiom bad`, never
            # `axiombad` (the applied set's lens, Sol and Astra)
            if not depth:
                res.append(" ")
            depth += 1; i += 2; continue
        if depth and src.startswith("-/", i):
            depth -= 1; i += 2; continue
        if depth:
            if src[i] == "\n":
                res.append("\n")
            i += 1; continue
        c = src[i]
        if c == "«":
            j = src.find("»", i + 1)
            if j < 0:
                if report is not None: report.append("an unterminated «…» name")
                res.append(src[i:]); return n
            res.append(src[i:j + 1]); i = j + 1; continue
        if src.startswith("--", i):
            j = src.find("\n", i); i = n if j < 0 else j; continue
        if c == "r" and not in_ident(src, i):
            m = re.match(r'r(#*)"', src[i:])
            if m:
                close = '"' + m.group(1)
                j = src.find(close, i + m.end())
                if j < 0:
                    if report is not None: report.append("an unterminated raw string")
                    res.append(_blank(src[i:])); return n
                res.append('"' + _blank(src[i + m.end():j]) + '"'); i = j + len(close); continue
        if c == '"':
            i = _string(src, i, res, report, interp_all); continue
        if c == "'" and not in_ident(src, i) and not src.startswith("''", i):
            m = re.match(r"'(?:\\.[^']*|[^'\\])'", src[i:])
            if m:
                res.append("' '"); i += m.end(); continue
        if until_brace:
            if c == "{":
                braces += 1
            elif c == "}":
                if braces == 0:
                    return i
                braces -= 1
        res.append(c); i += 1
    if depth and report is not None:
        report.append("an unterminated block comment")
    return n


def _interp(src, i, res, report, interp_all):
    """The interpolated string opened at `i`: its text blanked, each `{…}` read as code; returns the index after it."""
    n, j, seg = len(src), i + 1, i + 1
    res.append('"')
    while j < n:
        c = src[j]
        if c == '"':
            res.append(_blank(src[seg:j]) + '"'); return j + 1
        if c == "\\":
            j += 2; continue
        if c == "{":
            res.append(_blank(src[seg:j]) + "{")
            j = _scan(src, j + 1, res, report, interp_all, True)
            if j >= n:
                if report is not None: report.append("an unterminated interpolation")
                return n
            res.append("}"); j += 1; seg = j; continue
        j += 1
    if report is not None: report.append("an unterminated string")
    res.append(_blank(src[seg:])); return n


def _string(src, i, res, report, interp_all):
    """A string opened at `i`, read as Lean reads it; returns the index after it."""
    if interp_all or _after_keyword(src, i):
        return _interp(src, i, res, report, interp_all)
    j = _plain_end(src, i)
    if j >= len(src):
        if report is not None: report.append("an unterminated string")
        res.append(_blank(src[i:])); return len(src)
    if "{" in src[i + 1:j]:
        probe = []
        if _interp(src, i, probe, [], False) != j + 1 and report is not None:
            line = src.count("\n", 0, i) + 1
            report.append(f"a string at line {line} whose plain and interpolated readings end apart, after a token the scan cannot place")
    res.append('"' + _blank(src[i + 1:j]) + '"')
    return j + 1


def strip_code(src, report=None, interp_all=False):
    """The source with comments removed (block comments nest, as Lean's do; each outermost one leaves a space, so the
    tokens it separated stay apart) and the contents of strings, raw strings
    and char literals blanked; `«…»` names kept whole; an interpolated string's `{…}` kept as code; every newline kept,
    so lines keep their numbers. With `interp_all`, every string is read as interpolated (the second reading the
    refusals scan). When `report` is a list, each place the scan cannot read appends its reason to it."""
    res = []
    _scan(src, 0, res, report, interp_all, False)
    return "".join(res)


def _strip_mods_end(prefix):
    """The prefix before `theorem`/`lemma` without its trailing modifiers and attribute lists (brackets nested, as in
    `@[simp, aesop safe (rule_sets := [X])]`), or None when an attribute list does not close."""
    head = prefix.rstrip()
    while True:
        m = re.search(r"(?:^|\s)(public|private|protected|noncomputable|meta|nonrec|unsafe|partial)$", head)
        if m:
            head = head[:m.start(1)].rstrip(); continue
        if head.endswith("]"):
            depth, j = 0, len(head) - 1
            while j >= 0:
                if head[j] == "]":
                    depth += 1
                elif head[j] == "[":
                    depth -= 1
                    if depth == 0:
                        break
                j -= 1
            if j <= 0 or head[j - 1] != "@":
                return None
            head = head[:j - 1].rstrip(); continue
        return head


def _decl_name(rest):
    """The name after `theorem`/`lemma`, as Lean's `declId` reads it (`Lean/Parser/Command.lean:122–126`): `«…»`
    components kept whole; it stops at whitespace, `:`, `(`, `{`, `[`, `⦃` or a universe list `.{`."""
    name, i = [], 0
    while i < len(rest):
        c = rest[i]
        if c == "«":
            j = rest.find("»", i + 1)
            if j < 0:
                return None
            name.append(rest[i:j + 1]); i = j + 1; continue
        if c.isspace() or c in ":({[⦃" or rest.startswith(".{", i):
            break
        name.append(c); i += 1
    return "".join(name) or None


def declared_in(src):
    """The theorems one source declares, fully qualified, and what the scan cannot read: ([names], [(line number,
    line or reason)]). Refused: a place the stripper cannot read (a source it ends inside a string, a comment or a
    `«…»` name; a string whose two readings end apart); a code line with the word `theorem` or `lemma` whose prefix is
    not attributes, modifiers and `<command> in` prefixes; a scope line (`namespace`, `section`, `end`, `mutual`, after
    the modifiers Lean's section syntax admits) not read whole; a scope word after another command on its line."""
    names, unparsed, stack, report = [], [], [], []
    lines = strip_code(src, report).split("\n")
    for r in report:
        unparsed.append((0, "the scan cannot read " + r))
    k = 0
    while k < len(lines):
        line = lines[k]
        k += 1
        sw = SCOPE_WORD.match(line)
        if sw:
            word, tail = sw.group(1), line[sw.end():].strip()
            if word == "namespace" and re.fullmatch(r"\S+", tail):
                stack.extend(("ns", c) for c in tail.split(".")); continue
            if word == "section" and re.fullmatch(r"\S*", tail):
                stack.extend(("sec", c) for c in (tail.split(".") if tail else [""])); continue
            if word == "mutual" and tail == "":
                stack.append(("mutual", "")); continue
            if word == "end" and re.fullmatch(r"\S*", tail):
                for _ in range(len(tail.split(".")) if tail else 1):
                    if stack:
                        stack.pop()
                continue
            unparsed.append((k, line.strip())); continue
        if SCOPE_ANYWHERE.search(line):
            unparsed.append((k, line.strip())); continue
        m = re.search(r"\b(?:theorem|lemma)\b", line)
        if not m:
            continue
        # the prefix: attributes and modifiers, after any `<command> in` prefixes (the generic `in`)
        head = _strip_mods_end(line[:m.start()])
        if head is None or (head and not re.fullmatch(r".*\S\s+in", head)):
            unparsed.append((k, line.strip())); continue
        rest = line[m.end():]
        if not rest.strip():
            while k < len(lines) and not lines[k].strip():
                k += 1
            rest = lines[k] if k < len(lines) else ""
            k += 1
        name = _decl_name(rest.lstrip())
        if not name:
            unparsed.append((k, line.strip())); continue
        if name.startswith("_root_."):
            names.append(name[len("_root_."):]); continue
        ns = ".".join(c for kind, c in stack if kind == "ns")
        names.append(f"{ns}.{name}" if ns else name)
    return names, unparsed


def sources(lean):
    """The sources: every `.lean` file under `lean/BsvScript`, `lean/BsvChain` and `lean/Bsvs`, both library roots, and
    `lean/Test/OpNames.lean`, the table `Bsvs.Trace` imports (C3N-9)."""
    out = [os.path.join(lean, name + ".lean") for name in ("BsvScript", "BsvChain")]
    for sub in ("BsvScript", "BsvChain", "Bsvs"):
        for dp, _, fs in sorted(os.walk(os.path.join(lean, sub))):
            out += [os.path.join(dp, f) for f in sorted(fs) if f.endswith(".lean")]
    out.append(os.path.join(lean, "Test", "OpNames.lean"))
    # History is outside the public import graph and checked with --history.
    history = os.path.join(lean, "BsvScript", "Numbers", "History.lean")
    return [p for p in out if os.path.isfile(p) and p != history]


def walked(lean, srcs):
    """The sources the walk reads: all but `lean/Bsvs/Main.lean`, which AxiomCheck.lean does not import (C3N-1)."""
    main = os.path.join(lean, "Bsvs", "Main.lean")
    return [p for p in srcs if p != main]


def bypass_in(src):
    """The first refusal in a source, read twice (its strings as Lean reads them, then every string's braces as code),
    or None."""
    for code in (strip_code(src), strip_code(src, None, True)):
        m = BYPASS.search(code)
        if m:
            return m.group(0).strip()
    return None


def macro_refusal(rel, src):
    """A `macro`, `macro_rules` or `syntax` command outside `ALLOWED_MACROS` (C4N-2), or None."""
    code = strip_code(src).split("\n")
    raw = src.split("\n")
    for i, line in enumerate(code):
        m = MACRO_WORD.search(line)
        if not m:
            continue
        j = i
        while j < len(raw) and raw[j].strip():
            j += 1
        h = hashlib.sha256("\n".join(raw[i:j]).encode("utf-8")).hexdigest()
        if (rel, h) not in ALLOWED_MACROS:
            return f"`{m.group(1)}` at line {i + 1} (a block not in ALLOWED_MACROS, sha256 {h[:16]})"
    return None


def head_refusal(text):
    """A line of AxiomCheck.lean before its walk that is not a comment, a blank, one of `AXIOMCHECK_IMPORTS` or a
    `#print axioms` line (C4N-5), or None."""
    lines = text.split("\n")
    last = max((i for i, l in enumerate(lines) if l.startswith("#print axioms")), default=-1)
    code = strip_code("\n".join(lines[:last + 1])).split("\n")
    for i, line in enumerate(code):
        t = line.strip()
        if not t or re.fullmatch(r"#print axioms\s+" + NAME, t):
            continue
        m = re.fullmatch(r"import\s+(\S+)", t)
        if m and m.group(1) in AXIOMCHECK_IMPORTS:
            continue
        return f"line {i + 1}: {t[:80]}"
    return None


def lakefile_refusal(lean):
    """What the lakefile gives Lake that this check refuses, or None: any `lean/lakefile.lean` (Lake reads it before the
    TOML, `Lake/Load/Package.lean:108–113`); in `lean/lakefile.toml`, decoded by `tomllib` (escapes, dotted and quoted
    keys, comments as TOML reads them), `skipKernelTC` in any key or string, and `plugins`, `dynlibs`, `--plugin` or
    `--load-dynlib` anywhere (C3N-5)."""
    if os.path.lexists(os.path.join(lean, "lakefile.lean")):
        return "a lakefile.lean, which Lake reads before lakefile.toml"
    p = os.path.join(lean, "lakefile.toml")
    if not os.path.isfile(p):
        return None
    try:
        import tomllib
    except ImportError:
        return "no TOML reader here (Python 3.11 or later reads lakefile.toml)"
    try:
        with open(p, "rb") as f:
            data = tomllib.load(f)
    except Exception as e:  # a lakefile.toml Python cannot read is not judged clean
        return f"lakefile.toml does not parse as TOML ({e})"
    found = []

    def walk(v, path):
        if isinstance(v, dict):
            for key, x in v.items():
                if "skipKernelTC" in key:
                    found.append(f"the key {path}{key}")
                if key in ("plugins", "dynlibs"):
                    found.append(f"{path}{key}")
                walk(x, f"{path}{key}.")
        elif isinstance(v, list):
            for x in v:
                walk(x, path)
        elif isinstance(v, str):
            if "skipKernelTC" in v or "--plugin" in v or "--load-dynlib" in v:
                found.append(f"{path.rstrip('.')} = {v!r}")
    walk(data, "")
    return "; ".join(found) or None


def walk_judge(out, walked_n, listed_n):
    """The walk's verdict on the Lean output: (ok, reason)."""
    found = WALK.findall(out)
    if len(found) != 1:
        return False, f"{len(found)} walk lines (one expected)"
    mods, _consts, thms, axs, over, outside = map(int, found[0])
    if "axiom walk: NOT ALLOWED:" in out or axs or over or outside:
        return False, f"the walk found {axs} axiom(s), {over} compiler override(s) and {outside} dependencies outside Lean's three"
    if mods != walked_n:
        return False, f"the walk read {mods} modules, the text scan {walked_n} sources it walks"
    if thms < listed_n:
        return False, f"the walk read {thms} theorems, fewer than the {listed_n} listed"
    return True, f"{mods} modules, {thms} theorems, 0 axioms, 0 compiler overrides, 0 outside"


def walk_text(text):
    """AxiomCheck.lean's text after its last `#print axioms` line: the walk."""
    lines = text.split("\n")
    last = max((i for i, l in enumerate(lines) if l.startswith("#print axioms")), default=-1)
    return "\n".join(lines[last + 1:])


def walk_pin_ok(text):
    """The walk's text has the SHA-256 WALK_SHA256 holds (C3N-8)."""
    return hashlib.sha256(walk_text(text).encode("utf-8")).hexdigest() == WALK_SHA256


def pin_ok(allowed):
    """AXIOMS-ALLOWED names exactly Lean's three (C-14)."""
    return allowed == LEAN3


def compare(got, want):
    """The entries judged against AxiomCheck.lean's lines: the same count, each in its place."""
    return len(got) == len(want) and all(g == w or g.endswith("." + w) for g, w in zip(got, want))


def self_test():
    ok_all = True
    # 1. the output parser, and the walk's line
    sample = ("'A.one' depends on axioms: [propext]\n"
              "'A.two' does not depend on any axioms\n"
              "'A.three' depends on axioms: [propext,\n Classical.choice,\n Quot.sound,\n A.planted]\n"
              "'A.four' depends on axioms: [propext, Classical.choice, Quot.sound]\n"
              "'A.five'' depends on axioms: [propext]\n"
              "'A.six' depends on axioms: [propext, sorryAx]\n"
              "AxiomCheck.lean:9:0: 'A.seven' does not depend on any axioms\n")
    entries, _ = judge(sample, LEAN3)
    names = [e[0] for e in entries]
    bad = [e[0] for e in entries if e[2]]
    good_walk = ("info: axiom walk: 3 modules of BsvScript, BsvChain, Bsvs and Test.OpNames, 90 constants, 40 theorems, 0 axioms, "
                 "0 compiler overrides (implemented_by, extern, init, a hand-made _unsafe_rec), 0 dependencies outside Lean's three\n")
    ok = (names == ["A.one", "A.two", "A.three", "A.four", "A.five'", "A.six", "A.seven"] and bad == ["A.three", "A.six"]
          and walk_judge(good_walk, 3, 7)[0] and not walk_judge(good_walk, 4, 7)[0] and not walk_judge(good_walk, 3, 41)[0]
          and not walk_judge(good_walk * 2, 3, 7)[0] and not walk_judge("", 3, 7)[0]
          and not walk_judge(good_walk.replace("0 axioms", "1 axioms"), 3, 7)[0]
          and not walk_judge(good_walk.replace("0 compiler overrides", "1 compiler overrides"), 3, 7)[0]
          and not walk_judge(good_walk.replace("0 dependencies", "2 dependencies"), 3, 7)[0]
          and not walk_judge(good_walk + "axiom walk: NOT ALLOWED: X has an init attribute\n", 3, 7)[0])
    ok_all &= ok
    print(f"axiom check --self-test: the parser and the walk's line {'OK' if ok else 'FAILED'} (entries {names}; flagged {bad})")
    # 2. the declaration scan, on the spellings it must know
    src = "\n".join([
        "namespace A",
        "theorem t1 : True := trivial",
        "open Nat in theorem t2 : True := trivial",
        "set_option maxRecDepth 100 in theorem t3 : True := trivial",
        "@[simp] @[csimp] theorem t4 : True := trivial",
        "@[simp, aesop safe (rule_sets := [X])] theorem t5 : True := trivial",
        "nonrec theorem t6 : True := trivial",
        "theorem",
        "  t7 : True := trivial",
        "mutual",
        "theorem t8 : True := trivial",
        "end",
        "noncomputable section",
        "theorem t9 : True := trivial",
        "end",
        "namespace B.C",
        "theorem t10 : True := trivial",
        "end B.C",
        "namespace D",
        "namespace E",
        "theorem t11 : True := trivial",
        "end D.E",
        "def s : String := \"a string",
        "theorem fake : False := sorry\"",
        "def c : Char := '\"'",
        "theorem t12' : True := trivial",
        "/- theorem hidden : True := trivial -/",
        "-- theorem hidden2 : True := trivial",
        "/- nested /- theorem hidden3 -/ still a comment -/",
        "theorem t13.{u} (x : Sort u) : True := trivial",
        "theorem t14: True := trivial",
        "include h in theorem t15 : True := trivial",
        "open Nat in @[simp] theorem t16 : True := trivial",
        "public section",
        "theorem t17 : True := trivial",
        "end",
        "section S.T",
        "theorem t18 : True := trivial",
        "end S.T",
        "def u : String := r\"C:\\\"",
        "def w : String := r#\"a\"b\"#",
        "theorem «t19 x» : True := trivial",
        "def bang : Bool := !'\"'.isWhitespace",
        "theorem t21 : True := trivial",
        "def i1 : String := s!\"{'\"'}\"",
        "def i2 : String := s!\"{\"\\\"\"} and {1}\"",
        "theorem t22 : True := trivial",
        "def j : String := \"{plain}\"",
        "theorem t23 : True := trivial",
        "end A",
        "theorem _root_.t20 : True := trivial",
        "#check (theorem)",
    ])
    got, unp = declared_in(src)
    want = ["A.t1", "A.t2", "A.t3", "A.t4", "A.t5", "A.t6", "A.t7", "A.t8", "A.t9", "A.B.C.t10", "A.D.E.t11",
            "A.t12'", "A.t13", "A.t14", "A.t15", "A.t16", "A.t17", "A.t18", "A.«t19 x»", "A.t21", "A.t22", "A.t23", "t20"]
    ok = got == want and [u[1] for u in unp] == ["#check (theorem)"]
    ok_all &= ok
    print(f"axiom check --self-test: the declaration scan {'OK' if ok else 'FAILED'} (declared {got}; unparsed {unp})")
    # 3. six crafted sources: three refused, three read (the last, two declarations a comment alone separates from their keyword)
    crafted = {
        "an unterminated raw string": "def u : String := r\"abc\ntheorem hidden : True := trivial\n",
        "a scope line with a second command": "namespace B open Nat\ntheorem x : True := trivial\nend B\n",
        "a theorem after garbage": "foo theorem x : True := trivial\n",
        "a «…» name holding a quote": "def «a\"b» := 1\ntheorem hidden : True := trivial\n",
        "a char literal after ⟨": "def p := ⟨'\"', 1⟩\ntheorem shown : True := trivial\n",
        "a comment between two tokens": "theorem/--/hid : True := trivial\ntheorem/- x -/«h 2» : True := trivial\n",
    }
    results = {what: declared_in(s) for what, s in crafted.items()}
    ok = (results["an unterminated raw string"][1] != [] and results["a scope line with a second command"][1] != []
          and results["a theorem after garbage"][1] != []
          and results["a «…» name holding a quote"] == (["hidden"], [])
          and results["a char literal after ⟨"] == (["shown"], [])
          and results["a comment between two tokens"] == (["hid", "«h 2»"], []))
    ok_all &= ok
    print(f"axiom check --self-test: six crafted sources, three refused and three read {'OK' if ok else 'FAILED'} ({results})")
    # 3b. three more refused: a string that reads two ways, a scope word after a command, a trace string with a quote in braces
    more = {
        "a string that reads two ways": "def j := foo \"{\\\"a\\\": 1}\"\ntheorem x : True := trivial\n",
        "a scope word after a command": "namespace A\nnamespace B\ntheorem t1 : True := trivial end B\ntheorem t2 : True := trivial\nend A\n",
        "a trace string with a quote in its braces": "def k := trace[x] \"{\"a\"}\"\ntheorem y : True := trivial\n",
    }
    res2 = {what: declared_in(s) for what, s in more.items()}
    ok = all(u != [] for _, u in res2.values())
    ok_all &= ok
    print(f"axiom check --self-test: three more refused {'OK' if ok else 'FAILED'} ({res2})")
    # 4. the comparison, listed() on a «…» name, the pin, the walk's pin
    with tempfile.TemporaryDirectory() as td:
        ac = os.path.join(td, "AxiomCheck.lean")
        with open(ac, "w", encoding="utf-8") as f:
            f.write("import X\n#print axioms A.«t19 x»\n#print axioms A.b'\n-- the walk\n#eval 1\n")
        lst = listed(ac)
        text = open(ac, encoding="utf-8").read()
    with tempfile.TemporaryDirectory() as td:
        mainp, runp = os.path.join(td, "Bsvs", "Main.lean"), os.path.join(td, "Bsvs", "Run.lean")
        walked_ok = walked(td, [mainp, runp]) == [runp]
        os.makedirs(os.path.join(td, "BsvChain"))
        chain_root = os.path.join(td, "BsvChain.lean")
        chain_rule = os.path.join(td, "BsvChain", "Finality.lean")
        for p, body in ((chain_root, "import BsvChain.Finality\n"),
                        (chain_rule, "namespace BsvChain\naxiom planted : False\nend BsvChain\n")):
            with open(p, "w", encoding="utf-8") as f:
                f.write(body)
        chain_sources = sources(td)
        walked_ok &= set(chain_sources) == {chain_root, chain_rule} and walked(td, chain_sources) == chain_sources
        walked_ok &= bypass_in(open(chain_rule, encoding="utf-8").read()) is not None
    head_ok = (head_refusal("-- a comment\nimport BsvScript\n#print axioms A.b\n/-! the walk -/\n#eval 1\n") is None
               and head_refusal("import BsvChain\n#print axioms BsvChain.Properties.fee_nonnegative\n") is None
               and head_refusal("import BsvScript\nmacro_rules | `(tactic| x) => `(tactic| y)\n#print axioms A.b\n") is not None
               and head_refusal("import Test.Common\n#print axioms A.b\n") is not None
               and head_refusal("/- a -/ #eval 1\n#print axioms A.b\n") is not None)
    walk_ok = walked_ok and head_ok and not walk_pin_ok("#print axioms A.b\n-- another walk\n") and (walk_text(text) == "-- the walk\n#eval 1\n"
               and hashlib.sha256(walk_text(text).encode()).hexdigest() != hashlib.sha256(walk_text(text + " ").encode()).hexdigest())
    # the three readers of a name agree on one with a space (the applied set's lens): listed(), the head check, the scan
    spaced = "import BsvScript\n#print axioms A.«t19 x»\n"
    names_agree = (head_refusal(spaced) is None and LISTED.findall(spaced) == ["A.«t19 x»"]
                   and declared_in("namespace A\ntheorem «t19 x» : True := trivial\nend A\n")[0] == ["A.«t19 x»"]
                   and head_refusal("import BsvScript\n#print axioms A.b c\n") is not None)
    ok = (names_agree and compare(["X.a", "X.b"], ["a", "b"]) and not compare(["X.a"], ["a", "b"]) and not compare(["X.b", "X.a"], ["a", "b"])
          and pin_ok({"propext", "Classical.choice", "Quot.sound"}) and not pin_ok(LEAN3 | {"A.planted"})
          and not pin_ok({"propext", "Quot.sound"}) and lst == ["A.«t19 x»", "A.b'"] and walk_ok
          and re.fullmatch(r"[0-9a-f]{64}", WALK_SHA256) is not None)
    ok_all &= ok
    print(f"axiom check --self-test: the list comparison, listed(), the pin, the walk's pin, walked() and the head {'OK' if ok else 'FAILED'} (listed {lst})")
    # 5. each refusal planted, and the same words in comments and strings (a tactic macro among the quiet ones)
    planted = ["attribute [implemented_by f] g", "@[extern \"c\"] opaque h : Nat", "attribute [extern \"c\"] g",
               "@[inline, extern \"c\"] def k : Nat := 1", "#eval addDecl d", "set_option debug.skipKernelTC true",
               "theorem x : 1 = 1 := by native_decide", "theorem y : 1 = 1 := by decide +native",
               "theorem z : 1 = 1 := by decide (config := { native := true })", "theorem b : True := by bv_decide",
               "example : 1 = 1 := by decide (native := Bool.true)", "example : 1 = 1 := by decide (config := { native := t })",
               "#check Lean.ofReduceBool", "#check Lean.ofReduceNat", "#check Lean.trustCompiler", "axiom bad : False",
               "@[simp] private axiom bad2 : False", "open Nat in axiom bad3 : False",
               "@[simp, aesop safe (rule_sets := [X])] axiom bad4 : False",
               "run_cmd Lean.setImplementedBy ``f ``g", "def e := Lean.externAttr", "def u : Nat := unsafe (unsafeCast 0)",
               "elab \"x\" : term => pure default", "def m := Lean.modifyEnv id",
               "initialize r : IO.Ref Nat ← IO.mkRef 0", "run_elab pure ()", "run_meta pure ()",
               "def f := s!\"{by native_decide}\"", "def g := trace[x] \"{by native_decide}\"",
               "example : True := by run_tac pure ()", "def x : Nat := by_elab pure default", "simproc zz (_) := fun _ => pure .continue",
               "@[command_elab foo] def ce : Nat := 1", "def o := withOptions id", "def a := Lean.Meta.mkAuxTheorem",
               "@[init zzInitFn] def zzVal : Nat := 5", "attribute [init f] g", "def zzH._unsafe_rec : Nat := 2",
               "example : 1 = 1 := by decide +«native»", "example : 1 = 1 := by decide («native» := true)",
               "example : 1 = 1 := by decide (config := { «native» := true })", "example : True := by bv_check \"x.lrat\"",
               "@[tactic foo] def t : Nat := 1", "axiom/--/bad5 : False", "theorem t : True := by native_decide/- c -/",
               "set_option debug.skipKernelTC/- c -/true in def zzE : Nat := 1", "theorem w : True := by/--/native_decide",
               "def zzNL : Char × Char := ('\n','\"')\nset_option debug.skipKernelTC true in\ndef zzD : Nat := 1\ndef zzC2 : Char := '\"'",
               "def zzCR : Char × Char := ('\r','\"')\nset_option debug.skipKernelTC true in\ndef zzD : Nat := 1\ndef zzC2 : Char := '\"'"]
    hits = [bypass_in(p) is not None for p in planted]
    quiet = bypass_in("/-- `native_decide`, `implemented_by`, `extern`, an axiom, `unsafe`, in a docstring -/\n"
                      "-- decide +native, bv_decide, macro, syntax in a comment\n"
                      "def s : String := \"skipKernelTC ofReduceBool axiom x unsafe\"\n"
                      "def axioms : Nat := 1\n"
                      "theorem ok : 1 = 1 := by decide (config := { native := false })\n"
                      "def unsafeLike : Nat := 1\n"
                      "def f : Nat := [1].foldl (init := 0) (· + ·)\n"
                      "def initialValue : Nat := 1\n"
                      "macro \"t\" : tactic => `(tactic| rfl)\n"
                      "theorem ok2 : True := trivial\n")
    ok = all(hits) and quiet is None
    ok_all &= ok
    print(f"axiom check --self-test: the refusals {'OK' if ok else 'FAILED'} ({sum(hits)} of {len(planted)} planted caught"
          f"{'' if all(hits) else ', missed: ' + str([p for p, h in zip(planted, hits) if not h])}; "
          f"comments, strings and look-alike names {'quiet' if quiet is None else 'TRIPPED: ' + quiet})")
    # 6. the lakefile refusal on crafted lakefiles
    cases = {
        "clean": ("name = \"x\"\n[leanOptions]\npp.unicode.fun = true\n", False, None),
        "a # inside a string": ("moreLeanArgs = [\"#\", \"-Ddebug.skipKernelTC=true\"]\n", True, None),
        "a \\u escape": ("moreLeanArgs = [\"-Ddebug.skip\\u004BernelTC=true\"]\n", True, None),
        "a quoted key": ("[leanOptions]\ndebug.\"skip\\u004BernelTC\" = true\n", True, None),
        "plugins in a target": ("[[lean_lib]]\nname = \"L\"\nplugins = [\"p\"]\n", True, None),
        "a --load-dynlib argument": ("[[lean_exe]]\nname = \"e\"\nmoreLeanArgs = [\"--load-dynlib=x.so\"]\n", True, None),
        "a lakefile.lean beside a clean TOML": ("name = \"x\"\n", True, "import Lake\n"),
        "a TOML that does not parse": ("name = \n", True, None),
    }
    got6 = {}
    for what, (toml, want_red, lean_lf) in cases.items():
        with tempfile.TemporaryDirectory() as td:
            with open(os.path.join(td, "lakefile.toml"), "w", encoding="utf-8") as f:
                f.write(toml)
            if lean_lf is not None:
                with open(os.path.join(td, "lakefile.lean"), "w", encoding="utf-8") as f:
                    f.write(lean_lf)
            r = lakefile_refusal(td)
        got6[what] = (r is not None) == want_red
    ok = all(got6.values())
    ok_all &= ok
    print(f"axiom check --self-test: the lakefile refusal {'OK' if ok else 'FAILED'} ({sum(got6.values())} of {len(got6)} crafted lakefiles judged as they must: "
          f"{[w for w, v in got6.items() if not v] or 'all'})")
    # 7. the macro allowlist (C4N-2): the one allowed block, pinned; any other macro command refused
    allowed_block = ("macro \"impl_descend\" : tactic =>\n"
                     "  `(tactic| repeat' (first | (apply ite_congr rfl <;> intro _) | (apply bind_congr; intro _)))")
    ok = (("lean/BsvScript/Impl/State.lean", hashlib.sha256(allowed_block.encode()).hexdigest()) in ALLOWED_MACROS
          and macro_refusal("lean/BsvScript/Impl/State.lean", "-- before\n" + allowed_block + "\n\ndef after := 1\n") is None
          and macro_refusal("lean/BsvScript/Impl/State.lean", allowed_block + " -- one more word\n") is not None
          and macro_refusal("lean/BsvScript/Other.lean", allowed_block + "\n") is not None
          and macro_refusal("x.lean", "syntax \"zz\" : term\n") is not None
          and macro_refusal("x.lean", "macro_rules | `(zz) => `(1)\n") is not None
          and macro_refusal("x.lean", "-- a macro in a comment\ndef s := \"macro\"\n") is None)
    ok_all &= ok
    print(f"axiom check --self-test: the macro allowlist {'OK' if ok else 'FAILED'}")
    print(f"axiom check --self-test: {'OK' if ok_all else 'FAILED'}")
    return 0 if ok_all else 1


def history_check():
    """Check every private history theorem using the same axiom and source rules."""
    lean = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lean")
    source = os.path.join(lean, "BsvScript", "Numbers", "History.lean")
    check = os.path.join(lean, "Test", "HistoryCheck.lean")
    src = open(source, encoding="utf-8").read()
    names, unparsed = declared_in(src)
    if bypass_in(src) or macro_refusal("lean/BsvScript/Numbers/History.lean", src) or unparsed:
        print("history axiom check: FAILED source discipline")
        return 1
    want = listed(check)
    if set(names) != set(want) or len(names) != len(want):
        print("history axiom check: FAILED theorem coverage")
        return 1
    r = subprocess.run(["lake", "env", "lean", "Test/HistoryCheck.lean"], cwd=lean,
                       capture_output=True, text=True)
    allowed = {"propext", "Classical.choice", "Quot.sound"}
    entries, rest = judge(r.stdout, allowed)
    if r.returncode or rest.strip() or r.stderr.strip() or any(extra for _, _, extra in entries) or sorted(n for n, _, _ in entries) != sorted(want):
        print(r.stdout + r.stderr)
        print("history axiom check: FAILED")
        return 1
    print(f"history axiom check: GREEN ({len(entries)} theorems; only the three allowed axioms)")
    return 0


def main():
    if "--history" in sys.argv[1:]:
        return history_check()
    if "--self-test" in sys.argv[1:]:
        return self_test()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lean = os.path.join(root, "lean")
    allowed = set()
    for line in open(os.path.join(lean, "AXIOMS-ALLOWED")):
        line = line.strip()
        if line and not line.startswith("#"):
            allowed.add(line)
    if not pin_ok(allowed):
        print(f"axiom check: FAILED, lean/AXIOMS-ALLOWED lists {sorted(allowed)}; CLAUDE.md rule 7 names exactly Lean's three (C-14)")
        return 1
    lk = lakefile_refusal(lean)
    if lk:
        print(f"axiom check: FAILED, the lakefile: {lk} (C2N-3, C3N-5)")
        return 1
    axc = os.path.join(lean, "AxiomCheck.lean")
    head = head_refusal(open(axc, encoding="utf-8", newline="").read())
    if head:
        print(f"axiom check: FAILED, lean/AxiomCheck.lean holds, before its walk, more than comments, its imports and the list: {head} (C4N-5)")
        return 1
    if not walk_pin_ok(open(axc, encoding="utf-8", newline="").read()):
        print("axiom check: FAILED, the walk's text in lean/AxiomCheck.lean is off its pin (WALK_SHA256; C3N-8): a change of the walk updates the pin under both owners' tags")
        return 1
    decl, unparsed = [], []
    srcs = sources(lean)
    for path in srcs:
        src = open(path, encoding="utf-8", newline="").read()
        hit = bypass_in(src) or macro_refusal(os.path.relpath(path, root), src)
        if hit:
            print(f"axiom check: FAILED, {path} uses `{hit}` (a kernel bypass, a compiler override, a native or compiler-trusting spelling, an `axiom`, or a metaprogramming command; C-14, CN-3, C2N-3, C3N-4)")
            return 1
        names, unp = declared_in(src)
        decl += names
        unparsed += [(path, k, line) for k, line in unp]
    if unparsed:
        print(f"axiom check: FAILED, {len(unparsed)} place(s) the scan cannot read (CN-2, C2N-1, C2N-2, C3N-3): {unparsed[:10]}")
        return 1
    r = subprocess.run(["lake", "env", "lean", "AxiomCheck.lean"], cwd=lean, capture_output=True, text=True)
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        print(out)
        print("axiom check: `lake env lean AxiomCheck.lean` FAILED")
        return 1
    entries, rest = judge(out, allowed)
    for name, axioms, extra in entries:
        print(f"  {name}: {axioms if axioms else 'none'}" + (f"  <-- NOT ALLOWED: {extra}" if extra else ""))
    for line in rest.splitlines():
        if line.strip():
            print("  " + line)
    want = listed(axc)
    if not entries:
        print("axiom check: ZERO theorems checked (AxiomCheck.lean lists none, or the output format changed)")
        return 1
    got = [e[0] for e in entries]
    if not compare(got, want):
        print(f"axiom check: FAILED, {len(got)} entries judged against {len(want)} `#print axioms` lines in AxiomCheck.lean")
        return 1
    wok, wwhy = walk_judge(out, len(walked(lean, srcs)), len(want))
    if not wok:
        print(f"axiom check: FAILED, the walk: {wwhy}")
        return 1
    unlisted = sorted(set(decl) - set(want))
    if unlisted:
        print(f"axiom check: FAILED, {len(unlisted)} declared theorem(s) not on AxiomCheck.lean's list: {unlisted[:20]}")
        return 1
    bad = [(n, x) for n, _, x in entries if x]
    if bad:
        print(f"axiom check: FAILED, {len(bad)} theorem(s) depend on axioms outside AXIOMS-ALLOWED")
        return 1
    print(f"axiom check: OK ({len(entries)} theorem(s), every declared theorem among them; the walk: {wwhy}; allowed = {sorted(allowed)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
