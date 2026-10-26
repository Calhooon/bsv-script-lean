#!/usr/bin/env python3
"""The grep gate on the public edition (bsv-script-lean #46; NORTH-STAR constitution 05).

Runs on an export target written by tools/export_public.sh. Three legs:
  (a) mechanism: tools/mechanism_check.sh's two legs over the export. The vocabulary
      (the VOCAB line of tools/host_private.sh, which that check sources, so the list lives once) and the 64-hex rule
      over the exported harness/src; every corpus hex string of 40 characters or more
      against the sibling trees of the same file's SIBLINGS line (tools/mechanism_hex.py),
      except the named public constants and rooted public-header path rule in
      tools/mechanism_allow.txt. A
      sibling tree absent here is named, leg 2 is not run, and the gate cannot
      pass: exit 2.
  (b) pointer: the patterns of tools/export_pointers.txt over every exported file.
  (c) wording: the claim words the north star refuses (the unqualified word for
      matching a reference without a run, the licence adjective the owner retired,
      the long dash, and the priority word; the three words outside the exact
      phrases of tools/wording_allow.txt) over every exported text file. The dated
      history, `docs/records/` and `docs/audit/`, is EXEMPT from this leg (the owner's
      ruling C3 of 2026-10-06): its hits are counted and printed under "history,
      counted, not gated", and never fail the gate. The pointer leg still gates the
      history (after the export's records transform it must be clean).
The named-entry list is counted by distinct spend (witness copies share the source
ID) and every listed row must occur once with every selected field carrying its exact
disclosure marker. Markers contain no mechanism hex and remain clean text.
  (d) BUILD, opt-in by `--build` (the sub-minute gate stays sub-minute; the flip day's
      FULL gate passes it, #107): in the export, `cargo build --release --locked --offline`
      under `harness/` with CARGO_BUILD_JOBS=4 and a cold CARGO_TARGET_DIR under
      ~/bsv/targets/spec-export/.cargo/ (never the repository's target: a stranger has no
      cache), then `cargo test --release --locked --offline --no-run`. Each verdict line
      names the exit code, the wall and the binaries built; a crate absent offline, or cargo
      absent on PATH, is named and the leg is RED (it never fetches); the cold target is
      removed after the leg and the space freed is printed.
The lists are read at the manifest's `source-commit` (export_public.open_list, #107);
wording_allow.txt, mechanism_allow.txt (read by mechanism_hex.py) and host_private.sh stay
working-tree reads by name.
A hit prints file, line, leg and group; the matched text is printed only for the
wording leg. `--rows <file>` writes the hits as tab-separated rows for a record.
Exit 0 clean; 1 on any hit or failed leg; 2 when only a sibling tree is absent.

Usage: export_gate.py <target-dir> [--rows <file>] [--build]
"""
import json, os, re, shutil, subprocess, sys, time
from export_public import entry_marker, entry_field, metadata_field, load_withheld_entries, withheld_entry_counts
from export_public import load_withheld_rules, rule_entry_counts, rule_row_class, withhold_rule_data
from export_public import git, is_text, load_rewrites, open_list, rule_pointer_groups, withhold_rule_history
import export_public

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, 'tools')
MANIFEST = 'EXPORT-MANIFEST.txt'
HISTORY = ('docs/records/', 'docs/audit/')
CLASS_ROWS = re.compile(r'^### \S+ \(\d+ class rows\)$', re.M)
# Written with a character class so this file carries none of the words it gates.
WORDING = [
    ('conformance-claim', re.compile(r'\bconforman[t]\b', re.I)),
    ('licence-adjective', re.compile(r'\bpermissiv[e]\b', re.I)),
    ('long-dash', re.compile(r'\u2014')),
    ('priority-word', re.compile(r'\bfirs[t]\b', re.I)),
]


def mechanism_lists():
    # the VOCAB and SIBLINGS lines tools/mechanism_check.sh sources, from the owner's withheld host file
    src = open(os.path.join(TOOLS, 'host_private.sh'), encoding='utf-8').read()
    vocab = re.search(r"^VOCAB='([^']*)'", src, re.M).group(1)
    sibs = re.search(r'^SIBLINGS=\(([^)]*)\)', src, re.M).group(1)
    siblings = [s.strip('"').replace('$HOME', os.environ['HOME']) for s in sibs.split()]
    return re.compile(vocab), siblings


