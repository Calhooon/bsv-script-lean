#!/usr/bin/env bash
# The bench leg (#137; S3, lane gate-137, 2026-10-14): the replay and gate walls the tree already measures, held to a
# regression bar, and a bounded fuzz smoke of the harness's seed generator. A leg of `make check`, run after the chain leg.
#
# THE WALLS. The walls are read, never re-measured here: the chain leg's per-executable walls and its replay wall
# (`chain timing:` and `chain: GREEN` lines), the flow leg's large-lock walls, the harness leg's replay walls
# (`harness timing:` lines, tools/check.sh's harness_smoke, and run_diff's and run_engine's own trailing walls) and the fuzz smoke's own wall, from the tripwire's own log
# (`--log`, as `tools/check.sh all` calls it) or, standalone, from the newest docs/records/*-make-check-box.txt; and the
# export gate's two walls from the newest export dry-run record (the export gate runs outside make check, docs/LINT.md
# section 2). Each is judged against tools/bench_baseline.json: a wall more than `bar` (1.5) times its baseline AND more
# than `floor_seconds` (0.5 s) above it is RED, named. The tripwire walls are baselined per host (the box's, cut
# 2026-10-14); on a host with no baseline (the Studio, a Modal container) they are reported and SKIPPED BY NAME, never
# judged against another machine's walls; the export walls are judged on every host. The whole tripwire's wall is
# reported, never judged: it includes the builds, which a source change moves by minutes. In `--log` mode a baselined
# wall missing from the log is RED (the leg that prints it went quiet); in record mode it is named as absent.
# The bar, the floor and every baseline are re-cut only by a dated commit naming the records it read.
#
# THE COLD-RUN RULE (#137's follow-up; S3, lane cold-137, 2026-10-15). The chain leg's walls are its executables' runs
# right after `lake build`, and the run after a rebuild is cold: on the stacked tree of #89 to #91 four of them read
# 1.6x to 5.2x their baselines and two minutes later every one was below it (#137's comment of 2026-10-14 23:00Z). So in
# `--log` mode each chain executable wall with a `rerun` command in tools/bench_baseline.json (the command
# tools/chain_leg.sh runs for it) is run a second time here, alone, and the SECOND run is judged, when either rule fires:
# `rebuilt` (the executable's mtime is newer than the stamp of the previous record, the newest
# docs/records/*-make-check-box.txt; the current run's record is written after this leg) or `cheap` (its baseline is
# under the floor, so the second run costs less than the noise the floor already absorbs). Otherwise rule `warm`: the
# executable predates the previous record, its run in the log is warm and is the one judged. The parts sum is
# re-summed with the second runs in place of the logged ones (rule `resummed`); the replay wall is the parallel wall of
# the logged runs and is judged as logged. Every wall line names its rule, a second-run line also the logged run's wall and
# the rebuilt-since marker (the executable's mtime against the previous record's stamp); the verdict line counts the
# rules. On a RED the load sampler's newest line (the `.samples` file beside the log, or the record's last `sample`
# line in record mode) is printed beside the walls and quoted in the verdict, its `other programs` part included. In
# record mode nothing is re-run (rule `record`: the walls as recorded). BENCH_BIN_DIR overrides the executables'
# directory (lean/.lake/build/bin) for a scratch check of the rule.
#
# THE FUZZ SMOKE. harness/src/bin/seed_gen (the seed corpus's generator, deterministic from its seed) writes
# BENCH_FUZZ_COUNT (50000) fresh cases under a seed taken from the commit (BENCH_FUZZ_SEED overrides it; a RED is
# reproduced from the record's commit), twice, and the two corpora must be byte-identical; seed_gen itself is RED on
# a bsv-rs panic or a nondeterministic verdict; then run_bsvrs --smoke re-runs every case against its recorded verdict.
# The tree has no `cargo fuzz` target (no fuzz/ directory, no libfuzzer dependency in harness/Cargo.toml), so no
# coverage-guided fuzzing runs; docs/LINT.md section 1 says so. A host without cargo prints SKIPPED BY NAME.
#
# Usage: tools/bench_leg.sh [--log FILE | --record FILE] [--walls-only | --fuzz-only]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kind=record; src=; part=all
while [ $# -gt 0 ]; do
  case "$1" in
    --log) kind=log; src="$2"; shift 2 ;;
    --record) kind=record; src="$2"; shift 2 ;;
    --walls-only) part=walls; shift ;;
    --fuzz-only) part=fuzz; shift ;;
    *) echo "bench: unknown argument $1"; exit 2 ;;
  esac
