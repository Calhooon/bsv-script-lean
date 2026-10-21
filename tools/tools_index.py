#!/usr/bin/env python3
"""tools/tools_index.py: the index page of tools/ (#173), tools/README.md, generated.

One table row per file under tools/ that the public edition carries (the files tools/export_withheld.txt does not
withhold, matched by tools/export_public.py's own matcher): the path, what it does (one line, kept below in DESC, so
a new file without a line stops the run), who calls it (read from the Makefile's recipes, tools/check.sh's legs, the
other scripts of tools/ and .github/, and the public pages, in that order), and its class.

Usage: tools/tools_index.py            prints the page
       tools/tools_index.py --check    exit 1 when tools/README.md differs from the page (or a file has no line)
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import export_public  # noqa: E402  (the export's withheld list and its matcher, never a second copy)

PAGE = 'tools/README.md'
CLASSES = ('gate', 'generator', 'measurement', "maintainers' route", 'test')

# path: (what it does, class). One line each, opening with a verb.
DESC = {
    'tools/README.md': ('Lists every public file of tools/ (this page; written by tools/tools_index.py)', 'generator'),
    'tools/axiom_check.py': ('Runs the axiom check on the theorems of lean/AxiomCheck.lean and refuses any axiom beyond the three of Lean\'s core', 'gate'),
    'tools/bench_baseline.json': ('Holds the bench leg\'s baseline walls, each with the record it was read from', 'gate'),
    'tools/bench_leg.sh': ('Holds the replay and export walls to a regression bar and runs a bounded fuzz smoke of the seed generator', 'gate'),
    'tools/block_cases.py': ('Derives the block boundary rows (#63) from the pinned reference source, without Lean or a node', 'generator'),
    'tools/block_check.sh': ('Checks the measured public headers and the derived block boundaries (#63)', 'gate'),
    'tools/block_headers.py': ('Selects the header ranges of #63 from publicly read block archives', 'generator'),
    'tools/box_status.sh': ('Posts the build machine\'s verdict on the legs a hosted runner cannot run as a commit status', "maintainers' route"),
    'tools/cargo_deny.sh': ('Runs cargo-deny at its pin on the harness crate (advisories, licenses, bans, sources)', 'gate'),
    'tools/chain_check.sh': ('Checks the source-derived chain transition column (#64)', 'gate'),
    'tools/chain_leg.sh': ('Runs the chain leg: the scenario projection, the status fixtures and the chain family executables', 'gate'),
    'tools/chain_lint.py': ('Lints the BsvChain library for purity and explicit time inputs (#77)', 'gate'),
    'tools/check.sh': ('Runs the tripwire: every leg of `make check` in order, and writes its record under docs/records/', 'gate'),
    'tools/check_box.sh': ('Runs the tripwire on the build machine for a pushed commit and brings its record home', "maintainers' route"),
    'tools/check_parameters.py': ('Compares the node configuration census with Lean and enforces the library import direction (#59)', 'gate'),
    'tools/check_pins.py': ('Checks that every pin of docs/PROVENANCE.md section 1a agrees with every site that names it (#40)', 'gate'),
    'tools/check_route.sh': ('Routes `make check` to a local run, the build machine or a container by load and by MAKE_CHECK', "maintainers' route"),
    'tools/check_signer.sh': ('Runs the signer column on demand, once per signer pin move (#145)', 'measurement'),
    'tools/cite_check.py': ('Checks that every file:line citation of lean/ and docs/ still holds at its pinned source (#43)', 'gate'),
    'tools/column.py': ('Measures one implementation\'s column on one release and writes its record (#124)', 'measurement'),
    'tools/column.sh': ('Runs `make column`: one implementation\'s column on one release in one command (#124)', 'measurement'),
    'tools/conformance.py': ('Writes the conformance report from what the harness records (#30)', 'generator'),
    'tools/cpp_era_chain.py': ('Builds the reference unit-test fixture chain so its validation rows run at their own era (#49)', 'measurement'),
    'tools/cpp_era_run.sh': ('Runs the four differentials on the validation-cache rows at the test\'s own era (#49)', 'measurement'),
    'tools/cpp_extract.sh': ('Extracts the pinned reference\'s C++ unit tables into corpus/cpp through an instrumented test binary (#49)', 'generator'),
    'tools/cpp_replay.py': ('Projects corpus/cpp entries into spends and judges their replays (#49)', 'measurement'),
    'tools/cpp_replay_run.sh': ('Runs the four differentials on one projected corpus/cpp file (#49)', 'measurement'),
    'tools/discretion_overlap.py': ('Tests which citation rows overlap the lines a held disclosure covers (#43)', 'gate'),
    'tools/export_gate.py': ('Checks an export: the mechanism, pointer and wording legs, and with --build the cold offline build (#46, #107)', 'gate'),
    'tools/export_gate.sh': ('Runs the export gate on an export target (#46)', 'gate'),
    'tools/export_public.py': ('Writes the public edition of a commit into an empty directory with its manifest (#46)', 'generator'),
    'tools/export_public.sh': ('Runs the export of a named commit under the export directory (#46)', 'generator'),
    'tools/export_withheld.txt': ('Lists the paths the public edition withholds, by group and ruling (#46)', 'generator'),
    'tools/export_withheld_entries.txt': ('Lists the corpus rows whose named fields the export replaces with a disclosure marker', 'generator'),
    'tools/export_withheld_metadata.json': ('Selects the JSON strings the export replaces with a disclosure marker', 'generator'),
    'tools/finality_cases.py': ('Derives the finality boundary rows (#60) from the pinned reference source', 'generator'),
    'tools/finality_check.sh': ('Checks the source-derived finality column (#60)', 'gate'),
    'tools/fixtures_export.py': ('Renders the corpus as the SDKs\' own fixture files; --check compares a regeneration (#146)', 'generator'),
    'tools/fixtures_proof.py': ('Loads every exported fixture through its SDK and keeps the receipt (#146)', 'test'),
    'tools/fixtures_signer.py': ('Signs the fixture inputs offline for tools/fixtures_export.py (#146)', 'generator'),
    'tools/fuzz_batch.py': ('Reads one fuzz batch\'s outputs and writes its verdict line', 'measurement'),
    'tools/fuzz_campaign.sh': ('Runs the spec against the pinned node on fresh cases, batch after batch (off since #141; kept as history)', 'measurement'),
    'tools/fuzz_compose.py': ('Composes one fuzz batch\'s corpus', 'measurement'),
    'tools/fuzz_daily.sh': ('Prints the fuzz campaign\'s one line per day', "maintainers' route"),
    'tools/gate_leg.sh': ('Runs one job of the hosted gate through the same steps of tools/check.sh (#116)', 'gate'),
    'tools/host_vars.py': ('Resolves the pins block\'s `$NAME` host values from the environment or the maintainers\' host file; unresolved, a gate skips by name and a tool stops; `python3 tools/host_vars.py NAME` prints one for a shell script (#177)', 'gate'),
    'tools/jscpd/.jscpd.json': ('Sets the copy-paste leg\'s threshold, paths and ignore list (#138)', 'gate'),
    'tools/jscpd/package-lock.json': ('Pins the copy-paste detector\'s install (#138)', 'gate'),
    'tools/jscpd/package.json': ('Pins the copy-paste detector\'s version (#138)', 'gate'),
    'tools/jscpd_check.sh': ('Runs the copy-paste leg over harness/ and tools/ (#138)', 'gate'),
    'tools/mainnet_read.py': ('Reads public mainnet transactions as sighash corpus material (a read, never a broadcast)', 'generator'),
    'tools/mechanism_allow.txt': ('Lists the reviewed long hex strings the mechanism check allows, each with its public source', 'gate'),
    'tools/mechanism_check.sh': ('Checks that the sources and the corpus carry nothing of another program (#46)', 'gate'),
    'tools/mechanism_hex.py': ('Checks every long hex string of the corpus against its allowed sources (the mechanism check\'s second leg)', 'gate'),
    'tools/mempool_cases.py': ('Derives the mempool policy witnesses (#62) from the pinned reference source', 'generator'),
    'tools/mempool_check.sh': ('Checks the source-derived mempool policy column (#62)', 'gate'),
    'tools/mini_lock.sh': ('Takes and releases the build machine\'s lock around a long run', "maintainers' route"),
    'tools/modal_check.py': ('Runs the tripwire in a cloud container when MAKE_CHECK=modal and brings its record home', "maintainers' route"),
    'tools/modal_probe_56.py': ('Probes the cloud container\'s image build (#56); a diagnostic, never a verdict', "maintainers' route"),
    'tools/node_bin.sh': ('Prints the path of the node runtime the ts-sdk adapter runs on', 'gate'),
    'tools/node_contract.py': ('Writes the node client contract page from the absence ledger (#140)', 'generator'),
    'tools/node_scenarios.sh': ('Runs the live pinned-node scenario measurements (#66)', 'measurement'),
    'tools/opnames.py': ('Regenerates lean/Test/OpNames.lean from the pinned reference', 'generator'),
    'tools/oracle_cases.py': ('Writes the script oracle\'s inputs from the public script fixtures (#76)', 'generator'),
    'tools/oracle_check.sh': ('Checks the recorded script oracle agreement (#76)', 'gate'),
    'tools/prune_replay.py': ('Replays the Lean pruning function against the node\'s recorded answers (#82)', 'gate'),
    'tools/receipt_trim.py': ('Projects committed scenario receipts to their reference fields', 'generator'),
    'tools/replay_p2sh.py': ('Reads one public mainnet block and lists its P2SH-shaped spends (#26)', 'measurement'),
    'tools/ripemd_tables.py': ('Extracts the RIPEMD-160 word order and rotation tables from the pinned reference', 'generator'),
    'tools/road_variant.py': ('Builds the script families as funded transactions (corpus/road)', 'generator'),
    'tools/rpc_contract.py': ('Generates the RPC observation contract\'s interface and checks it against the probe record (#85)', 'gate'),
    'tools/rpc_probe.py': ('Probes the reference node\'s RPC replies on fresh regtest instances (#85)', 'measurement'),
    'tools/scenario_metadata_check.py': ('Checks scenario provenance and witness shape, never a semantic judgment', 'gate'),
    'tools/scenario_preservation.py': ('Compares node-column inputs with the main branch\'s', 'gate'),
    'tools/scenario_receipt_paths.py': ('Normalizes local instance paths in scenario receipts, every other byte exact', 'generator'),
    'tools/scenario_verdicts.py': ('Byte-compares the per-row verdict sets of independently recorded runs', 'gate'),
    'tools/secrets_allow.txt': ('Lists the secrets scan\'s reviewed exceptions, each with its reason (#135)', 'gate'),
    'tools/secrets_patterns.txt': ('Lists the shapes the secrets scan refuses (#135)', 'gate'),
    'tools/secrets_scan.py': ('Runs the secrets scan\'s Python engine (#135)', 'gate'),
    'tools/secrets_scan.sh': ('Scans staged lines, pushed ranges or the whole tree for secrets (#135)', 'gate'),
    'tools/signer_selfcheck.py': ('Checks the signable corpus with the spec as the judge (#145)', 'test'),
    'tools/soft_freeze_probe.py': ('Measures the reference half of the soft-freeze row on fresh regtest instances (#140)', 'measurement'),
    'tools/specgen.py': ('Generates spec/ from the Lean sources; --check refuses a stale tree (#17)', 'generator'),
    'tools/subtree_vectors.py': ('Writes the subtree merkle vectors of #89', 'generator'),
    'tools/teranode_absences.py': ('Renders and verifies the Teranode absence ledger\'s page (#96)', 'generator'),
    'tools/teranode_gate.py': ('Writes the per-release divergence report of a Teranode release against the reference (#95)', 'measurement'),
    'tools/teranode_gate.sh': ('Runs the live steps of the per-release divergence gate (#95)', 'measurement'),
    'tools/teranode_map.py': ('Renders spec/teranode-map.md from corpus/teranode/map.json and verifies its citations (#87)', 'generator'),
    'tools/test_chain_lint.py': ('Tests the chain purity lint on disposable fixtures (#77)', 'test'),
    'tools/test_check_parameters.py': ('Mutation-tests the parameter census gate (#59)', 'test'),
    'tools/test_column.py': ('Tests the column\'s manifest merge on a pin move (#148)', 'test'),
    'tools/test_conformance.py': ('Tests that a replacement run keeps receipts and cannot hide missing spends', 'test'),
    'tools/test_export_cargo.py': ('Tests the export\'s Cargo and Makefile transforms on synthetic fixtures (#107)', 'test'),
    'tools/test_export_gate.py': ('Tests that a failed subprocess or a missing export cannot pass the export gate', 'test'),
    'tools/test_export_pointers.py': ('Tests the export\'s pointer substitution and its accounting (#101)', 'test'),
    'tools/test_export_rules.py': ('Tests the export\'s rule withholding on synthetic identifiers (#102)', 'test'),
    'tools/test_fixtures_proof.py': ('Tests the fixture proof\'s verdict and receipt contract with negative controls (#146)', 'test'),
    'tools/test_mechanism_hex.py': ('Tests that the hex gate holds on every corpus path but the public headers', 'test'),
    'tools/test_receipt_trim.py': ('Tests the receipt projection and its size bound on synthetic receipts', 'test'),
    'tools/test_teranode_gate.py': ('Tests the divergence report\'s writer on synthetic records (#95)', 'test'),
    'tools/tools_index.py': ('Writes this page from the export\'s file list; --check refuses a stale page (#173)', 'generator'),
    'tools/records_index.py': ('Writes docs/records/INDEX.md from the exported records; --check refuses a stale index (#175)', 'generator'),
    'tools/make_help_check.py': ('Checks that every .PHONY target of the Makefile has its `## ` help line (#174)', 'gate'),
    'tools/utxo_cases.py': ('Derives the UTXO boundary rows (#61) from the pinned reference source', 'generator'),
    'tools/utxo_check.sh': ('Checks the source-derived UTXO column (#61)', 'gate'),
    'tools/wire_compare.py': ('Compares the spec\'s wire-view column with each engine\'s (#86)', 'measurement'),
    'tools/wire_corpus.py': ('Builds the wire-view corpus from public mainnet reads (#86)', 'generator'),
    'tools/withheld_legs.py': ('Reads the list of legs the hosted gate skips and matches it with the workflow (#116)', 'gate'),
    'tools/withheld_legs.txt': ('Lists what the hosted gate does not run, by name (#116)', 'gate'),
    'tools/witness.sh': ('Replays one recorded witness by one command (#30)', 'test'),
    'tools/wording_allow.txt': ('Lists the exact phrases in which a gated word is not a claim', 'gate'),
    'tools/wording_gate.sh': ('Greps the public pages for the forms that may not leave the repository (#33)', 'gate'),
    'tools/xsig/gosign/go.mod': ('Pins go-sdk for the go signer of the checksig-in-unlock witness (#144)', 'measurement'),
    'tools/xsig/gosign/go.sum': ('Pins the go signer\'s module sums (#144)', 'measurement'),
    'tools/xsig/gosign/main.go': ('Signs with go-sdk for the checksig-in-unlock witness (#144)', 'measurement'),
    'tools/xsig/tssign.mjs': ('Signs with @bsv/sdk for the checksig-in-unlock witness (#144)', 'measurement'),
    'tools/xsig_witness.py': ('Measures the checksig-in-unlock witness on a fresh regtest instance of the reference (#144)', 'measurement'),
}


def tracked(prefix=''):
    out = subprocess.run(['git', '-C', ROOT, 'ls-files', '--', prefix], check=True, capture_output=True, text=True).stdout
    return [p for p in out.split('\n') if p]


def public(paths, rules):
    return [p for p in paths if export_public.group_of(rules, p) is None]


def read(rel):
    try:
        with open(os.path.join(ROOT, rel), encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


def code(text, rel):
    """The text a program runs: comment lines dropped, and a Python file's triple-quoted strings."""
    if rel.endswith('.py'):
        text = re.sub(r'("""|\'\'\')(?:.|\n)*?\1', '', text)
    return '\n'.join(l for l in text.split('\n') if not l.lstrip().startswith(('#', '//')))