def load_groups(path, flags=0):
    out, group = [], None
    for raw in open_list(path):
        line = raw.rstrip('\n')
        if line.startswith('## '):
            group = line[3:].strip()
        elif line.strip() and not line.startswith('#'):
            out.append((group, re.compile(line.strip(), flags)))
    return out


def load_allow(path):
    phrases = []
    for raw in open(path, encoding='utf-8'):
        line = raw.rstrip('\n')
        if line.strip() and not line.startswith('#'):
            phrases.append(line.strip().lower())
    return sorted(phrases, key=len, reverse=True)


def redact(text, pointers):
    """A wording excerpt never carries a pointer: each match becomes its group's name."""
    for group, pat in pointers:
        text = pat.sub(f'<{group}>', text)
    return text


def files_of(target):
    for dirpath, dirnames, filenames in os.walk(target):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if not os.path.islink(full):
                yield os.path.relpath(full, target), full


def text_lines(full):
    data = open(full, 'rb').read()
    if full.endswith('.gz') or b'\0' in data[:8192]:
        return None
    return data.decode('utf-8', 'replace').splitlines()


def check_withheld_entries(target, entries):
    """Every named row and selected field must carry its own group marker."""
    rows = []
    for rel, ids in entries.items():
        full = os.path.join(target, rel)
        if not os.path.isfile(full) or os.path.islink(full):
            rows.append(('withheld-entry', 'missing-file', rel, 0, ''))
            continue
        seen = set()
        for n, line in enumerate(text_lines(full) or [], 1):
            try:
                row = json.loads(line)
            except ValueError:
                rows.append(('withheld-entry', 'invalid-json', rel, n, ''))
                continue
            if not isinstance(row, dict) or not isinstance(row.get('id'), str):
                rows.append(('withheld-entry', 'invalid-row', rel, n, ''))
                continue
            entry_id = row['id']
            if entry_id not in ids:
                if any(isinstance(row.get(k), str) and row[k].startswith('WITHHELD:')
                       for k in ('tx', 'prevouts', 'note')):
                    rows.append(('withheld-entry', 'unlisted-marker', rel, n, ''))
                continue
            if entry_id in seen:
                rows.append(('withheld-entry', 'duplicate-id', rel, n, ''))
            seen.add(entry_id)
            for field, group in ids[entry_id].items():
                try:
                    parent, key = entry_field(row, field)
                    valid = parent[key] == entry_marker(group)
                except (KeyError, TypeError):
                    valid = False
                if not valid:
                    rows.append(('withheld-entry', 'invalid-marker', rel, n, ''))
        if set(ids) - seen:
            rows.append(('withheld-entry', 'missing-id', rel, 0, ''))
    return rows


def pointer_summary(counts, pointers):
    """Report every configured group, including groups with no hits (#101)."""
    groups = sorted({g for g, _ in pointers} | set(counts))
    return (f'(pointer) {sum(counts.values())} hit(s)'
            + ''.join(f'; {g} {counts.get(g, 0)}' for g in groups))


