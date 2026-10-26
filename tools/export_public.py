#!/usr/bin/env python3
"""The public edition's export (bsv-script-lean #46; NORTH-STAR constitution 05).

Writes every tracked path of a named commit into an empty target directory, except
the paths `tools/export_withheld.txt` withholds. Blobs are read from git's object
store one by one (`git cat-file blob`), so a withheld path's contents are never
read: only its name is matched, printed and listed. No git history is carried; the
target is a plain tree. The manifest `EXPORT-MANIFEST.txt` in the target names the
source commit, the date, every exported path with its sha256, and every withheld
path by name with its group.

The declared changes apply to the exported copy only (the repository's files are
never edited). The WITHHELD LIST `tools/export_withheld.txt` omits named paths
without reading their contents. The REWRITE LIST `tools/export_rewrite.txt` (the
owner's ruling C2 of 2026-10-06) replaces exact text blocks in named files, each
old text present exactly once or the export stops. The RECORDS TRANSFORM (ruling
C3) applies in `docs/records/` and `docs/audit/`: every
line a pattern of `tools/export_pointers.txt` matches is replaced by the marker line
`[withheld at export: a sibling tree's line]`, and a transformed file gains one header line
naming the transform and the count. No change prints a line it removes; the manifest
names each rewritten and transformed path with its count. The ENTRY LIST
`tools/export_withheld_entries.txt` (D7, 2026-10-06) replaces only the named JSONL
rows' named fields with a disclosure marker. Their manifests retain the private
sha256 as sha256_private and record the public sha256, row count and group. The
export manifest lists every named row, counting witness copies with their spend.
The METADATA LIST `tools/export_withheld_metadata.json` selects individual JSON
strings by pointer and private sha256;
those strings receive the same group marker without editing private manifests.
The POINTER SUBSTITUTION TRANSFORM (#101) applies outside the dated
records and audit pages: every exported text file substitutes only local-paths,
modal-names and addresses. Home prefixes become `~`, the lanes volume prefix
becomes `<lanes-volume>`, Modal names become `<modal-name>`, and addresses become
`<address>`. Path suffixes and surrounding text remain. The manifest counts each
group's occurrences per file, including occurrences removed by the records
transform, without printing any removed text.
The RULE LIST `tools/export_withheld_rules.txt` (#102) removes selected class
definitions and every classifier row bearing those classes. Opaque entry aliases
preserve source joins. Hash-pinned history spans in
`tools/export_withheld_history.json` feed the records transform; generated report
rows are removed and their totals recounted. Rule references in JSON and pages
receive disclosure markers or have their selected records removed. The manifest
names every transformed and withheld path with its count, including each
rule-reference path's changed fields and removed records.
The CARGO TRANSFORM (#107, 2026-10-17): over every exported `Cargo.toml` (found by
walking the export), every `[[bin]]`, `[[test]]`, `[[bench]]` and `[[example]]` table
whose `path` resolves to a withheld path is dropped from the exported copy, with the
comment lines directly above it and the blank lines below it; every other byte is
kept, and the manifest gains one header comment line naming the count. The export
then STOPS if an exported Cargo manifest still names a withheld path, or if an
exported `.rs` file of a Cargo package names a withheld source by a `mod`,
`#[path]`, `include!`, `include_str!` or `include_bytes!` line (the lines naming a
withheld basename are resolved to paths; the counts are printed). Never a stub: the
public tree carries only what is public.
The MAKEFILE TRANSFORM (#107, 2026-10-17), beside the Cargo one: over every exported
Makefile, a target whose rule line or recipe names a binary the Cargo transform dropped
(`--bin <name>`, a `release/` or `debug/` path to it, its `src/bin/` source) is dropped
with the comment lines directly above it and the blank lines below; its name leaves the
`.PHONY:` line; every other byte is kept, and one header comment line names the count.
The export then STOPS if an exported Makefile still names a dropped binary, or names a
dropped target as a prerequisite.
The PUBLIC PAGE MOVE (#169, 2026-10-21): after the tree is written, a page of PUBLIC_PAGES that
was exported replaces its private namesake in the exported copy (`CLAUDE.public.md` over
`CLAUDE.md`, the contributor's agent page over the maintainers' session rules); the manifest
lists the public page's sha256 under the private name and names each move.
Every list above is read from the NAMED COMMIT (`git show <commit>:<path>`), never
from the working tree, so the manifest's "@ <commit>" lines are what was read; one
line says whether the working tree's copies differ (a warning, not a stop).

Usage: export_public.py <target-dir> [<commit>]   (commit defaults to HEAD)
"""
import datetime, fnmatch, hashlib, io, json, os, re, subprocess, sys, tomllib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WITHHELD = os.path.join(ROOT, 'tools', 'export_withheld.txt')
ENTRIES = os.path.join(ROOT, 'tools', 'export_withheld_entries.txt')
REWRITE = os.path.join(ROOT, 'tools', 'export_rewrite.txt')
POINTERS = os.path.join(ROOT, 'tools', 'export_pointers.txt')
METADATA = os.path.join(ROOT, 'tools', 'export_withheld_metadata.json')
MANIFEST = 'EXPORT-MANIFEST.txt'
HISTORY = ('docs/records/', 'docs/audit/')
MARKER = "[withheld at export: a sibling tree's line]"
# Every list the export reads; main() sets LIST_COMMIT, and open_list then reads each from that commit (#107).
LISTS = ('tools/export_withheld.txt', 'tools/export_withheld_entries.txt', 'tools/export_rewrite.txt',
         'tools/export_pointers.txt', 'tools/export_withheld_metadata.json', 'tools/export_withheld_rules.txt',
         'tools/export_withheld_history.json')
LIST_COMMIT = None
CARGO_TARGETS = ('bin', 'test', 'bench', 'example')
# The public page that replaces its private namesake in the exported copy (#169).
PUBLIC_PAGES = {'CLAUDE.public.md': 'CLAUDE.md'}


def git(*args, **kw):
    return subprocess.run(['git', '-C', ROOT, *args], check=True, capture_output=True, **kw).stdout


def open_list(path):
    """A list's text as a stream: the blob at LIST_COMMIT (`git show <commit>:<path>`) once main() names it.

    Each reader keeps its name and its path argument; only the source of the bytes moves. The
    stream translates newlines as `open` does. Unset (the gate, the tests' own fixtures), the file.
    """
    if LIST_COMMIT is None:
        return open(path, encoding='utf-8')
    rel = os.path.relpath(os.path.abspath(path), ROOT)
    if rel.startswith('..'):
        sys.exit(f'export: {path} is outside the repository, so it cannot be read at {LIST_COMMIT[:12]}')
    try:
        blob = git('show', f'{LIST_COMMIT}:{rel}')
    except subprocess.CalledProcessError:
        sys.exit(f'export: {rel} is absent at {LIST_COMMIT[:12]}')
    return io.StringIO(blob.decode('utf-8'), newline=None)


def list_drift(commit):
    """The lists whose working-tree bytes differ from the commit's (a missing file differs)."""
    out = []
    for rel in LISTS:
        try:
            tree = open(os.path.join(ROOT, rel), 'rb').read()
        except OSError:
            tree = None
        try:
            blob = git('show', f'{commit}:{rel}')
        except subprocess.CalledProcessError:
            sys.exit(f'export: {rel} is absent at {commit[:12]}')
        if tree != blob:
            out.append(rel)
    return out