done
if [ -z "$src" ]; then
  src="$(ls "$ROOT"/docs/records/*-make-check-box.txt 2>/dev/null | sort | tail -1)"
  [ -n "$src" ] || { echo "bench: RED (no docs/records/*-make-check-box.txt to read the walls from)"; exit 1; }
fi
now() { python3 -c 'import time; print("%.6f" % time.time())'; }
red=0

fuzz_smoke() {
  echo "== bench fuzz: seed_gen fresh cases, twice, byte-identical; run_bsvrs --smoke on them (#137) =="
  if ! command -v cargo >/dev/null 2>&1; then
    echo "bench fuzz: SKIPPED BY NAME (cargo is not on PATH on host $(hostname -s); the fuzz smoke needs the harness's seed_gen and run_bsvrs)"
    return 0
  fi
  local count="${BENCH_FUZZ_COUNT:-50000}" seed="${BENCH_FUZZ_SEED:-}"
  [ -n "$seed" ] || seed="0x$(git -C "$ROOT" rev-parse HEAD 2>/dev/null | cut -c1-16)"
  [ "$seed" != "0x" ] || seed=0x137f022e00000001
  local tmp; tmp="$(mktemp -d)"
  ( cd "$ROOT/harness" && cargo build --release --quiet --locked --bin seed_gen --bin run_bsvrs ) || { echo "bench fuzz: RED (the harness does not build)"; rm -rf "$tmp"; return 1; }
  local bin; bin="$(cd "$ROOT/harness" && cd "${CARGO_TARGET_DIR:-target}" && pwd)"   # where cargo put it, as the sighash leg reads it
  local t0 out1 out2 smoke rc=0; t0=$(now)
  out1="$("$bin/release/seed_gen" --out "$tmp/a" --seed "$seed" --count "$count" 2>&1)" || rc=1
  out2="$("$bin/release/seed_gen" --out "$tmp/b" --seed "$seed" --count "$count" 2>&1)" || rc=1
  smoke="$("$bin/release/run_bsvrs" --corpus "$tmp/a" --smoke 2>&1)" || rc=1
  if [ "$rc" = 0 ]; then
    printf '%s\n' "$out1" | grep -E 'entries|nondeterminism' | sed 's/^ */  bench fuzz> /'
    printf '%s\n' "$smoke" | tail -1 | sed 's/^ */  bench fuzz> /'
  else
    # on failure the case itself: seed_gen's stderr (a panic, a nondeterministic verdict) and run_bsvrs's RED lines
    printf '%s\n' "$out1" "$out2" | grep -v '^ *$' | tail -20 | sed 's/^ */  bench fuzz> /'
    printf '%s\n' "$smoke" | grep -v '^ *$' | tail -20 | sed 's/^ */  bench fuzz> /'
  fi
  local wall; wall=$(python3 -c "print('%.6f' % ($(now) - $t0))")
  export BENCH_FUZZ_WALL="$wall"
  local same=no; cmp -s "$tmp/a/seed.jsonl" "$tmp/b/seed.jsonl" && same=yes
  rm -rf "$tmp"
  if [ "$rc" = 0 ] && [ "$same" = yes ] && printf '%s\n' "$out1" | grep -q 'nondeterminism 0, panics 0' \
     && printf '%s\n' "$smoke" | grep -q "^run_bsvrs --smoke: GREEN ($count of $count entries"; then
    echo "bench fuzz: GREEN [X] (seed_gen seed $seed, $count cases, generated twice byte-identical, panics 0, nondeterminism 0; run_bsvrs --smoke $count of $count agree; wall [M] ${wall}s)"
  else
    echo "bench fuzz: RED (seed_gen seed $seed, $count cases: exit $rc, twin corpora identical: $same; the bench fuzz> lines above are seed_gen's and run_bsvrs's own output; reproduce with BENCH_FUZZ_SEED=$seed BENCH_FUZZ_COUNT=$count tools/bench_leg.sh --fuzz-only)"
    return 1
  fi
}