def check_withheld_rules(target):
    """Rule absence, exact retained counts and generated report counts are gated."""
    policy, rows, summaries = load_withheld_rules(), [], []
    classes = {cls for selected in policy.values() for cls in selected}
    for rel, full in files_of(target):
        if not (rel.startswith('harness/rules/') and rel.endswith('.json')):
            continue
        try:
            with open(full, 'rb') as stream:
                raw = stream.read()
            json.loads(raw)
            if any(cls.encode() in raw for cls in classes):
                rows.append(('withheld-rule', 'present-class', rel, 0, ''))
        except (OSError, ValueError):
            rows.append(('withheld-rule', 'invalid-json', rel, 0, ''))
    for rel, selected in policy.items():
        try:
            with open(os.path.join(ROOT, rel), 'rb') as stream:
                private = stream.read()
            expected_bytes, n, k = withhold_rule_data(rel, private, selected)
            expected = json.loads(expected_bytes)
            with open(os.path.join(target, rel), encoding='utf-8') as stream:
                public = json.load(stream)
            engine = expected['engine']
            if len(public['classes']) != len(expected['classes']) or len(public['rows']) != len(expected['rows']):
                rows.append(('withheld-rule', 'count-mismatch', rel, 0, ''))
            for group in sorted(set(selected.values())):
                summaries.append((group, sum(g == group for g in selected.values()),
                                  sum(selected.get(rule_row_class(r)) == group for r in json.loads(private)['rows'])))
            with open(os.path.join(target, 'corpus', 'witnesses', engine, 'manifest.json'), encoding='utf-8') as stream:
                manifest = json.load(stream)
            current = [r for corpus in manifest.values() if isinstance(corpus, dict) for r in corpus.get('rules', [])]
            kinds = {'IMPLEMENTATION-WRONG': set(), 'SPEC-SIDE': set(), 'OPEN': set(), 'MECHANISM': set()}
            for r in current:
                cls = r['rule']
                ruling = r.get('ruling') or public['classes'].get(cls, {}).get('ruling')
                kind = ('MECHANISM' if cls.startswith('engine.') else 'SPEC-SIDE' if engine == 'sv-node'
                        else 'IMPLEMENTATION-WRONG' if ruling == 'impl-wrong' else 'OPEN')
                kinds[kind].add(cls)
            # the generated classifier report is the page with per-engine `### <engine> (<n> class rows)` sections,
            # and every CONFORMANCE page that names the rule file quotes its counts (#107: the other pages, the
            # association, double-spend, P2P relay, RPC contract and three Teranode pages, carry no classifier table
            # and name no rule file, so the sentence, header and counts recounted here have no place on them; a page
            # judged is judged in full, and no such page at all is still `missing-report`)
            reports = [p for p, full in files_of(target) if re.fullmatch(r'docs/CONFORMANCE-[^/]+\.md', p)
                       and (CLASS_ROWS.search(t := open(full, encoding='utf-8').read()) or rel in t)]
            if not reports:
                rows.append(('withheld-rule', 'missing-report', rel, 0, ''))
            for report in reports:
                with open(os.path.join(target, report), encoding='utf-8') as stream:
                    text = stream.read()
                sentence = (f"Exported `{rel}`: [M] {len(public['classes'])} class definitions, "
                            f"[M] {len(public['rows'])} classifier rows;")
                header = f'### {engine} ({len(current)} class rows)'
                counts = '| ' + engine + ' | ' + ' | '.join(str(len(v)) for v in kinds.values()) + ' |'
                if sentence not in text or header not in text or counts not in text:
                    rows.append(('withheld-rule', 'report-count-mismatch', report, 0, ''))
        except (OSError, ValueError, KeyError, TypeError):
            rows.append(('withheld-rule', 'missing-or-invalid-artifact', rel, 0, ''))
    return rows, summaries


def check_rule_removal_counts(target):
    """Recount history and report removals at the manifest's source commit."""
    with open(os.path.join(target, MANIFEST), encoding='utf-8') as stream:
        manifest = stream.read()
    source = re.findall(r'^source-commit ([0-9a-f]{40})$', manifest, re.M)
    if len(source) != 1:
        raise ValueError('invalid source commit')
    policy = load_withheld_rules()
    plan = dict(pointers=rule_pointer_groups(policy), history={},
                classes={cls: {'group': group} for selected in policy.values() for cls, group in selected.items()})
    with open_list(os.path.join(TOOLS, 'export_withheld_history.json')) as stream:
        plan['spans'] = json.load(stream)
    rewrites = load_rewrites(os.path.join(TOOLS, 'export_rewrite.txt'))
    reports = {}
    for rel, full in files_of(target):
        history = rel.startswith(HISTORY) and rel not in rewrites
        report = re.fullmatch(r'docs/CONFORMANCE-[^/]+\.md', rel)
        if not (history or report):
            continue
        try:
            private = git('show', f'{source[0]}:{rel}')
        except subprocess.CalledProcessError:
            raise ValueError('missing source artifact') from None
        if history and is_text(rel, private):
            withhold_rule_history(rel, private, [], plan)
        if report:
            count = 0
            for line in private.decode().splitlines():
                cells = line.split('|')
                if len(cells) > 2 and cells[1].strip().strip('`') in plan['classes']:
                    count += 1
            if count:
                reports[rel] = count
    history_counts = [(group, sum(per.get(group, 0) for per in plan['history'].values()),
                       sum(group in per for per in plan['history'].values()))
                      for group in sorted(plan['pointers'])]
    declared_history = [(g, int(n), int(k)) for g, n, k in re.findall(
        r'^withheld-history-group (\S+) (\d+) lines in (\d+) files$', manifest, re.M)]
    declared_reports = [(p, int(n)) for n, p in re.findall(
        r'^withheld-report-rows (\d+) (.+)$', manifest, re.M)]
    rows = []
    if sorted(declared_history) != history_counts:
        rows.append(('withheld-rule', 'history-count-mismatch', MANIFEST, 0, ''))
    if sorted(declared_reports) != sorted(reports.items()):
        rows.append(('withheld-rule', 'report-removal-count-mismatch', MANIFEST, 0, ''))
    summaries = [f'(withheld history) {n} lines in {k} files, group {g}' for g, n, k in history_counts]
    summaries += [f'(withheld report rows) {n} {p}' for p, n in sorted(reports.items())]
    return rows, summaries