def load_withheld(path):
    """[(group, glob)] in file order; a `## <group>: ...` line opens a group."""
    rules, group = [], None
    for raw in open_list(path):
        line = raw.strip()
        if line.startswith('## '):
            group = line[3:].split(':', 1)[0].strip()
        elif line and not line.startswith('#'):
            if group is None:
                sys.exit(f'export: {path}: glob {line!r} sits above any group line')
            rules.append((group, line))
    return rules


def load_withheld_entries(path):
    """{path: {id: {field: group}}}; optional column 3 selects comma-separated fields."""
    entries, group = {}, None
    allowed = {'tx', 'prevouts', 'note', 'divergence.decided_by', 'divergence.note'}
    for n, raw in enumerate(open_list(path), 1):
        line = raw.rstrip('\n')
        if line.startswith('## '):
            group = line[3:].split(':', 1)[0].strip()
            if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', group):
                sys.exit(f'export: {path}:{n}: invalid entry group')
        elif line.strip() and not line.startswith('#'):
            parts = line.split('\t')
            if group is None or len(parts) not in (2, 3):
                sys.exit(f'export: {path}:{n}: needs group and path<TAB>id[<TAB>fields]')
            file, entry_id = parts[:2]
            fields = parts[2].split(',') if len(parts) == 3 else ['tx', 'prevouts']
            if (not file.startswith('corpus/') or not file.endswith('.jsonl')
                    or any(p in ('', '.', '..') for p in file.split('/'))
                    or not entry_id or any(c.isspace() for c in file + entry_id)
                    or not fields or len(set(fields)) != len(fields) or set(fields) - allowed):
                sys.exit(f'export: {path}:{n}: invalid entry path, id or fields')
            selected = entries.setdefault(file, {}).setdefault(entry_id, {})
            for field in fields:
                if field in selected:
                    sys.exit(f'export: {path}:{n}: duplicate entry field in {file}')
                selected[field] = group
    return entries


def entry_field(row, field):
    """Locate one explicitly named field; an absent path is an error."""
    parts = field.split('.')
    for key in parts[:-1]:
        row = row[key]
    if parts[-1] not in row:
        raise KeyError(field)
    return row, parts[-1]


def entry_groups(entries):
    return list(dict.fromkeys(g for ids in entries.values() for fields in ids.values() for g in fields.values()))


def group_rows(entries, group):
    return [(path, entry_id, sorted(f for f, g in fields.items() if g == group))
            for path, ids in entries.items() for entry_id, fields in ids.items() if group in fields.values()]


def entry_marker(group):
    return f'WITHHELD: {group} (see corpus/INDEX.md)'


def withheld_entry_counts(entries):
    """{group: (distinct entries, files)}; witness copies count with their source ID."""
    counts = {}
    for group in entry_groups(entries):
        rows = group_rows(entries, group)
        primary = {i for p, i, _ in rows if not p.startswith('corpus/witnesses/')}
        spends, files = set(primary), set()
        for path, entry_id, _ in rows:
            files.add(path)
            if path.startswith('corpus/witnesses/'):
                source = next((i for i in sorted(primary, key=len, reverse=True)
                               if entry_id.endswith('-' + i)), entry_id)
                spends.add(source)
        counts[group] = len(spends), len(files)
    return counts


def withhold_entry_data(path, data, ids):
    """Redact selected fields; unselected lines retain their exact bytes."""
    out, seen = [], set()
    for n, raw in enumerate(data.splitlines(keepends=True), 1):
        try:
            row = json.loads(raw)
        except (ValueError, UnicodeError):
            sys.exit(f'export: {path}:{n}: invalid JSONL row')
        if not isinstance(row, dict):
            sys.exit(f'export: {path}:{n}: JSONL row is not an object')
        entry_id = row.get('id')
        if entry_id not in ids:
            out.append(raw)
            continue
        if entry_id in seen:
            sys.exit(f'export: {path}:{n}: duplicate named id or missing spend fields')
        seen.add(entry_id)
        for field, group in ids[entry_id].items():
            try:
                parent, key = entry_field(row, field)
            except (KeyError, TypeError):
                sys.exit(f'export: {path}:{n}: missing named field {field}')
            parent[key] = entry_marker(group)
        end = b'\r\n' if raw.endswith(b'\r\n') else (b'\n' if raw.endswith(b'\n') else b'')
        out.append(json.dumps(row, separators=(',', ':')).encode('utf-8') + end)
    missing = sorted(set(ids) - seen)
    if missing:
        sys.exit(f'export: {path}: named ids missing: {", ".join(missing)}')
    return b''.join(out)


def withhold_manifest_data(path, data, changes):
    """Update a corpus descriptor or named descriptors in a witness manifest."""
    manifest = json.loads(data)
    records = [manifest] if 'file' in manifest else [v for v in manifest.values() if isinstance(v, dict)]
    for file, (private_sha, public_sha, count, groups) in changes.items():
        found = [r for r in records if r.get('file') == file]
        if len(found) != 1 or found[0].get('sha256') != private_sha:
            sys.exit(f'export: {path}: {file} needs one descriptor with its private sha256')
        row = found[0]
        row['sha256_private'] = row['sha256']
        row['sha256'] = public_sha
        row['withheld_entries'] = count
        row['withheld_groups'] = groups
        if len(groups) == 1:
            row['withheld_group'] = next(iter(groups))
        else:
            row.pop('withheld_group', None)
    return (json.dumps(manifest, indent=2) + '\n').encode('utf-8')


def entry_exports(entries, blobs, rules):
    """Validate every named blob and manifest before writing the exported tree."""
    def read(path):
        meta = blobs.get(path)
        if (meta is None or meta[0] not in ('100644', '100755') or meta[1] != 'blob'
                or group_of(rules, path) is not None):
            sys.exit(f'export: entry list needs an exported regular file: {path}')
        return git('cat-file', 'blob', meta[2])

    overrides, manifests = {}, {}
    for path, ids in entries.items():
        private = read(path)
        public = withhold_entry_data(path, private, ids)
        overrides[path] = public
        manifest_path = os.path.join(os.path.dirname(path), 'manifest.json')
        manifests.setdefault(manifest_path, {})[os.path.basename(path)] = (
            hashlib.sha256(private).hexdigest(), hashlib.sha256(public).hexdigest(),
            len(ids), {g: sum(g in fields.values() for fields in ids.values())
                       for g in entry_groups({path: ids})})
    for path, changes in manifests.items():
        overrides[path] = withhold_manifest_data(path, read(path), changes)
    return overrides


def metadata_field(row, pointer):
    """RFC 6901 object/array path, explicitly listed for the exported copy."""
    parts = [p.replace('~1', '/').replace('~0', '~') for p in pointer.split('/')[1:]]
    if not pointer.startswith('/') or not parts:
        raise KeyError(pointer)
    for key in parts[:-1]:
        row = row[int(key)] if isinstance(row, list) else row[key]
    key = int(parts[-1]) if isinstance(row, list) else parts[-1]
    row[key]
    return row, key


def withhold_metadata(path, data, rules):
    """Named metadata strings only; payload fields use the entry transform."""
    row = json.loads(data)
    for rule in rules:
        try:
            parent, key = metadata_field(row, rule['pointer'])
        except (KeyError, IndexError, ValueError, TypeError):
            sys.exit(f"export: {path}: absent metadata field {rule['pointer']}")
        value = parent[key]
        if not isinstance(value, str) or hashlib.sha256(value.encode()).hexdigest() != rule['sha256']:
            sys.exit(f"export: {path}: metadata field changed: {rule['pointer']}")
        parent[key] = entry_marker(rule['group'])
    return (json.dumps(row, indent=2, ensure_ascii=False) + '\n').encode()