walls_judge() {
  echo "== bench: the replay and gate walls against tools/bench_baseline.json (#137) =="
  if [ "$kind" = log ]; then
    # the log is written through tee: the chain leg's verdict line may land a moment late (tools/check.sh's require_leg_lines)
    local i=0; while [ $i -lt 10 ] && ! grep -q '^ *chain: GREEN' "$src"; do sleep 1; i=$((i + 1)); done
  fi
  BENCH_SAMPLES="${src}.samples" BENCH_BIN="${BENCH_BIN_DIR:-$ROOT/lean/.lake/build/bin}" BENCH_ROOT="$ROOT" BENCH_KIND="$kind" BENCH_SRC="$src" BENCH_HOSTNAME="${BENCH_HOST:-$(hostname -s)}" python3 - <<'PY'
import calendar, glob, json, os, re, subprocess, sys, time
root, kind, src, host = (os.environ[k] for k in ("BENCH_ROOT", "BENCH_KIND", "BENCH_SRC", "BENCH_HOSTNAME"))
bindir = os.environ["BENCH_BIN"]
base = json.load(open(os.path.join(root, "tools/bench_baseline.json")))
bar, floor = float(base["bar"]), float(base["floor_seconds"])
text = open(src, encoding="utf-8", errors="replace").read()
rel = os.path.relpath(src, root) if src.startswith(root) else ("the tripwire's own log" if kind == "log" else src)
reds, judged = [], 0
rules = {}

def utc(t):
    return time.strftime("%Y-%m-%d %H:%M:%SZ", time.gmtime(t))

# the previous record: the newest box tripwire record on disk (in --log mode the current run's is written after this leg)
prev = sorted(glob.glob(os.path.join(root, "docs/records/*-make-check-box.txt")))
prev_rel, prev_t = None, None
if prev:
    prev_rel = os.path.relpath(prev[-1], root)
    m = re.match(r"(\d{8}-\d{6})-", os.path.basename(prev[-1]))
    prev_t = calendar.timegm(time.strptime(m.group(1), "%Y%m%d-%H%M%S")) if m else None

def sampler_line():
    p = os.environ.get("BENCH_SAMPLES", "")
    lines = open(p, encoding="utf-8", errors="replace").read().splitlines() if p and os.path.exists(p) else []
    if kind != "log" and not lines:
        lines = [l for l in text.splitlines() if re.match(r"^ *sample \d", l)]
    lines = [l.strip() for l in lines if l.strip()]
    if not lines:
        return "no load sampler line (no samples beside " + rel + ")"
    last = lines[-1].rstrip("; ")
    if "other programs:" not in last:
        last += " (other programs: none over 5% cpu)"
    return last

def second_run(w, logged):
    """The cold-run rule: (value judged, rule, marker). Runs the executable again when `rebuilt` or `cheap` fires."""
    if kind != "log":
        return logged, "record", "the wall as recorded"
    exe = os.path.join(bindir, w["rerun"][0])
    if not os.path.exists(exe):
        return logged, "warm", f"no executable at {os.path.relpath(exe, root)} to re-run, the logged run judged"
    mt = os.stat(exe).st_mtime
    rebuilt = prev_t is not None and mt > prev_t
    since = (f"rebuilt since {prev_rel}: built {utc(mt)}, the record stamped {utc(prev_t)}" if rebuilt else
             f"built {utc(mt)}, before {prev_rel} stamped {utc(prev_t)}" if prev_t is not None else
             f"built {utc(mt)}, no previous box record to compare")
    cheap = secs(float(w["baseline"]), w["unit"]) < floor
    if not (rebuilt or cheap):
        return logged, "warm", since + "; the logged run judged"
    t0 = time.monotonic()
    r = subprocess.run([exe, *w["rerun"][1:]], cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    v = time.monotonic() - t0
    rule = "rebuilt" if rebuilt else "cheap"
    if r.returncode != 0:
        reds.append(f"{w['name']} second run exited {r.returncode}")
        print(f"bench: {w['name']}: RED (the second run, rule {rule}, exited {r.returncode})")
    return v, rule, f"second run judged, the chain leg's run {logged:g} {w['unit']}; {since}"

def secs(v, unit):
    return v / 1000.0 if unit == "ms" else v

def judge(w, v, rule=None, marker=None):
    global judged
    judged += 1
    if rule:
        rules[rule] = rules.get(rule, 0) + 1
    b, unit = float(w["baseline"]), w["unit"]
    ratio = v / b if b > 0 else float("inf")
    bad = v > bar * b and secs(v, unit) - secs(b, unit) > floor
    tag = f" [rule {rule}: {marker}]" if rule else ""
    print(f"bench: {w['name']} [M] {v:g} {unit} against {b:g} {unit} [M] ({w['source']}): {ratio:.2f}x: {'RED' if bad else 'ok'}{tag}")
    if bad:
        reds.append(f"{w['name']} {v:g} {unit} > {bar}x {b:g} {unit} and more than {floor} s above it" + (f" (rule {rule})" if rule else ""))

def measured(w):
    if "env" in w:
        e = os.environ.get(w["env"])
        return float(e) if e else None
    m = re.findall(w["pattern"], text, re.M)
    return float(m[-1]) if m else None

hb = base["hosts"].get(host)
if hb is None:
    shown = []
    for w in base["hosts"]["box"]["walls"]:
        v = measured(w)
        if v is not None:
            shown.append(f"{w['name']} {v:g} {w['unit']}")
    print(f"bench: host {host} has no baseline in tools/bench_baseline.json: the tripwire walls SKIPPED BY NAME, reported not judged ({'; '.join(shown) or 'none in ' + rel})")
else:
    delta, parts_w = 0.0, None
    for w in hb["walls"]:
        v = measured(w)
        if w["name"] == "chain parts summed" and v is not None:
            parts_w = (w, v)   # judged after the executables, with their second runs in place of the logged ones
            continue
        if v is None:
            if kind == "log" and "env" not in w:
                print(f"bench: {w['name']}: RED (no measurement in {rel}; the leg that prints it went quiet)")
                reds.append(f"{w['name']} absent")
            else:
                print(f"bench: {w['name']}: absent from {rel} (it predates the line or the part did not run), not judged")
            continue
        if "rerun" in w:
            v2, rule, marker = second_run(w, v)
            delta += v2 - v
            judge(w, v2, rule, marker)
        else:
            judge(w, v, "logged" if kind == "log" else "record", "the wall as the log carries it" if kind == "log" else "the wall as recorded")
    if parts_w is not None:
        w, v = parts_w
        if delta:
            judge(w, v + delta, "resummed", f"the logged sum {v:g} s with the second runs in place of the logged ones ({delta:+.6f} s)")
        else:
            judge(w, v, "logged" if kind == "log" else "record", "no second run moved it")
    for w in hb.get("reported", []):
        v = os.environ.get("BENCH_ELAPSED") if kind == "log" else (re.findall(w["pattern"], text) or [None])[-1]
        if v is not None:
            print(f"bench: {w['name']} [M] {float(v):g} {w['unit']}, the baseline's {w['baseline']} {w['unit']} ({w['source']}): reported, not judged ({w['why_not_judged']})")

# the export gate: the newest export record with a full-gate row
recs = []
for p in sorted(glob.glob(os.path.join(root, "docs/records/*export*.md"))):
    lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
    if any(l.startswith("| full gate |") for l in lines):
        recs.append((p, lines))
if not recs:
    print("bench: RED (no export record with a `| full gate |` row under docs/records/)")
    reds.append("export record absent")
else:
    p, lines = recs[-1]
    col = None
    for l in lines:
        if l.startswith("| step |") and "wall seconds" in l:
            col = next(i for i, c in enumerate(l.strip().strip("|").split("|")) if "wall seconds" in c)
    for w in base["export"]["walls"]:
        row = next((l for l in lines if l.startswith(f"| {w['row']} |")), None)
        if row is None or col is None:
            print(f"bench: {w['name']}: RED (no `| {w['row']} |` row with a wall-seconds column in {os.path.relpath(p, root)})")
            reds.append(f"{w['name']} unreadable")
            continue
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        w = dict(w, name=f"{w['name']} ({os.path.relpath(p, root)})")
        judge(w, float(cells[col]), "export record", "the export gate's newest record")

fired = ", ".join(f"{k} {n}" for k, n in sorted(rules.items()))
if reds:
    s = sampler_line()
    print(f"bench: the load sampler beside the RED: {s}")
    print(f"bench: RED ({len(reds)} RED, {judged} walls judged against the bar {bar}x with the floor {floor} s: {'; '.join(reds)}; the rules fired: {fired}; the load sampler: {s}; tools/bench_baseline.json cut {base['cut']})")
    sys.exit(1)
if hb is None:
    print(f"bench: GREEN [X] ({judged} export walls judged on host {host}; the tripwire walls SKIPPED BY NAME, no baseline for this host; tools/bench_baseline.json cut {base['cut']}, bar {bar}x, floor {floor} s; the tripwire walls from {rel})")
    sys.exit(0)
print(f"bench: GREEN [X] ({judged} walls judged on host {host} against tools/bench_baseline.json cut {base['cut']}, bar {bar}x, floor {floor} s; the rules fired: {fired}; the tripwire walls from {rel})")
PY
}

if [ "$part" != walls ]; then fuzz_smoke || red=1; fi
if [ "$part" != fuzz ]; then walls_judge || red=1; fi
exit $red