def missing_crates(stderr):
    """The crates an offline resolution or download could not find, by name (never fetched)."""
    names = re.findall(r'no matching package named `([^`]+)`', stderr)
    names += re.findall(r'failed to download `([^`]+)`', stderr)
    names += [f'{n} v{v}' for n, v in re.findall(r'/api/v1/crates/([^/\s]+)/([^/\s]+)/download', stderr)]
    return list(dict.fromkeys(names))


def cargo_step(args, harness, env):
    """(exit code, wall seconds, executables built, stderr) for one cargo command."""
    start = time.monotonic()
    r = subprocess.run(['cargo', *args, '--message-format=json-render-diagnostics'], cwd=harness, env=env,
                       capture_output=True, text=True)
    built = []
    for line in r.stdout.splitlines():
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get('reason') == 'compiler-artifact' and msg.get('executable'):
            built.append(msg['target']['name'])
    return r.returncode, time.monotonic() - start, sorted(set(built)), r.stderr


def build_leg(target):
    """(d) BUILD: the exported harness built as a stranger would. ([verdict lines], [failures])."""
    if shutil.which('cargo') is None:
        return ['(build) cargo absent on PATH: RED, never a pass'], ['build leg RED: cargo absent on PATH']
    harness = os.path.join(target, 'harness')
    cache = os.path.join(os.environ['HOME'], 'bsv', 'targets', 'spec-export', '.cargo', os.path.basename(target))
    if os.path.isdir(cache):
        shutil.rmtree(cache)
    env = dict(os.environ, CARGO_BUILD_JOBS='4', CARGO_TARGET_DIR=cache)
    lines, failures = [f'(build) cold target {cache}'], []
    for name, args in (('build', ['build', '--release', '--locked', '--offline']),
                       ('test --no-run', ['test', '--release', '--locked', '--offline', '--no-run'])):
        code, wall, built, stderr = cargo_step(args, harness, env)
        lines.append(f'(build) cargo {" ".join(args)}: exit {code}, wall {wall:.1f} s, '
                     f'{len(built)} executable(s): {", ".join(built) or "none"}')
        if code:
            crates = missing_crates(stderr)
            failures.append(f'build leg RED: cargo {name} exit {code}'
                            + (f'; absent offline: {", ".join(crates)}' if crates else ''))
            break
    # the cold target is the stranger's, not a cache: removed after the leg, its size named
    freed = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(cache) for f in fs)
    if os.path.isdir(cache):
        shutil.rmtree(cache)
    lines.append(f'(build) cold target removed, {freed / 2**30:.1f} GiB freed')
    return lines, failures


def fail(reason):
    """An incomplete check must never report a clean export."""
    print(f'export gate: FAILED ({reason})')
    sys.exit(1)