def load_rewrites(path):
    """{path: [(old, new)]}: `@@ <path>` names the file; `<<<<` old `====` new `>>>>` a block."""
    out, cur, state, old, new = {}, None, None, [], []
    for n, raw in enumerate(open_list(path), 1):
        line = raw.rstrip('\n')
        if state is None:
            if line.startswith('@@ '):
                cur = line[3:].strip(); out.setdefault(cur, [])
            elif line == '<<<<':
                if cur is None:
                    sys.exit(f'export: {path}:{n}: a block above any `@@ <path>` line')
                state, old, new = 'old', [], []
            elif line.strip() and not line.startswith('#'):
                sys.exit(f'export: {path}:{n}: a line outside any block')
        elif state == 'old':
            if line == '====':
                state = 'new'
            else:
                old.append(raw)
        elif line == '>>>>':
            out[cur].append((''.join(old), ''.join(new))); state = None
        else:
            new.append(raw)
    if state is not None:
        sys.exit(f'export: {path}: an unterminated block')
    return out


def load_pointers(path):
    pats = []
    for raw in open_list(path):
        line = raw.strip()
        if line and not line.startswith('#'):
            pats.append(re.compile(line, re.I))
    return pats


def is_text(path, data):
    return not (path.endswith('.gz') or b'\0' in data[:8192])


def rewrite(path, data, blocks):
    text = data.decode('utf-8')
    for i, (old, new) in enumerate(blocks, 1):
        c = text.count(old)
        if c != 1:
            sys.exit(f'export: {path}: rewrite block {i} of tools/export_rewrite.txt matches {c} times (needs exactly 1)')
        text = text.replace(old, new)
    return text.encode('utf-8')


def transform(data, pointers):
    """The records transform: (new bytes, lines replaced). Never prints a line."""
    lines = data.decode('utf-8', 'surrogateescape').splitlines(keepends=True)
    out, count = [], 0
    for line in lines:
        if any(p.search(line) for p in pointers):
            end = '\r\n' if line.endswith('\r\n') else ('\n' if line.endswith('\n') else '')
            out.append(MARKER + end); count += 1
        else:
            out.append(line)
    if not count:
        return data, 0
    head = (f'[export: {count} line{"s" if count != 1 else ""} withheld by tools/export_public.py, '
            "the sibling trees' lines; the original is in the private history]\n")
    return (head + ''.join(out)).encode('utf-8', 'surrogateescape'), count


def transform_json(data, pointers):
    """The records transform for a JSON record: a withheld LINE would leave no JSON (the hosted gate of
    2026-10-26 found 63 of 186 exported records unreadable), so every string a pointer matches becomes
    the marker and the document stays JSON; (new bytes, strings replaced). The shape (one line or
    indented) is kept; a file that is not JSON takes the line transform."""
    text = data.decode('utf-8', 'surrogateescape')
    try:
        obj = json.loads(text)
    except ValueError:
        return transform(data, pointers)
    count = 0

    def visit(x):
        nonlocal count
        if isinstance(x, str):
            if any(p.search(x) for p in pointers):
                count += 1
                return MARKER
            return x
        if isinstance(x, list):
            return [visit(v) for v in x]
        if isinstance(x, dict):
            out, keys = {}, 0
            for k, v in x.items():
                if any(p.search(k) for p in pointers):
                    keys += 1; count += 1
                    k = f'{MARKER} (key {keys})'
                out[k] = visit(v)
            return out
        return x
    obj = visit(obj)
    if not count:
        return data, 0
    one_line = '\n' not in text.rstrip('\n')
    out = json.dumps(obj, separators=(',', ':')) if one_line else json.dumps(obj, indent=2)
    return (out + ('\n' if text.endswith('\n') else '')).encode('utf-8', 'surrogateescape'), count


def json_strings(obj):
    """Every string of a JSON document, keys included."""
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, list):
        for v in obj:
            yield from json_strings(v)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from json_strings(v)


def load_substitutions(path):
    """Only the three substitution groups; longer alternatives take precedence."""
    groups = {g: [] for g in ('local-paths', 'modal-names', 'addresses')}
    group = None
    with open_list(path) as source:
        for raw in source:
            line = raw.strip()
            if line.startswith('## '):
                group = line[3:].strip()
            elif line and not line.startswith('#') and group in groups:
                groups[group].append(line)
    for group, patterns in groups.items():
        if not patterns:
            sys.exit(f'export: missing pointer substitution group {group}')
    return {g: re.compile('|'.join(f'({p})' for p in sorted(pats, key=len, reverse=True)), re.I)
            for g, pats in groups.items()}


def substitute_pointers(path, data, original, groups):
    """Count record removals or substitute text, retaining byte and newline shapes."""
    text = (original if path.startswith(HISTORY) else data).decode('utf-8', 'surrogateescape')
    counts = {}
    for group, pattern in groups.items():
        if path.startswith(HISTORY):
            counts[group] = sum(1 for _ in pattern.finditer(text))
            continue
        if group == 'local-paths':
            replacement = lambda m: '~' if m.group().split('/')[1].lower() == 'users' else '<lanes-volume>'
        else:
            replacement = '<modal-name>' if group == 'modal-names' else '<address>'
        text, counts[group] = pattern.subn(replacement, text)
    return (data if path.startswith(HISTORY) else text.encode('utf-8', 'surrogateescape')), counts


def write_pointer_manifest(manifest, changes, groups):
    """Occurrences per group and per file, with record removals counted separately."""
    manifest.write(f'\npointer-transformed {len(changes)} files\n')
    for group in groups:
        records = sum(c[group] for p, c in changes if p.startswith(HISTORY))
        substitutions = sum(c[group] for p, c in changes if not p.startswith(HISTORY))
        manifest.write(f'pointer-group {group} {records + substitutions} occurrences; '
                       f'records {records}; substitutions {substitutions}\n')
        print(f'export: pointer group {group}: {records + substitutions} occurrences; '
              f'records {records}; substitutions {substitutions}')
    manifest.write('\n## pointer transforms: occurrences group mode path\n')
    for path, counts in changes:
        mode = 'records' if path.startswith(HISTORY) else 'substitution'
        for group, count in counts.items():
            if count:
                manifest.write(f'{count}  {group}  {mode}  {path}\n')


def matches(glob, path):
    if glob.endswith('/'):
        return path.startswith(glob)
    if '/' in glob:
        return fnmatch.fnmatchcase(path, glob)
    return fnmatch.fnmatchcase(os.path.basename(path), glob)


def group_of(rules, path):
    for group, glob in rules:
        if matches(glob, path):
            return group
    return None


def load_withheld_rules(path=None):
    """Rule policy is separate from metadata's hash-pinned string selections."""
    path = path or os.path.join(ROOT, 'tools', 'export_withheld_rules.txt')
    out, group = {}, None
    for n, raw in enumerate(open_list(path), 1):
        line = raw.rstrip('\n')
        if line.startswith('## '):
            group = line[3:].split(':', 1)[0].strip()
            if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', group):
                sys.exit(f'export: {path}:{n}: invalid rule group')
        elif line.strip() and not line.startswith('#'):
            parts = line.split('\t')
            if (group is None or len(parts) != 2
                    or not re.fullmatch(r'harness/rules/[a-z0-9-]+\.json', parts[0])
                    or not re.fullmatch(r'[a-z0-9][a-z0-9.-]*', parts[1])):
                sys.exit(f'export: {path}:{n}: needs group and rule path<TAB>class id')
            selected = out.setdefault(parts[0], {})
            if parts[1] in selected:
                sys.exit(f'export: {path}:{n}: duplicate rule class')
            selected[parts[1]] = group
    return out


