#!/usr/bin/env bash
# tools/witness.sh <witness-id> [--restore-block]: ONE recorded witness replayed by ONE command (#30's done-bar: "every
# witness reproducible by one command"; S3, set 4, 2026-09-27). It finds the witness line under corpus/witnesses/ (every
# line carries its own `divergence`: the class, the spec's key, the engine's key, both verdicts, the citation), writes
# it as a one-entry corpus in a scratch directory, runs the spec's evaluator on it (eval/bsvs corpus) and the engine's
# driver on it WITHOUT --record (its witnesses to the scratch directory, the tree untouched), and compares the replayed
# witness with the recorded one IN THE RECORDED PAIRING (#32 C-B1): the replayed line whose spec column (`a`, the name
# before its `@`, the commit after it moving with the tree) and engine column (`b`) are the recorded ones, for the same
# entry and family; then the class, the spec's verdict and code, and the engine's verdict and code. GREEN (exit 0) when
# they are the same; RED (exit 1) otherwise; exit 2 on a usage error, a witness that is not found, or a file no driver
# replays (below).
# NOT REPLAYED HERE (#32 C-B2): the top-level policy-defaults.jsonl. Its lines record the two NODES' mempool columns
# (`bitcoin-sv@… mempool` against `teranode@… mempool`, [D] from source), which no driver writes; the executed check of
# that file is `make witnesscheck` (lean/Test/WitnessCheck.lean: the spec under both nodes' derived parameters).
#   bsv-rs (the top-level files)  run_diff, in-process at the pinned crate
#   go-sdk/, ts-sdk/              run_engine --engine gosdk|tssdk, through the adapters at their pins
#   sv-node/ (script corpora)     run_svnode against the spec's two instances (harness/oracle/spec-node.sh local|policy)
#   sv-node/tx.jsonl              run_svnode --mode tx, the block road: it needs the block instance's chain at its base
#                                 snapshot; --restore-block restores it (spec-node.sh block stop/restore base/start) first
# Nothing here touches a network: the node instances are the spec's own regtest instances on this machine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ID="${1:-}"; RESTORE="${2:-}"
[ -n "$ID" ] || { echo "usage: tools/witness.sh <witness-id> [--restore-block]"; exit 2; }
BIN="${CARGO_TARGET_DIR:-$ROOT/harness/target}/release"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/witness.XXXXXX")"
python3 - "$ROOT" "$ID" "$WORK" <<'PY' || exit 2
import json, sys, glob, os
root, wid, work = sys.argv[1:4]
for f in sorted(glob.glob(f"{root}/corpus/witnesses/**/*.jsonl", recursive=True)):
    for line in open(f, encoding="utf-8"):
        if f'"id":"{wid}"' in line or f'"id": "{wid}"' in line:
            e = json.loads(line)
            if e.get("id") != wid: continue
            rel = os.path.relpath(f, f"{root}/corpus/witnesses")
            engine = rel.split("/")[0] if "/" in rel else "bsv-rs"
            if rel == "policy-defaults.jsonl":
                print(f"witness.sh: {wid} is a policy-default witness (the two nodes' mempool columns, [D] from source): no driver writes its columns; its executed check is make witnesscheck (#32 C-B2)"); sys.exit(1)
            corpus = os.path.basename(f)[:-len(".jsonl")]
            d = e["divergence"]
            open(f"{work}/w.jsonl", "w").write(json.dumps({k: v for k, v in e.items() if k != "divergence"}) + "\n")
            json.dump({"file": rel, "engine": engine, "corpus": corpus, "class": d["rule"], "a": d["a"], "b": d["b"],
                       "a_verdict": d["a_verdict"], "b_verdict": d["b_verdict"], "family": e.get("family"), "decided_by": d.get("decided_by", "")}, open(f"{work}/want.json", "w"))
            print(f"witness {wid}: {rel} (engine {engine}, corpus {corpus}); class {d['rule']}; recorded {d['b']} {d['b_verdict'].get('verdict')} {d['b_verdict'].get('code') or ''}")
            sys.exit(0)
print(f"witness.sh: no witness with id {wid} under corpus/witnesses/"); sys.exit(1)
PY
ENGINE=$(python3 -c "import json;print(json.load(open('$WORK/want.json'))['engine'])")
CORPUS=$(python3 -c "import json;print(json.load(open('$WORK/want.json'))['corpus'])")
"$ROOT/eval/bsvs" corpus "$WORK/w.jsonl" --out "$WORK/spec.jsonl" | tail -1
mkdir -p "$WORK/wit"
# an SDK replay runs under the adapter timeout its corpus was RECORDED with (the manifest's `adapter_timeout_s`; the
# driver's own default is 120 s, the D15a re-run ten times it): a timeout witness reproduces under its own conditions
if [ "$ENGINE" = "go-sdk" ] || [ "$ENGINE" = "ts-sdk" ]; then
  T=$(python3 -c "import json,sys; m=json.load(open('$ROOT/corpus/witnesses/$ENGINE/manifest.json')).get('$CORPUS',{}); print(m.get('adapter_timeout_s') or '')")
  if [ -n "$T" ]; then export ENGINE_ADAPTER_TIMEOUT_S="$T"; echo "  the adapter timeout as recorded: ENGINE_ADAPTER_TIMEOUT_S=$T (the re-run at ten times it)"; fi