def run_gate():
    args = sys.argv[1:]
    rows_path, build = None, '--build' in args
    args = [a for a in args if a != '--build']
    if '--rows' in args:
        i = args.index('--rows'); rows_path = args[i + 1]; del args[i:i + 2]
    if len(args) != 1:
        sys.exit(__doc__)
    target = os.path.abspath(args[0])
    if not os.path.isfile(os.path.join(target, MANIFEST)):
        fail('missing export manifest')
    vocab, siblings = mechanism_lists()
    allow = load_allow(os.path.join(TOOLS, 'wording_allow.txt'))
    entries_path = os.path.join(target, 'tools', 'export_withheld_entries.txt')
    entries = load_withheld_entries(entries_path) if os.path.isfile(entries_path) else {}
    # #107: the gate judges an export of commit X with X's lists, read at the manifest's `source-commit`
    # (the export's own entry list above is a file of the export; wording_allow.txt and host_private.sh stay
    # working-tree reads by name)
    source = re.findall(r'^source-commit ([0-9a-f]{40})$',
                        open(os.path.join(target, MANIFEST), encoding='utf-8').read(), re.M)
    if len(source) == 1:
        export_public.LIST_COMMIT = source[0]
    pointers = load_groups(os.path.join(TOOLS, 'export_pointers.txt'), re.I)
    entry_counts = rule_entry_counts(entries)
    rows = check_withheld_entries(target, entries)
    rule_rows, rule_summaries = check_withheld_rules(target)
    removal_rows, removal_summaries = check_rule_removal_counts(target)
    rule_rows.extend(removal_rows)
    rows.extend(rule_rows)
    metadata = json.load(open_list(os.path.join(TOOLS, 'export_withheld_metadata.json')))
    for rel, rules in metadata.items():
        try:
            data = json.load(open(os.path.join(target, rel), encoding='utf-8'))
            for rule in rules:
                parent, key = metadata_field(data, rule['pointer'])
                if parent[key] != entry_marker(rule['group']):
                    rows.append(('withheld-metadata', 'invalid-marker', rel, 0, ''))
        except (OSError, ValueError, KeyError, IndexError, TypeError):
            rows.append(('withheld-metadata', 'missing-field', rel, 0, ''))
    # (leg, group, file, line, text-or-empty)
    if not os.path.isfile(entries_path):
        manifest = open(os.path.join(target, MANIFEST), encoding='utf-8').read()
        if 'withheld-entry-list ' in manifest:
            rows.append(('withheld-entry', 'missing-list', 'tools/export_withheld_entries.txt', 0, ''))
    history = {}  # wording category -> count, for the exempt dated history
    history_files = {}  # file -> count

    # (a) mechanism, leg 1: vocabulary outside comment lines, and 64-hex literals, in harness/src
    for rel, full in files_of(target):
        if not (rel.startswith('harness/src/') and rel.endswith('.rs')):
            continue
        for n, line in enumerate(text_lines(full) or [], 1):
            if vocab.search(line) and not re.match(r'\s*//', line):
                rows.append(('mechanism', 'vocabulary', rel, n, ''))
            if re.search(r'[0-9a-f]{64}', line):
                rows.append(('mechanism', '64-hex-literal', rel, n, ''))
    # (a) mechanism, leg 2: corpus hex strings against the sibling trees
    absent = [s for s in siblings if not os.path.isdir(s)]
    present = [s for s in siblings if os.path.isdir(s)]
    corpus = sorted(full for rel, full in files_of(target) if rel.startswith('corpus/') and rel.endswith('.jsonl'))
    failures = []
    hex_note = 'no corpus files: leg 2 not run'
    if absent:
        # leg 2 cannot pass without every tree, so it is not run on a partial set (it is the slow leg)
        hex_note = 'not run: ' + ', '.join(absent) + ' absent here'
    elif corpus:
        r = subprocess.run([sys.executable, os.path.join(TOOLS, 'mechanism_hex.py'), '--root', target, *present, '--', *corpus],
                           capture_output=True, text=True)
        hex_hits = 0
        for line in r.stdout.splitlines():
            m = re.match(r'\(2\) FAIL: (.*?) contains a hex string of (\S+):', line)
            if m:
                hex_hits += 1
                rows.append(('mechanism', 'corpus-hex-in-sibling', os.path.relpath(m.group(2), target), 0, ''))
        hex_note = f'{len(corpus)} corpus files against {len(present)} present sibling tree(s), exit {r.returncode}'
        if r.returncode != 0 and not (r.returncode == 1 and hex_hits and not r.stderr.strip()):
            failures.append(f'mechanism leg 2 failed: exit {r.returncode}, {hex_hits} counted hit(s)'
                            + ('; stderr present' if r.stderr.strip() else ''))
    elif not absent:
        failures.append('mechanism leg 2 has no corpus files')

    if not os.path.isfile(os.path.join(target, MANIFEST)):
        fail('export manifest disappeared during mechanism leg 2')
    if any(not os.path.isfile(path) for path in corpus):
        fail('corpus file disappeared during mechanism leg 2')
    if any(not os.path.isdir(path) for path in present):
        fail('sibling tree disappeared during mechanism leg 2')

    # (b) pointer and (c) wording over every exported text file
    for rel, full in files_of(target):
        lines = text_lines(full)
        if lines is None:
            continue
        for n, line in enumerate(lines, 1):
            for group, pat in pointers:
                if pat.search(line):
                    rows.append(('pointer', group, rel, n, '')); break
            low = line.lower()
            for phrase in allow:
                low = low.replace(phrase, ' ' * len(phrase))
            for cat, pat in WORDING:
                probe = line if cat == 'long-dash' else low
                for m in pat.finditer(probe):
                    if rel.startswith(HISTORY):
                        history[cat] = history.get(cat, 0) + 1
                        history_files[rel] = history_files.get(rel, 0) + 1
                        continue
                    a, b = max(0, m.start() - 40), min(len(line), m.end() + 40)
                    rows.append(('wording', cat, rel, n, redact(line[a:b].strip(), pointers)))

    # (e) json: every exported .json parses (the hosted gate of 2026-10-26: a one-line record whose line
    # was withheld is not JSON), and (f) the records index of the export is current (tools/check.sh's
    # seed leg reads it on the hosted gate).
    for base, dirs, names in os.walk(target):
        dirs[:] = [d for d in dirs if d != '.git']
        for name in names:
            if name.endswith('.json'):
                full = os.path.join(base, name)
                rel = os.path.relpath(full, target)
                try:
                    with open(full, 'rb') as f:
                        json.load(f)
                except (ValueError, UnicodeDecodeError) as e:
                    rows.append(('json', 'invalid', rel, 0, str(e)[:80]))
    index_tool = os.path.join(target, 'tools', 'records_index.py')
    if os.path.isfile(index_tool):
        index_check = subprocess.run([sys.executable, index_tool, '--check'], capture_output=True, text=True, cwd=target)
        if index_check.returncode != 0:
            rows.append(('records-index', 'stale', 'docs/records/INDEX.md', 0,
                         (index_check.stdout + index_check.stderr).strip().splitlines()[-1][:120]))
    else:
        print('(records-index) tools/records_index.py absent from the export: leg SKIPPED BY NAME')

    legs = {}
    for leg, group, *_ in rows:
        legs.setdefault(leg, {}).setdefault(group, 0)
        legs[leg][group] += 1
    for leg, group, rel, n, text in rows:
        where = f'{rel}:{n}' if n else rel
        print(f'HIT {leg} [{group}] {where}' + (f'  "{text}"' if leg == 'wording' else ''))
    print('== the gate on', target)
    for group, (n, k) in entry_counts.items():
        print(f'(withheld entries) {n} in {k} files, group {group}')
    for group, n, k in rule_summaries:
        print(f'(withheld rules) {n} classes, {k} rows, group {group}')
    for summary in removal_summaries:
        print(summary)
    print(f'(withheld-rule) {len(rule_rows)} hit(s)')
    print(f'(a) mechanism leg 2: {hex_note}')
    for s in absent:
        print(f'(a) ABSENT sibling tree: {s} (the gate cannot pass here; run it where the tree is)')
    for leg in ('mechanism', 'pointer', 'wording', 'json', 'records-index'):
        per = legs.get(leg, {})
        print(pointer_summary(per, pointers) if leg == 'pointer' else
              f'({leg}) {sum(per.values())} hit(s)' + ''.join(f'; {g} {c}' for g, c in sorted(per.items())))
    print('== history, counted, not gated (the wording leg over docs/records/ and docs/audit/)')
    print(f'(wording, history) {sum(history.values())} hit(s) in {len(history_files)} file(s)'
          + ''.join(f'; {g} {c}' for g, c in sorted(history.items())))
    if build:
        build_lines, build_failures = build_leg(target)
        failures.extend(build_failures)
        print('\n'.join(build_lines))
    else:
        print('(build) not run (opt-in: --build)')
    if rows_path:
        with open(rows_path, 'w', encoding='utf-8') as f:
            for leg, group, rel, n, text in rows:
                f.write(f'{leg}\t{group}\t{rel}\t{n}\t{text}\n')
        with open(rows_path + '.history', 'w', encoding='utf-8') as f:
            for rel, c in sorted(history_files.items()):
                f.write(f'{rel}\t{c}\n')
    if not os.path.isfile(os.path.join(target, MANIFEST)):
        fail('export manifest disappeared during the scan')
    if failures:
        fail('; '.join(failures))
    if rows:
        print('export gate: FAILED'); sys.exit(1)
    if absent:
        print('export gate: INCOMPLETE (a sibling tree is absent)'); sys.exit(2)
    print('export gate: CLEAN')


def main():
    try:
        run_gate()
    except (OSError, ValueError, KeyError, TypeError) as error:
        # Paths and subprocess diagnostics can carry private values. Name the
        # failure category, never their contents.
        fail(f'gate input could not be checked: {type(error).__name__}')


if __name__ == '__main__':
    main()