def rule_pointer_groups(policy):
    groups = {g for selected in policy.values() for g in selected.values()}
    out, group = {g: [] for g in groups}, None
    for raw in open_list(POINTERS):
        line = raw.strip()
        if line.startswith('## '):
            group = line[3:]
        elif line and not line.startswith('#') and group in out:
            out[group].append(re.compile(line, re.I))
    if any(not patterns for patterns in out.values()):
        sys.exit('export: every rule group needs a pointer group')
    return out


def rule_entry_counts(entries, policy=None):
    """Witnesses share source spends even when another group covers the source."""
    counts = withheld_entry_counts(entries)
    primary = sorted({i for p, ids in entries.items() if not p.startswith('corpus/witnesses/')
                      for i in ids}, key=len, reverse=True)
    policy = load_withheld_rules() if policy is None else policy
    for group in {g for selected in policy.values() for g in selected.values()}:
        rows = group_rows(entries, group)
        if rows:
            spends = {next((i for i in primary if entry_id == i or entry_id.endswith('-' + i)), entry_id)
                      for _, entry_id, _ in rows}
            counts[group] = len(spends), len({p for p, _, _ in rows})
    return counts


def rule_aliases(entries, pointers):
    """Opaque public IDs preserve witness-to-source joins and expose no private ID."""
    primary = sorted({i for p, ids in entries.items() if not p.startswith('corpus/witnesses/')
                      for i in ids}, key=len, reverse=True)
    aliases = {}
    for ids in entries.values():
        for entry_id in ids:
            if not any(p.search(entry_id) for patterns in pointers.values() for p in patterns):
                continue
            alias = 'withheld-' + hashlib.sha256(entry_id.encode()).hexdigest()[:20]
            source = next((i for i in primary if entry_id.endswith('-' + i)), None) if entry_id not in primary else None
            if source:
                alias += '-withheld-' + hashlib.sha256(source.encode()).hexdigest()[:20]
            aliases[entry_id] = alias
    if len(set(aliases.values())) != len(aliases):
        sys.exit('export: public entry alias collision')
    return aliases


def rule_json(path, data, value):
    """Infer the existing serializer only by a byte-identical empty round trip."""
    original = json.loads(data)
    end = '\n' if data.endswith(b'\n') else ''
    for indent in (1, 2, 4, '\t', None):
        for ascii_only in (False, True):
            for separators in (None, (',', ':')):
                options = dict(indent=indent, ensure_ascii=ascii_only, separators=separators)
                if (json.dumps(original, **options) + end).encode() == data:
                    return (json.dumps(value, **options) + end).encode()
    sys.exit(f'export: {path}: JSON serializer has no byte-identical round trip')


def rule_row_class(row):
    """Return a fixed class ID; class_from needs an entry's rule, so its row stays intact."""
    return None if row.get('class_from') is not None else row['class']


def withhold_rule_data(path, data, selected):
    """Drop selected definitions and fixed-class rows, retaining derived rows and order."""
    table = json.loads(data)
    if not isinstance(table.get('classes'), dict) or not isinstance(table.get('rows'), list):
        sys.exit(f'export: {path}: invalid rule table')
    if set(selected) - set(table['classes']):
        sys.exit(f'export: {path}: named rule class missing')
    before = len(table['rows'])
    table['classes'] = {k: v for k, v in table['classes'].items() if k not in selected}
    table['rows'] = [row for row in table['rows'] if rule_row_class(row) not in selected]
    return rule_json(path, data, table), len(selected), before - len(table['rows'])


def withhold_rule_references(value, plan):
    """Drop manifest class records and mask matching JSON strings, without excerpts.

    An object key that is a withheld entry's private ID (a per-entry map, as the clean-room outputs
    `harness/cleanroom/out/<corpus>.json` key their rows) becomes the entry's opaque public alias, the
    same one the exported corpus row carries, so the join survives (#107); each such key counts as a field.
    """
    fields, rows = 0, 0
    aliases = plan.get('aliases', {})
    def key(k):
        nonlocal fields
        if k in aliases:
            fields += 1
            return aliases[k]
        return k
    def visit(obj):
        nonlocal fields, rows
        if isinstance(obj, list):
            out = []
            for item in obj:
                if isinstance(item, dict) and any(isinstance(item.get(k), str) and item[k] in plan['classes']
                                                 for k in ('rule', 'class')):
                    rows += 1
                else:
                    out.append(visit(item))
            return out
        if isinstance(obj, dict):
            out = {key(k): visit(v) for k, v in obj.items()}
            if len(out) != len(obj):
                sys.exit('export: a public entry alias collides with an object key')
            return out
        if isinstance(obj, str):
            for group, patterns in plan['pointers'].items():
                if any(p.search(obj) for p in patterns):
                    fields += 1
                    return entry_marker(group)
        return obj
    return visit(value), fields, rows


def prepare_rule_exports(entries, overrides, blobs, withheld):
    """Prepare rules, ID aliases and final corpus hashes before the export loop."""
    policy = load_withheld_rules()
    plan = dict(policy=policy, pointers=rule_pointer_groups(policy), tables={}, classes={},
                references={}, reports={}, history={})
    plan['aliases'] = rule_aliases(entries, plan['pointers'])
    plan['spans'] = json.load(open_list(os.path.join(ROOT, 'tools', 'export_withheld_history.json')))
    def read(path):
        meta = blobs.get(path)
        if (meta is None or meta[0] not in ('100644', '100755') or meta[1] != 'blob'
                or group_of(withheld, path) is not None):
            sys.exit(f'export: rule policy needs an exported regular file: {path}')
        return git('cat-file', 'blob', meta[2])
    for path, selected in policy.items():
        private = read(path)
        original = json.loads(private)
        public, classes, rows = withhold_rule_data(path, private, selected)
        overrides[path] = public
        plan['tables'][original['engine']] = dict(path=path, classes=classes, rows=rows,
            public_classes=len(original['classes']) - classes, public_rows=len(original['rows']) - rows,
            groups={g: (sum(v == g for v in selected.values()),
                        sum(selected.get(rule_row_class(r)) == g for r in original['rows'])) for g in set(selected.values())})
        for cls, group in selected.items():
            plan['classes'][cls] = dict(group=group, engine=original['engine'], ruling=original['classes'][cls]['ruling'])
    for path, ids in entries.items():
        before, out = overrides[path], []
        fields, rows = 0, 0
        for raw in before.splitlines(keepends=True):
            row = json.loads(raw)
            if row.get('id') in plan['aliases']:
                row['id'] = plan['aliases'][row['id']]
            row, f, r = withhold_rule_references(row, plan)
            fields += f; rows += r
            if row == json.loads(raw):
                out.append(raw)
            else:
                end = b'\r\n' if raw.endswith(b'\r\n') else (b'\n' if raw.endswith(b'\n') else b'')
                out.append(json.dumps(row, separators=(',', ':')).encode() + end)
        public = b''.join(out)
        if fields or rows:
            plan['references'][path] = (fields, rows)
        if public == before:
            continue
        overrides[path] = public
        mp = os.path.join(os.path.dirname(path), 'manifest.json')
        manifest = json.loads(overrides[mp])
        descriptors = [manifest] if 'file' in manifest else [v for v in manifest.values() if isinstance(v, dict)]
        found = [d for d in descriptors if d.get('file') == os.path.basename(path)]
        if len(found) != 1 or found[0]['sha256'] != hashlib.sha256(before).hexdigest():
            sys.exit(f'export: {mp}: entry alias hash does not match descriptor')
        found[0]['sha256'] = hashlib.sha256(public).hexdigest()
        overrides[mp] = rule_json(mp, overrides[mp], manifest)
    public_list = []
    for raw in read('tools/export_withheld_entries.txt').decode().splitlines(keepends=True):
        parts = raw.rstrip('\n').split('\t')
        if len(parts) in (2, 3) and not raw.startswith('#'):
            parts[1] = plan['aliases'].get(parts[1], parts[1])
            raw = '\t'.join(parts) + ('\n' if raw.endswith('\n') else '')
        public_list.append(raw)
    overrides['tools/export_withheld_entries.txt'] = ''.join(public_list).encode()
    for path, span in plan['spans'].items():
        private = read(path)
        if span['group'] not in plan['pointers'] or hashlib.sha256(private).hexdigest() != span['sha256']:
            sys.exit(f'export: {path}: history span group or sha256 changed')
        if any(a < 1 or b < a or b > len(private.splitlines()) for a, b in span['lines']):
            sys.exit(f'export: {path}: invalid history span')
    return plan


