#!/usr/bin/env bash
# tools/fuzz_daily.sh: the fuzz campaign's one line a day for the captain (S3, lane fuzz-campaign, 2026-10-15).
# Reads the day's batch lines of tools/fuzz_campaign.sh ($FUZZ_STATE/log/<date>.log, outside the repository) and prints
#   <date> batches B (red R, failed F) spends S divergences D (unexplained U) undecided X no-spec Y witnesses <corpus file|none>
#   record <path|none>; replay still P fixed Q unrun Z; <engine> ran N (red R) skipped K failed F agree A divergences D
#   (unexplained U) rows W, per SDK engine of the batch lines (lane fuzz-cut2, 2026-10-15)
# which it also writes into $FUZZ_STATE/DAILY.txt (a re-run for the same date replaces that date's line). On a day with a
# witness file it INDEXES it in the campaign's worktree (CLAUDE.md rule 12): a row of corpus/INDEX.md's fuzz table (above
# its marker line) for the node's day file and one for each SDK engine's (corpus/fuzz/<date>-<engine>.jsonl), one more such
# row for each batch's kept run_svnode or run_engine per-class witnesses (corpus/fuzz/<date>-batch-<n>-<engine>.jsonl,
# <engine> sv-node, go-sdk or ts-sdk, named in the batch's record line) and a row of docs/records/README.md, both uncommitted for the captain's lane to land with the rows.
# `divergences` counts divergent cells (a spend has two: the block and the mempool column); `red` counts batches whose
# run_svnode verdict was RED (an unexplained divergence, a node description outside the table or a flag-word drift);
# `failed` counts batches that stopped before a verdict (they are retried, with the same seed); `undecided` counts the
# node's undecided runs (a timeout or a skip) and `no-spec` the entries without a spec verdict, which run_svnode's
# GREEN does not test: `divergences 0` is a fidelity count only with both at 0. An engine `skipped` (its runner, adapter
# or node 22 absent) or `failed` (run_engine stopped without a verdict) is never counted as agreeing. A divergence is never
# judged here: each witness row is `ruling: open`, a Finding for the captain (rule 4).
# Usage: tools/fuzz_daily.sh [YYYY-MM-DD]   (default: today, UTC). Environment: FUZZ_STATE, FUZZ_TREE as the loop's.
set -euo pipefail
: "${FUZZ_STATE:=$HOME/bsv/targets/spec-fuzz}"
: "${FUZZ_TREE:=$HOME/bsv/worktrees/spec-box-fuzz}"
d="${1:-$(date -u +%Y-%m-%d)}"
FZ_DAY="$d" FZ_STATE="$FUZZ_STATE" FZ_TREE="$FUZZ_TREE" python3 - <<'PY'
import hashlib, os, re
day, state, tree = os.environ["FZ_DAY"], os.environ["FZ_STATE"], os.environ["FZ_TREE"]
log = os.path.join(state, "log", f"{day}.log")
lines = open(log, encoding="utf-8", errors="replace").read().splitlines() if os.path.exists(log) else []
done = [dict(re.findall(r"(\w+)=(\S+)", l)) for l in lines if re.search(r" batch=\d+ ", l) and " FAILED " not in l]
failed = sum(1 for l in lines if " FAILED " in l)
num = lambda k: sum(int(b.get(k, 0)) for b in done)
red = sum(1 for b in done if b.get("verdict") == "RED")
rec_rel = f"docs/records/{day.replace('-', '')}-fuzz-campaign-divergences.jsonl"
has_r = os.path.exists(os.path.join(tree, rec_rel))
fz = os.path.join(tree, "corpus/fuzz")
natural = lambda f: [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", f)]
listing = sorted(os.listdir(fz), key=natural) if os.path.isdir(fz) else []
day_files = [f for f in listing if re.fullmatch(re.escape(day) + r"(-[a-z]+-sdk)?\.jsonl", f)]
note = ""
if day_files:
    idx = os.path.join(tree, "corpus/INDEX.md")
    text = open(idx, encoding="utf-8").read()
    marker = "<!-- fuzz-campaign rows: tools/fuzz_daily.sh inserts above this line -->"
    if marker not in text:
        note = " (corpus/INDEX.md has no fuzz-campaign marker: rebase the campaign's worktree on main)"
    else:
        for wf in day_files + [f for f in listing if re.fullmatch(re.escape(day) + r"-batch-(\d+)-(sv-node|go-sdk|ts-sdk)\.jsonl", f)]:
            wp = os.path.join(fz, wf)
            wrows = sum(1 for l in open(wp) if l.strip())
            wsha = hashlib.sha256(open(wp, "rb").read()).hexdigest()
            m = re.fullmatch(re.escape(day) + r"-batch-(\d+)-(sv-node|go-sdk|ts-sdk)\.jsonl", wf)
            what = (f"{m.group(2)}'s {'run_svnode' if m.group(2) == 'sv-node' else 'run_engine'} per-class witnesses of batch {m.group(1)}, the classifier's rulings" if m else
                    "open (each row a Finding for the captain, CLAUDE.md rule 4)" + ("" if wf == f"{day}.jsonl" else
                    f"; the {wf[len(day) + 1:-6]} column, one row per new class (tools/fuzz_batch.py)"))
            wrow = f"| [`corpus/fuzz/{wf}`](fuzz/{wf}) | {wrows} | `{wsha}` | [`{rec_rel}`](../{rec_rel}) | {what} |"
            text = "\n".join(l for l in text.split("\n") if not l.startswith(f"| [`corpus/fuzz/{wf}`]"))
            text = text.replace(marker, wrow + "\n" + marker)
        open(idx, "w", encoding="utf-8").write(text)
    rr = os.path.join(tree, "docs/records/README.md")
    rtext = open(rr, encoding="utf-8").read()
    rname = os.path.basename(rec_rel)
    if has_r and f"[{rname}]" not in rtext:
        rrow = (f"| [{rname}]({rname}) | S3, the fuzz campaign (tools/fuzz_campaign.sh): one line per batch of {day} "
                f"that wrote a witness row (its seeds, counts, classes, the spec's, the node's and the SDKs' keys); the rows in "
                f"{', '.join(f'`corpus/fuzz/{f}`' for f in day_files)} |")
        rtext = re.sub(r"(\| record \| scope and status \|\n\|---\|---\|\n)", lambda m: m.group(1) + rrow + "\n", rtext, count=1)
        open(rr, "w", encoding="utf-8").write(rtext)
eng = {}
for x in done:
    for k, v in x.items():
        if not k.endswith("_sdk"):
            continue
        t = eng.setdefault(k.replace("_", "-"), {"ran": 0, "red": 0, "skipped": 0, "failed": 0, "agree": 0, "divergent": 0, "unexplained": 0, "rows": 0})
        st = v.split(",")[0]
        if st.startswith("SKIPPED"):
            t["skipped"] += 1
        elif st.startswith("FAILED"):
            t["failed"] += 1
        else:
            t["ran"] += 1
            t["red"] += st == "RED"
            for kk, vv in (p.split(":") for p in v.split(",")[1:]):
                if kk in t:
                    t[kk] += int(vv)
rp = {"still": 0, "fixed": 0, "unrun": 0}
for x in done:
    for kk, vv in (p.split(":") for p in x.get("replay", "").split(",") if ":" in p):
        if kk in rp:
            rp[kk] += int(vv)
out = (f"{day} batches {len(done)} (red {red}, failed {failed}) spends {num('spends')} divergences {num('divergent')} "
       f"(unexplained {num('unexplained')}) undecided {num('undecided')} no-spec {num('no_spec')} witnesses {'+'.join('corpus/fuzz/' + f for f in day_files) or 'none'} "
       f"record {rec_rel if has_r else 'none'}{note}; replay still {rp['still']} fixed {rp['fixed']} unrun {rp['unrun']}"
       + "".join(f"; {k} ran {t['ran']} (red {t['red']}) skipped {t['skipped']} failed {t['failed']} agree {t['agree']} "
                 f"divergences {t['divergent']} (unexplained {t['unexplained']}) rows {t['rows']}" for k, t in sorted(eng.items())))
daily = os.path.join(state, "DAILY.txt")
old = open(daily, encoding="utf-8").read().splitlines() if os.path.exists(daily) else []
old = [l for l in old if not l.startswith(day + " ")]
open(daily, "w", encoding="utf-8").write("\n".join(old + [out]) + "\n")
print(out)
PY