fi
cd "$ROOT/harness"
case "$ENGINE" in
  bsv-rs) "$BIN/run_diff" --corpus "$WORK/w.jsonl" --spec "$WORK/spec.jsonl" --witnesses "$WORK/wit" > "$WORK/run.log" 2>&1 || true ;;
  go-sdk) "$BIN/run_engine" --engine gosdk --corpus "$WORK/w.jsonl" --spec "$WORK/spec.jsonl" --witnesses "$WORK/wit" > "$WORK/run.log" 2>&1 || true ;;
  ts-sdk) "$BIN/run_engine" --engine tssdk --corpus "$WORK/w.jsonl" --spec "$WORK/spec.jsonl" --witnesses "$WORK/wit" > "$WORK/run.log" 2>&1 || true ;;
  sv-node)
    if [ "$CORPUS" = "tx" ]; then
      if [ "$RESTORE" = "--restore-block" ]; then
        "$ROOT/harness/oracle/spec-node.sh" block stop >/dev/null 2>&1 || true
        # the restore needs the node GONE, not stopping (two tx replays back to back raced here on 2026-09-27)
        for _ in $(seq 1 60); do pgrep -f "datadir=$HOME/bsv/targets/spec-oracle-block-data" >/dev/null || break; sleep 1; done
        "$ROOT/harness/oracle/spec-node.sh" block restore base | tail -1
        "$ROOT/harness/oracle/spec-node.sh" block start | tail -1
      else
        echo "witness.sh: a tx witness replays on the block road from the block chain's base snapshot: add --restore-block (it restores the spec's own block instance)"; exit 2
      fi
      "$BIN/run_svnode" --mode tx --corpus "$WORK/w.jsonl" --spec "$WORK/spec.jsonl" --witnesses "$WORK/wit" > "$WORK/run.log" 2>&1 || true
    else
      "$BIN/run_svnode" --corpus "$WORK/w.jsonl" --spec "$WORK/spec.jsonl" --witnesses "$WORK/wit" > "$WORK/run.log" 2>&1 || true
    fi ;;
  *) echo "witness.sh: no driver for engine $ENGINE"; exit 2 ;;
esac
python3 - "$WORK" <<'PY'
import json, sys, glob
work = sys.argv[1]
want = json.load(open(f"{work}/want.json"))
# a replay writes one witness per pairing and class: the recorded one is the line in the SAME pairing (#32 C-B1): the spec's
# column `a` (`spec@…` the block word, `spec-mempool@…` the policy word; the name before `@`, the commit moving with the
# tree) AND the engine's column `b` (`go-sdk@…` the block word, `go-sdk-mempool@…` the policy word, `ts-sdk-default@…` the
# SDK's own mode, which two spec columns pair with), for the recorded entry and family; never the first line of `b` alone
col = lambda k: (k or "").split("@")[0]
cands = []
for f in glob.glob(f"{work}/wit/**/*.jsonl", recursive=True):
    for line in open(f, encoding="utf-8"):
        if line.strip():
            e = json.loads(line)
            cands.append((e, e["divergence"]))
def pair(e, d):
    return (col(d.get("a")) == col(want["a"]) and d.get("b") == want["b"]
            and (want.get("family") is None or e.get("family") == want["family"]))
inpair = [d for e, d in cands if pair(e, d)]
got = next((d for d in inpair if d.get("rule") == want["class"]), None) or (inpair[0] if inpair else None)
tail = open(f"{work}/run.log", encoding="utf-8", errors="replace").read().strip().split("\n")[-3:]
if got is None:
    print(f"witness.sh: RED (the replay wrote no witness in the recorded pairing {col(want['a'])} / {want['b']}: the engine and the spec now agree there, or the driver stopped; the replay's pairings: {sorted(set(col(d.get('a')) + ' / ' + str(d.get('b')) for e, d in cands)) or 'none'})"); print("\n".join("  " + t[:220] for t in tail)); sys.exit(1)
same = (got["rule"] == want["class"]
        and got["a_verdict"].get("verdict") == want["a_verdict"].get("verdict") and got["a_verdict"].get("code") == want["a_verdict"].get("code")
        and got["b_verdict"].get("verdict") == want["b_verdict"].get("verdict") and got["b_verdict"].get("code") == want["b_verdict"].get("code"))
print(f"  replayed: class {got['rule']}; spec {got['a']} {got['a_verdict'].get('verdict')} {got['a_verdict'].get('code') or ''}; {got['b']} {got['b_verdict'].get('verdict')} {got['b_verdict'].get('code') or ''}")
print(f"  decided by: {want['decided_by'][:300]}")
print(f"witness.sh: {'GREEN (the witness reproduces in its recorded pairing: the same class, the same spec and engine verdicts and codes)' if same else 'RED (the replay differs from the record)'}; the scratch directory {work}")
sys.exit(0 if same else 1)
PY