def withhold_rule_report(path, data, plan):
    """Filter generated class rows and recount current runs, rows and distinct kinds."""
    lines = data.decode().splitlines(keepends=True)
    removed, run_counts, kinds = {}, {}, {}
    out = []
    for line in lines:
        cells = line.split('|')
        cls = cells[1].strip().strip('`') if len(cells) > 2 else ''
        if cls in plan['classes']:
            engine = plan['classes'][cls]['engine']
            removed[engine] = removed.get(engine, 0) + 1
            kinds.setdefault(engine, {}).setdefault(cells[2].strip(), set()).add(cls)
            corpus, column = re.findall(r'`([^`]+)`', cells[4])
            key = engine, corpus, column
            run_counts[key] = run_counts.get(key, 0) + int(cells[5].strip())
        else:
            out.append(line)
    if not removed:
        return data
    section, engine, final = '', '', []
    for line in out:
        if line.startswith('## '):
            section = line.split('.')[0]
        if section == '## 1' and line.startswith('### '):
            engine = line[4:].strip()
        cells = line.split('|')
        if section == '## 1' and len(cells) == 12 and engine in removed:
            corpus = cells[1].strip().strip('`').removeprefix('corpus/')
            column = cells[5].strip().strip('`')
            delta = run_counts.get((engine, corpus, column), 0)
            if delta:
                count = int(cells[7].strip()) - delta
                if count < 0:
                    sys.exit(f'export: {path}: negative classified count')
                cells[7] = f' {count} '
                line = '|'.join(cells)
        for eng, count in removed.items():
            match = re.fullmatch(r'### ' + re.escape(eng) + r' \((\d+) class rows\)\n', line)
            if match:
                table = plan['tables'][eng]
                line = f'### {eng} ({int(match[1]) - count} class rows)\n'
                line += (f"\nExported `{table['path']}`: [M] {table['public_classes']} class definitions, "
                         f"[M] {table['public_rows']} classifier rows; [M] {table['classes']} class definitions and "
                         f"[M] {table['rows']} classifier rows withheld by the rule policy.\n")
            if section == '## 3' and len(cells) == 7 and cells[1].strip() == eng:
                for i, kind in enumerate(('IMPLEMENTATION-WRONG', 'SPEC-SIDE', 'OPEN', 'MECHANISM'), 2):
                    count_kind = int(cells[i].strip()) - len(kinds.get(eng, {}).get(kind, ()))
                    if count_kind < 0:
                        sys.exit(f'export: {path}: negative distinct class count')
                    cells[i] = f' {count_kind} '
                line = '|'.join(cells)
        final.append(line)
    plan['reports'][path] = removed
    return ''.join(final).encode()


def withhold_rule_artifact(path, data, plan):
    """Declared #102 transform: references in JSON and public pages, export copy only."""
    if path.startswith(HISTORY) or not is_text(path, data):
        return data
    if re.fullmatch(r'docs/CONFORMANCE-[^/]+\.md', path):
        data = withhold_rule_report(path, data, plan)
    if path.endswith('.json'):
        if not any(p.search(data.decode('utf-8')) for patterns in plan['pointers'].values() for p in patterns):
            return data
        obj, fields, rows = withhold_rule_references(json.loads(data), plan)
        if fields or rows:
            plan['references'][path] = (fields, rows)
            return rule_json(path, data, obj)
    elif path.endswith('.md'):
        lines, count = [], 0
        for line in data.decode().splitlines(keepends=True):
            if not re.fullmatch(r'docs/CONFORMANCE-[^/]+\.md', path) and any(
                    p.search(line) for patterns in plan['pointers'].values() for p in patterns):
                lines.append(MARKER + ('\n' if line.endswith('\n') else ''))
                count += 1
                continue
            for group, patterns in plan['pointers'].items():
                for pattern in patterns:
                    line, n = pattern.subn(entry_marker(group), line)
                    count += n
            lines.append(line)
        if count:
            plan['references'][path] = (count, 0)
            return ''.join(lines).encode()
    return data


def withhold_rule_history(path, data, pointers, plan):
    """Hash-pinned spans feed the existing records transform, including wrapped lines."""
    if path.endswith('.json'):
        try:
            obj = json.loads(data.decode('utf-8', 'surrogateescape'))
        except ValueError:
            obj = None
        if obj is not None:
            per = {}
            for s in json_strings(obj):
                for group, patterns in plan['pointers'].items():
                    if any(p.search(s) for p in patterns):
                        per[group] = per.get(group, 0) + 1
            if per:
                plan['history'][path] = per
            return transform_json(data, pointers)
    lines = data.decode('utf-8', 'surrogateescape').splitlines(keepends=True)
    span = plan['spans'].get(path)
    marked = {n for a, b in span['lines'] for n in range(a, b + 1)} if span else set()
    per = {}
    for n, line in enumerate(lines, 1):
        for group, patterns in plan['pointers'].items():
            if any(p.search(line) for p in patterns) or (span and span['group'] == group and n in marked):
                per[group] = per.get(group, 0) + 1
                if n in marked:
                    cls = next(c for c, info in plan['classes'].items() if info['group'] == group)
                    end = '\r\n' if line.endswith('\r\n') else ('\n' if line.endswith('\n') else '')
                    lines[n - 1] = cls + end
    if per:
        plan['history'][path] = per
    return transform(''.join(lines).encode('utf-8', 'surrogateescape'), pointers)


def write_rule_manifest(stream, plan):
    """Identifier-free rule, report, reference and per-group history counts."""
    stream.write('withheld-rule-list tools/export_withheld_rules.txt\n')
    for engine, table in plan['tables'].items():
        for group, (classes, rows) in table['groups'].items():
            stream.write(f'withheld-rule-group {group} {classes} classes {rows} rows ({table["path"]})\n')
            history = sum(counts.get(group, 0) for counts in plan['history'].values())
            files = sum(group in counts for counts in plan['history'].values())
            stream.write(f'withheld-history-group {group} {history} lines in {files} files\n')
    for path, removed in plan['reports'].items():
        stream.write(f'withheld-report-rows {sum(removed.values())} {path}\n')
    stream.write(f'withheld-rule-references {sum(f for f, _ in plan["references"].values())} fields '
                 f'{sum(r for _, r in plan["references"].values())} records in {len(plan["references"])} files\n')
    for path, (fields, records) in sorted(plan['references'].items()):
        stream.write(f'withheld-rule-reference {fields} fields {records} records {path}\n')