def make_targets():
    """[(target, rule line + recipe text)] of the Makefile."""
    out, cur, body = [], None, []
    for line in read('Makefile').split('\n'):
        m = re.match(r'^([A-Za-z0-9_.-]+):(?!=)', line)
        if m and not line.startswith('.'):
            if cur:
                out.append((cur, '\n'.join(body)))
            cur, body = m.group(1), [line]
        elif cur and line.startswith('\t'):
            body.append(line)
    if cur:
        out.append((cur, '\n'.join(body)))
    return out


def check_legs():
    """{function name: step name} from tools/check.sh's dispatch, and [(leg, text)] of each function's body."""
    text = read('tools/check.sh')
    steps = {fn: st for st, fn in re.findall(r'^\s+([a-z]+)\) ([a-z_]+) ;;', text, re.M)}
    for st, script in re.findall(r'^\s+([a-z]+)\) bash "\$ROOT/tools/([a-z_]+\.sh)"', text, re.M):
        steps['tools/' + script] = st
    bodies, cur, buf = [], None, []
    for line in text.split('\n'):
        m = re.match(r'^([a-z_]+)\(\) \{', line)
        if m:
            if cur in steps:
                bodies.append((steps[cur], '\n'.join(buf)))
            cur, buf = m.group(1), []
        elif line.startswith('case "$step"'):
            if cur in steps:
                bodies.append((steps[cur], '\n'.join(buf)))
            cur = None
        elif not line.lstrip().startswith('#'):
            buf.append(line)
    for path, st in steps.items():
        if path.startswith('tools/'):
            bodies.append((st, path))
    return bodies