def cargo_header(line):
    """The table a TOML header line opens (`bin` for `[[bin]]`), or None."""
    m = re.match(r'\s*\[\[?\s*([^\]\s]+)\s*\]\]?\s*(#.*)?$', line)
    return m.group(1) if m else None


def cargo_resolve(manifest, path):
    """A manifest-relative path as a repository path (posix, normalised)."""
    return os.path.normpath(os.path.join(os.path.dirname(manifest), path)).replace(os.sep, '/')


def withhold_cargo_targets(manifest, data, rules):
    """The Cargo transform: (new bytes, [(kind, name)], [(line index, removed lines)]).

    A dropped target's span is its header line through its last key line, the comment lines
    directly above the header and the blank lines below the last key; every other line keeps
    its bytes. The spans are returned so a caller can re-insert them (the test's round trip).
    """
    text = data.decode('utf-8')
    try:
        parsed = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        sys.exit(f'export: {manifest}: the Cargo manifest does not parse ({error})')
    lines = text.splitlines(keepends=True)
    heads = [i for i, line in enumerate(lines) if cargo_header(line) is not None]
    drop, dropped, spans = set(), [], []
    for kind in CARGO_TARGETS:
        tables = parsed.get(kind, [])
        at = [i for i in heads if re.match(r'\s*\[\[\s*' + kind + r'\s*\]\]', lines[i])]
        if len(at) != len(tables):
            sys.exit(f'export: {manifest}: {len(tables)} [[{kind}]] tables but {len(at)} header lines')
        for table, start in zip(tables, at):
            if 'path' not in table or group_of(rules, cargo_resolve(manifest, table['path'])) is None:
                continue
            nxt = next((i for i in heads if i > start), len(lines))
            end = start
            for i in range(start + 1, nxt):
                if lines[i].strip() and not lines[i].lstrip().startswith('#'):
                    end = i
            while end + 1 < nxt and not lines[end + 1].strip():
                end += 1
            while start > 0 and lines[start - 1].lstrip().startswith('#') and start - 1 not in drop:
                start -= 1
            drop.update(range(start, end + 1))
            dropped.append((kind, table.get('name', '?')))
    if not dropped:
        return data, [], []
    kept = []
    for i, line in enumerate(lines):
        if i in drop:
            if not spans or spans[-1][0] + len(spans[-1][1]) != i:
                spans.append((i, []))
            spans[-1][1].append(line)
        else:
            kept.append(line)
    n = len(dropped)
    head = (f'# [export: {n} target table{"s" if n != 1 else ""} withheld by tools/export_public.py, '
            'its source on the withheld list; the original is in the private history]\n')
    return (head + ''.join(kept)).encode('utf-8'), dropped, spans


def cargo_named_withheld(manifest, data, rules):
    """Every withheld path the manifest still names: target and lib paths, the build script, any `*.rs` token."""
    parsed = tomllib.loads(data.decode('utf-8'))
    named = [t.get('path') for kind in CARGO_TARGETS for t in parsed.get(kind, [])]
    named += [parsed.get('lib', {}).get('path'), parsed.get('package', {}).get('build')]
    named += re.findall(r'[\w./-]+\.rs\b', data.decode('utf-8'))
    resolved = {cargo_resolve(manifest, p) for p in named if isinstance(p, str)}
    return sorted(p for p in resolved if group_of(rules, p) is not None)


SOURCE_REF = re.compile(r'^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+(?:r#)?(\w+)\s*;'
                        r'|#\[\s*path\s*=\s*"([^"]+)"'
                        r'|\binclude(?:_str|_bytes)?!\s*\(\s*"([^"]+)"')


def source_candidates(rel, ref):
    """The paths a `mod`, `#[path]` or `include*!` line in `rel` may load; both module directories are tried."""
    here = os.path.dirname(rel)
    stem = os.path.join(here, os.path.splitext(os.path.basename(rel))[0])
    mod, path, include = ref
    if mod:
        return [os.path.normpath(os.path.join(d, f)) for d in (here, stem) for f in (mod + '.rs', mod + '/mod.rs')]
    if path:
        return [os.path.normpath(os.path.join(d, path)) for d in (here, stem)]
    return [os.path.normpath(os.path.join(here, include))]


def withheld_source_refs(target, sources, rules, withheld):
    """(lines searched, lines naming a withheld basename, [(file, line)] resolving to a withheld path)."""
    basenames = {os.path.basename(p) for p in withheld} | {os.path.splitext(os.path.basename(p))[0] for p in withheld}
    searched, named, hits = 0, 0, []
    for rel in sources:
        for n, line in enumerate(open(os.path.join(target, rel), encoding='utf-8', errors='replace'), 1):
            for m in SOURCE_REF.finditer(line):
                searched += 1
                ref = m.groups()
                name = os.path.basename(next(g for g in ref if g))
                if name not in basenames and os.path.splitext(name)[0] not in basenames:
                    continue
                named += 1
                if any(group_of(rules, c.replace(os.sep, '/')) is not None for c in source_candidates(rel, ref)):
                    hits.append((rel, n))
    return searched, named, hits


def cargo_transform(target, rules, withheld, exported):
    """Walk the export for every Cargo.toml, drop withheld targets, then the two stops. Updates `exported`."""
    manifests, sources, changes = [], [], []
    for dirpath, dirnames, filenames in os.walk(target):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if name == 'Cargo.toml' and not os.path.islink(full):
                manifests.append(os.path.relpath(full, target).replace(os.sep, '/'))
    for manifest in manifests:
        full = os.path.join(target, manifest)
        data = open(full, 'rb').read()
        public, dropped, _ = withhold_cargo_targets(manifest, data, rules)
        if dropped:
            with open(full, 'wb') as f:
                f.write(public)
            changes.append((manifest, dropped))
            i = next(i for i, (p, _) in enumerate(exported) if p == manifest)
            exported[i] = (manifest, hashlib.sha256(public).hexdigest())
        still = cargo_named_withheld(manifest, public, rules)
        if still:
            sys.exit(f'export: STOP: the exported {manifest} still names {len(still)} withheld path(s): {", ".join(still)}; '
                     'the public tree would not build')
        package = os.path.dirname(manifest)
        for dirpath, dirnames, filenames in os.walk(os.path.join(target, package)):
            dirnames.sort()
            for name in sorted(filenames):
                if name.endswith('.rs') and not os.path.islink(os.path.join(dirpath, name)):
                    sources.append(os.path.relpath(os.path.join(dirpath, name), target).replace(os.sep, '/'))
    searched, named, hits = withheld_source_refs(target, sources, rules, withheld)
    print(f'export: cargo transform: {len(manifests)} Cargo manifests, {sum(len(d) for _, d in changes)} target tables dropped'
          + ''.join(f'; {m}: {", ".join(f"{k} {n}" for k, n in d)}' for m, d in changes))
    print(f'export: source check: {len(sources)} .rs files of the Cargo packages; {searched} mod, #[path] and include lines; '
          f'{named} name a withheld basename; {len(hits)} resolve to a withheld path')
    if hits:
        sys.exit('export: STOP: an exported source loads a withheld path: '
                 + ', '.join(f'{p}:{n}' for p, n in hits) + '; the public tree would not build')
    return changes, (len(sources), searched, named)


MAKE_RULE = re.compile(r'^([^\s#:=.][^:=]*?)\s*::?(?!=)')
MAKEFILES = ('Makefile', 'GNUmakefile', 'makefile')


def make_bin_pattern(bins):
    """A recipe's use of a dropped binary: `--bin <name>`, a `release/` or `debug/` path to it, or its `src/bin/` source."""
    names = '|'.join(re.escape(b) for b in sorted(bins, key=len, reverse=True))
    return re.compile(r'(?:--bin[ =]|/(?:release|debug)/|src/bin/)(?:' + names + r')(?![\w-])')


def withhold_make_targets(path, data, bins):
    """The Makefile transform: (new bytes, [target names], [(line index, removed lines)], {line index: original}).

    A target is dropped when its rule line or a recipe line names a dropped binary; its span is the comment
    lines directly above the rule line, the rule line, its recipe (tab lines and backslash continuations) and
    the blank lines below. The dropped names leave each `.PHONY:` line (the one other edit, returned so a
    caller can restore it); every other line keeps its bytes.
    """
    if not bins:
        return data, [], [], {}
    pat = make_bin_pattern(bins)
    lines = data.decode('utf-8').splitlines(keepends=True)
    drop, targets = set(), []
    i = 0
    while i < len(lines):
        m = None if lines[i].startswith('\t') else MAKE_RULE.match(lines[i])
        if not m:
            i += 1
            continue
        end = i
        while end + 1 < len(lines) and (lines[end + 1].startswith('\t') or lines[end].rstrip('\r\n').endswith('\\')):
            end += 1
        if any(pat.search(lines[k]) for k in range(i, end + 1)):
            start = i
            while start > 0 and lines[start - 1].startswith('#') and start - 1 not in drop:
                start -= 1
            while end + 1 < len(lines) and not lines[end + 1].strip():
                end += 1
            drop.update(range(start, end + 1))
            targets.extend(m.group(1).split())
        i = end + 1
    if not targets:
        return data, [], [], {}
    kept, spans, phony = [], [], {}
    for i, line in enumerate(lines):
        if i in drop:
            if not spans or spans[-1][0] + len(spans[-1][1]) != i:
                spans.append((i, []))
            spans[-1][1].append(line)
            continue
        if line.startswith('.PHONY:'):
            body = line[len('.PHONY:'):]
            end = body[len(body.rstrip('\r\n')):]
            words = [w for w in body.split() if w not in targets]
            new = '.PHONY:' + ''.join(' ' + w for w in words) + end
            if new != line:
                phony[len(kept)] = line
                line = new
        kept.append(line)
    n = len(targets)
    head = (f'# [export: {n} target{"s" if n != 1 else ""} withheld by tools/export_public.py, its recipe runs a '
            'binary the Cargo transform dropped; the original is in the private history]\n')
    return (head + ''.join(kept)).encode('utf-8'), targets, spans, phony


def make_still_names(data, bins, targets):
    """The lines of an exported Makefile that still name a dropped binary or a dropped target as a prerequisite."""
    if not bins:
        return []
    pat, out = make_bin_pattern(bins), []
    for n, line in enumerate(data.decode('utf-8').splitlines(), 1):
        m = None if line.startswith('\t') or line.startswith('.PHONY:') else MAKE_RULE.match(line)
        prereqs = line[m.end():].split(';')[0].split() if m else []
        if pat.search(line) or any(t in prereqs for t in targets):
            out.append(n)
    return out


def make_transform(target, cargo_changes, exported):
    """Walk the export for every Makefile; drop the targets that run a dropped binary, then the stop. Updates `exported`."""
    bins = sorted({name for _, dropped in cargo_changes for kind, name in dropped if kind == 'bin'})
    found, changes = [], []
    for dirpath, dirnames, filenames in os.walk(target):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if (name in MAKEFILES or name.endswith('.mk')) and not os.path.islink(full):
                found.append(os.path.relpath(full, target).replace(os.sep, '/'))
    for path in found:
        full = os.path.join(target, path)
        data = open(full, 'rb').read()
        public, targets, _, _ = withhold_make_targets(path, data, bins)
        if targets:
            with open(full, 'wb') as f:
                f.write(public)
            changes.append((path, targets))
            i = next(i for i, (p, _) in enumerate(exported) if p == path)
            exported[i] = (path, hashlib.sha256(public).hexdigest())
        still = make_still_names(public, bins, targets)
        if still:
            sys.exit(f'export: STOP: the exported {path} still names a dropped binary or target at line(s) '
                     f'{", ".join(map(str, still))}; a stranger\'s make would fail')
    print(f'export: Makefile transform: {len(found)} Makefiles, {sum(len(t) for _, t in changes)} targets dropped'
          f' (dropped binaries: {", ".join(bins) or "none"})'
          + ''.join(f'; {p}: {", ".join(t)}' for p, t in changes))
    return changes, len(found)


def regenerate_records_index(target, exported):
    """The export's own records index. The transform changes what a record says (a withheld line can be
    the one that names a commit; a JSON record's matched strings become the marker), so the index the
    private tree carries is not the index of the exported records (the hosted gate of 2026-10-26, the
    seed leg). Rendered by the exported tool over the exported tree; the manifest's digest follows."""
    tool, index = os.path.join(target, 'tools', 'records_index.py'), 'docs/records/INDEX.md'
    if not os.path.isfile(tool) or not os.path.isfile(os.path.join(target, index)):
        return 'not rendered (the tool or the index is not exported)'
    got = subprocess.run([sys.executable, tool], capture_output=True, text=True, cwd=target)
    if got.returncode != 0:
        sys.exit(f'export: the records index over the export failed: {(got.stdout + got.stderr).strip()[-300:]}')
    with open(os.path.join(target, index), 'rb') as f:
        digest = hashlib.sha256(f.read()).hexdigest()
    exported[:] = [(p, digest if p == index else d) for p, d in exported]
    return got.stdout.strip()