def names(rel):
    """The forms a caller writes: tools/<name>, or the bare file name for a nested file's directory."""
    base = os.path.basename(rel)
    return [rel, base] if rel.count('/') == 1 else [rel, os.path.dirname(rel) + '/']


def mentions(text, rel):
    for form in names(rel):
        if re.search(r'(?<![A-Za-z0-9_.-])' + re.escape(form) + r'(?![A-Za-z0-9_-])', text):
            return True
    return False


def callers(rel, targets, legs, scripts, pages):
    found = []
    found += ['Makefile: ' + t for t, body in targets if mentions(body, rel)]
    found += ['check.sh: ' + leg for leg, body in legs if (body == rel or mentions(body, rel)) and rel != 'tools/check.sh']
    found = list(dict.fromkeys(found))
    if found:
        return '; '.join(found[:4]) + ('; ...' if len(found) > 4 else '')
    by = [s for s in scripts if s != rel and mentions(code(read(s), s), rel)]
    if by:
        return '; '.join(by[:3]) + ('; ...' if len(by) > 3 else '')
    pg = [p for p in pages if mentions(read(p), rel)]
    if pg:
        return pg[0]
    return 'by hand'


def cell(s):
    return s.replace('|', '\\|')


def page():
    rules = export_public.load_withheld(export_public.WITHHELD)
    files = sorted(set(public(tracked('tools'), rules)) | {PAGE})
    missing = [f for f in files if f not in DESC]
    if missing:
        sys.exit('tools_index: no line in DESC for ' + ', '.join(missing) + ' (add one: what it does, its class)')
    targets, legs = make_targets(), check_legs()
    scripts = [s for s in public(tracked('tools') + tracked('.github'), rules)
               if s.endswith(('.sh', '.py', '.yml', '.mjs')) and s != 'tools/tools_index.py']
    pages = public(['README.md', 'harness/README.md', 'lean/README.md', 'corpus/INDEX.md']
                   + sorted(p for p in tracked('docs') if re.fullmatch(r'docs/[^/]+\.md', p)), rules)
    lines = [
        '# tools/',
        '',
        'This directory holds the scripts that check the tree (the gates of `make check`), that write its generated files '
        '(the generators), that run measurements against the pinned implementations, and the routes the maintainers use '
        'to run the checks on their machines. This page is generated by `tools/tools_index.py` from the public file list; '
        'edit that script, never this page, and `python3 tools/tools_index.py --check` refuses a stale copy.',
        '',
        'Classes: gate (a check that can fail a run), generator (writes a committed file), measurement (runs an '
        'implementation and records what it answered), test (tests a tool), maintainers\' route (runs a check on a '
        'particular machine; a stranger runs `make verify` instead).',
        '',
        '**The host values.** The pins block of `docs/PROVENANCE.md` §1a names eleven clones and built binaries by `$NAME` (`BSV_SPEC_REFERENCE_CLONE`, `BSV_SPEC_REFERENCE_BINARY`, `BSV_SPEC_REFERENCE_BINARY_WALLET`, `BSV_SPEC_REFERENCE_BINARY_ZMQ`, `BSV_SPEC_TERANODE_CLONE`, `BSV_SPEC_GOBDK_CLONE`, `BSV_SPEC_GO_CHAINCFG_CLONE`, `BSV_SPEC_GO_SAFE_CONVERSION_CLONE`, `BSV_SPEC_BSV_RS_CLONE`, `BSV_SPEC_GO_SDK_CLONE`, `BSV_SPEC_TS_SDK_CLONE`); each is a path on the maintainers\' hosts, set in the environment (`export BSV_SPEC_REFERENCE_CLONE=/path/to/bitcoin-sv`) or as a `NAME="/path"` line of `tools/host_private.sh` (a file absent from the public edition). Without them the pins and citation legs skip those pins by name, never a pass, and the maintainers\' routes stop with one line and exit 2.',
        '',
        '| path | what it does | who calls it | class |',
        '|---|---|---|---|',
    ]
    for f in files:
        what, cls = DESC[f]
        assert cls in CLASSES, (f, cls)
        who = 'by hand' if f == PAGE else callers(f, targets, legs, scripts, pages)
        lines.append(f'| `{f}` | {cell(what)} | {cell(who)} | {cls} |')
    return '\n'.join(lines) + '\n'


def main():
    text = page()
    if sys.argv[1:] == ['--check']:
        if read(PAGE) != text:
            print(f'tools_index: {PAGE} is stale (regenerate: python3 tools/tools_index.py > {PAGE})')
            sys.exit(1)
        print(f'tools_index: {PAGE} is current ({text.count(chr(10) + "| `")} files)')
    elif not sys.argv[1:]:
        sys.stdout.write(text)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