def move_public_pages(target, exported, pointer_changes):
    """Move each exported page of PUBLIC_PAGES over its private namesake (#169); [(public, private, sha256)]."""
    moves = []
    for public, private in PUBLIC_PAGES.items():
        digest = dict(exported).get(public)
        if digest is None:
            continue
        os.replace(os.path.join(target, public), os.path.join(target, private))
        if private not in dict(exported):
            exported.append((private, digest))
        exported[:] = [(p, digest if p == private else d) for p, d in exported if p != public]
        pointer_changes[:] = [(private if p == public else p, c) for p, c in pointer_changes if p != private]
        moves.append((public, private, digest))
    return moves


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    target = os.path.abspath(sys.argv[1])
    commit = git('rev-parse', '--verify', (sys.argv[2] if len(sys.argv) == 3 else 'HEAD') + '^{commit}').decode().strip()
    global LIST_COMMIT
    LIST_COMMIT = commit
    drift = list_drift(commit)
    print(f'export: lists read at {commit[:12]}; ' + (
        f'WARNING: the working tree differs for {len(drift)}: {", ".join(drift)}' if drift
        else f'the working tree matches for all {len(LISTS)}'))
    if os.path.exists(target) and os.listdir(target):
        sys.exit(f'export: target {target} is not empty')
    os.makedirs(target, exist_ok=True)
    rules = load_withheld(WITHHELD)
    rewrites = load_rewrites(REWRITE)
    pointers = load_pointers(POINTERS)
    substitutions, pointer_changes = load_substitutions(POINTERS), []
    groups = list(dict.fromkeys(g for g, _ in rules))
    entries = load_withheld_entries(ENTRIES)
    entry_counts = rule_entry_counts(entries)
    metadata = json.load(open_list(METADATA))

    tree = []
    for entry in git('ls-tree', '-r', '-z', '--full-tree', commit).split(b'\0'):
        if not entry:
            continue
        meta, path = entry.split(b'\t', 1)
        mode, kind, sha = meta.decode().split()
        path = path.decode('utf-8', 'surrogateescape')
        tree.append((mode, kind, sha, path))
    overrides = entry_exports(entries, {p: (m, k, s) for m, k, s, p in tree}, rules)
    rule_plan = prepare_rule_exports(entries, overrides, {p: (m, k, s) for m, k, s, p in tree}, rules)

    exported, withheld, skipped, rewritten, transformed = [], [], [], [], []
    for mode, kind, sha, path in tree:
        g = group_of(rules, path)
        if g is not None:
            withheld.append((path, g))
            continue
        if kind != 'blob':
            skipped.append((path, kind))
            continue
        data = overrides[path] if path in overrides else git('cat-file', 'blob', sha)
        if path in metadata:
            data = withhold_metadata(path, data, metadata[path])
        original = data
        data = withhold_rule_artifact(path, data, rule_plan)
        if mode != '120000' and path in rewrites:
            data = rewrite(path, data, rewrites[path]); rewritten.append((path, len(rewrites[path])))
        elif mode != '120000' and path.startswith(HISTORY) and is_text(path, data):
            data, c = withhold_rule_history(path, data, pointers, rule_plan)
            if c:
                transformed.append((path, c))
        if mode != '120000' and is_text(path, data):
            data, by_group = substitute_pointers(path, data, original, substitutions)
            if any(by_group.values()):
                pointer_changes.append((path, by_group))
        dest = os.path.join(target, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if mode == '120000':
            os.symlink(data.decode('utf-8', 'surrogateescape'), dest)
        else:
            with open(dest, 'wb') as f:
                f.write(data)
            if mode == '100755':
                os.chmod(dest, 0o755)
        exported.append((path, hashlib.sha256(data).hexdigest()))

    moves = move_public_pages(target, exported, pointer_changes)
    cargo_changes, source_counts = cargo_transform(target, rules, [p for p, _ in withheld], exported)
    make_changes, makefiles = make_transform(target, cargo_changes, exported)
    index_note = regenerate_records_index(target, exported)
    print(f'export: records index over the export: {index_note}')

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    counts = {g: sum(1 for _, wg in withheld if wg == g) for g in groups}
    missing = sorted((set(rewrites) - {p for p, _ in rewritten}) | (set(metadata) - {p for p, _ in exported}))
    if missing:
        sys.exit(f'export: tools/export_rewrite.txt names paths not exported: {", ".join(missing)}')
    replaced = sum(c for _, c in transformed)
    with open(os.path.join(target, MANIFEST), 'w', encoding='utf-8') as m:
        m.write('# The public edition of bsv-script-lean: export manifest (tools/export_public.py)\n')
        m.write(f'source-commit {commit}\n')
        m.write(f'exported-at {stamp}\n')
        m.write(f'withheld-list tools/export_withheld.txt @ {commit[:12]}\n')
        m.write(f'withheld-entry-list tools/export_withheld_entries.txt @ {commit[:12]}\n')
        m.write(f'paths-exported {len(exported)}\n')
        m.write(f'paths-withheld {len(withheld)}\n')
        for g in groups:
            m.write(f'withheld-group {g} {counts[g]}\n')
        for g, (n, k) in entry_counts.items():
            rows = len(group_rows(entries, g))
            m.write(f'withheld-entry-group {g} {n} entries in {k} files ({rows} rows including witness copies)\n')
        m.write(f'withheld-metadata {sum(map(len, metadata.values()))} fields in {len(metadata)} files\n')
        write_rule_manifest(m, rule_plan)
        m.write(f'rewritten {len(rewritten)} (tools/export_rewrite.txt)\n')
        m.write(f'transformed {len(transformed)} lines-replaced {replaced} (the records transform)\n')
        m.write(f'cargo-transformed {len(cargo_changes)} files, {sum(len(d) for _, d in cargo_changes)} target tables '
                'dropped (the Cargo transform)\n')
        m.write(f'cargo-source-check {source_counts[0]} .rs files, {source_counts[1]} mod/#[path]/include lines, '
                f'{source_counts[2]} naming a withheld basename, 0 resolving to a withheld path\n')
        m.write(f'makefile-transformed {len(make_changes)} of {makefiles} Makefiles, '
                f'{sum(len(t) for _, t in make_changes)} targets dropped (the Makefile transform)\n')
        m.write(f'public-pages-moved {len(moves)} (PUBLIC_PAGES)\n')
        m.write(f'records-index rendered over the export: {index_note}\n')
        m.write(f'lists-read-at {commit[:12]} ({len(LISTS)} lists; working tree differs: {", ".join(drift) or "none"})\n')
        m.write('\n## exported: sha256 path\n')
        for path, digest in exported:
            m.write(f'{digest}  {path}\n')
        m.write('\n## withheld: group path (by name only)\n')
        for path, g in withheld:
            m.write(f'{g}  {path}\n')
        for g in entry_counts:
            m.write(f'\n## withheld entries: {g} (path<TAB>id<TAB>fields)\n')
            for path, entry_id, fields in group_rows(entries, g):
                m.write(f'{path}\t{rule_plan["aliases"].get(entry_id, entry_id)}\t{",".join(fields)}\n')
        for path, kind in skipped:
            m.write(f'not-a-blob ({kind})  {path}\n')
        m.write('\n## rewritten: blocks path (tools/export_rewrite.txt)\n')
        for path, c in rewritten:
            m.write(f'{c}  {path}\n')
        m.write("\n## transformed: lines-replaced path (the records transform, a sibling tree's lines)\n")
        for path, c in transformed:
            m.write(f'{c}  {path}\n')
        m.write('\n## cargo-transformed: targets-dropped path (kind name, ...) (the Cargo transform)\n')
        for path, dropped in cargo_changes:
            m.write(f'{len(dropped)}  {path}  ' + ', '.join(f'{k} {n}' for k, n in dropped) + '\n')
        m.write('\n## makefile-transformed: targets-dropped path (target, ...) (the Makefile transform)\n')
        for path, targets in make_changes:
            m.write(f'{len(targets)}  {path}  ' + ', '.join(targets) + '\n')
        m.write('\n## public pages moved: public-path -> exported-as sha256\n')
        for public, private, digest in moves:
            m.write(f'{public} -> {private} {digest}\n')
        write_pointer_manifest(m, pointer_changes, substitutions)

    print(f'export: {commit[:12]} -> {target}')
    print(f'export: {len(exported)} paths exported, {len(withheld)} withheld, {len(skipped)} not blobs')
    for g in groups:
        print(f'  withheld [{g}] {counts[g]}')
        for path, wg in withheld:
            if wg == g:
                print(f'    {path}')
    for path, kind in skipped:
        print(f'  not exported ({kind}): {path}')
    for g, (n, k) in entry_counts.items():
        print(f'export: withheld entries {n} in {k} files, group {g}')
    for path, c in rewritten:
        print(f'export: rewritten {path} ({c} blocks of tools/export_rewrite.txt)')
    for public, private, _ in moves:
        print(f'export: moved {public} over {private} (the exported copy only)')
    print(f'export: records transform: {len(transformed)} files, {replaced} lines replaced by the marker')
    print(f'export: manifest {os.path.join(target, MANIFEST)}')


if __name__ == '__main__':
    main()
