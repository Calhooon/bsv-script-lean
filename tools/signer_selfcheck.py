#!/usr/bin/env python3
"""tools/signer_selfcheck.py (#145 piece 1, lane sign-145a, [M] 2026-10-16; S3): THE SIGNABLE CORPUS's self-check.

The spec is the judge here (the node's column is #145 piece 3's). Four steps, each a verdict line:
  1. determinism: `signer_gen` regenerated under the manifest's seed into scratch equals corpus/signer byte for byte;
  2. the rows: `signer_gen --sign` signs every row BY HAND over its own `scriptcode_hex` (the pinned bsv-rs's dispatched
     digest, `compute_sighash_dispatched_for_signing`, and its RFC 6979 low-S signer: the harness's own helpers,
     harness/src/signer.rs), fills the unlock templates, and `eval/bsvs corpus` judges the signed spends under each
     row's own params (the `spec` column, the block word): every row the generator marks `valid` must be `valid`, every
     row it marks `invalid` must be `invalid` with the code its note names (`expect SCRIPT_ERR_<X>`): the version-1
     twins of #144's two shapes SIG_PUSHONLY (interpreter.cpp:2321-2334 at v1.2.3), the CHRONICLE bit before Chronicle
     ILLEGAL_CHRONICLE (296-303);
  3. the control: the same rows signed over the LOCKING SCRIPT ALONE at every site (the scriptCode the SDKs' default
     signing paths hash, #144) must leave every row whose scriptCodes all equal its lock as it was and turn every
     valid row with an in-unlock CHECKSIG site into `invalid`: the corpus tells the two scriptCodes apart;
  4. the mempool word (`spec-mempool`), reported, not judged.
Exit 0 when steps 1 to 3 hold, 1 otherwise.

Usage: tools/signer_selfcheck.py [--corpus corpus/signer] [--bin <signer_gen>] [--scratch DIR]
The binary defaults to $CARGO_TARGET_DIR/release/signer_gen, else harness/target/release/signer_gen
(`cargo build --release --locked --bin signer_gen` in harness/); eval/bsvs must be runnable (eval/README.md).
"""
import argparse
import collections
import filecmp
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(cmd):
    try:
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    except OSError as e:
        sys.exit(f"signer_selfcheck: SKIPPED BY NAME [M] {cmd[0]} unavailable: {e}")
    if r.returncode != 0:
        sys.exit(f"signer_selfcheck: RED [M] {cmd[0]} exited {r.returncode}: {r.stderr.strip()[-400:]}")
    return r.stdout + r.stderr


def jsonl(p):
    return [json.loads(line) for line in open(p, encoding="utf-8") if line.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default=str(ROOT / "corpus/signer"))
    tgt = Path(os.environ["CARGO_TARGET_DIR"]) if os.environ.get("CARGO_TARGET_DIR") else ROOT / "harness/target"
    ap.add_argument("--bin", default=str(tgt / "release/signer_gen"))
    ap.add_argument("--scratch", default=None)
    a = ap.parse_args()
    scratch = Path(a.scratch or tempfile.mkdtemp(prefix="signer-selfcheck-"))
    scratch.mkdir(parents=True, exist_ok=True)
    corpus = Path(a.corpus)
    manifest = json.load(open(corpus / "manifest.json", encoding="utf-8"))
    ok = True

    # 1. determinism
    regen = scratch / "regen"
    run([a.bin, "--out", str(regen), "--seed", manifest["seed"], "--count", str(manifest["count_per_family"])])
    names = ["manifest.json"] + [f["file"] for f in manifest["files"]]
    same = [n for n in names if filecmp.cmp(corpus / n, regen / n, shallow=False)]
    det = len(same) == len(names)
    ok &= det
    print(f"determinism: {'GREEN' if det else 'RED'} [M] {len(same)}/{len(names)} files byte-equal on regeneration under seed {manifest['seed']}")

    rows = {}
    for f in manifest["files"]:
        for r in jsonl(corpus / f["file"]):
            rows[r["id"]] = r

    def judged(lock_only):
        tag = "lock" if lock_only else "rows"
        signed, out = scratch / f"signed-{tag}.jsonl", scratch / f"spec-{tag}.jsonl"
        run([a.bin, "--sign", str(corpus), "--out", str(signed), *(["--lock-only"] if lock_only else []),
             "--digests", str(scratch / f"digests-{tag}.jsonl")])
        head = run([str(ROOT / "eval/bsvs"), "corpus", str(signed), "--out", str(out)]).strip().splitlines()[-1]
        return {e["id"]: e for e in jsonl(out)}, head

    # 2. the rows
    spec, head = judged(False)
    digests = {r["id"]: r for r in jsonl(scratch / "digests-rows.jsonl")}
    single_rows = [r for r in rows.values()
                   if any(i["index"] == 1 and i["sighash_type"] == 0x03 for i in r["signing"]["inputs"])]
    single_ok = bool(single_rows)
    for r in single_rows:
        sites = next(i["sites"] for i in digests[r["id"]]["inputs"] if i["index"] == 1)
        single_ok &= all(s["digest_hex"] == "01" + "00" * 31 for s in sites)
    ok &= single_ok
    print(f"single-sentinel: {'GREEN' if single_ok else 'RED'} [M] {len(single_rows)} dedicated 0x03 rows: input 1 digest is constant one")
    stamp = re.search(r"keyed (spec@\S+)", head)
    stamp = stamp.group(1) if stamp else "spec@?"
    per = collections.Counter()
    bad = []
    for i, r in rows.items():
        v = spec[i]["spec"]
        want = r["reference"]["expect"]
        m = re.search(r"expect SCRIPT_ERR_(\w+)", r.get("note", ""))
        code = m.group(1) if m else None
        fam = r["family"].split("/")[1]
        good = v["verdict"] == want and (code is None or (v.get("code") or "").endswith(code))
        per[(fam, want, "agree" if good else "DISAGREE")] += 1
        if not good:
            bad.append(f"{i} {r['family']}: generator {want} {code or ''}, spec {v['verdict']} {v.get('code') or ''}")
    for (fam, want, g), n in sorted(per.items()):
        print(f"  {fam:<22} generator {want:<7} {g:<8} {n}")
    for b in bad:
        print("  DISAGREE", b)
    valid = sum(1 for r in rows.values() if r["reference"]["expect"] == "valid")
    twins = sum(1 for r in rows.values() if "expect SCRIPT_ERR_SIG_PUSHONLY" in r.get("note", ""))
    ok &= not bad
    print(f"rows: {'GREEN' if not bad else 'RED'} [M] {len(rows) - len(bad)}/{len(rows)} rows agree with the spec ({stamp}, "
          f"block word): {valid} valid rows valid, {twins} SIG_PUSHONLY rows refused with SIG_PUSHONLY, "
          f"{len(rows) - valid - twins} other refusals with their code")

    # 3. the control
    ctl, _ = judged(True)
    moved_ok, kept_ok, wrong = 0, 0, []
    for i, r in rows.items():
        unlock_site = any(c != r["prevouts"][s["index"]]["script"] for s in r["signing"]["inputs"] for c in s["scriptcode_hex"])
        a_, b_ = spec[i]["spec"]["verdict"], ctl[i]["spec"]["verdict"]
        if unlock_site and a_ == "valid":
            if b_ == "invalid":
                moved_ok += 1
            else:
                wrong.append(f"{i}: valid over the lock alone")
        elif not unlock_site:
            if a_ == b_:
                kept_ok += 1
            else:
                wrong.append(f"{i}: moved though every scriptCode is the lock")
        else:
            if a_ == b_:
                kept_ok += 1
            else:
                wrong.append(f"{i}: invalid in-unlock row changed from {a_} to {b_}")
    for w in wrong:
        print("  CONTROL", w)
    ok &= not wrong
    print(f"control: {'GREEN' if not wrong else 'RED'} [M] signed over the locking script alone: {moved_ok} valid rows with an "
          f"in-unlock CHECKSIG site refused, {kept_ok} other rows unmoved")

    # 4. the mempool word, reported
    mp = collections.Counter((spec[i]["spec-mempool"]["verdict"], spec[i]["spec-mempool"].get("code")) for i in rows)
    print("mempool word (reported, not judged): " + ", ".join(f"{v} {c or ''}".strip() + f" {n}" for (v, c), n in sorted(mp.items(), key=str)))
    print(f"signer_selfcheck: {'GREEN' if ok else 'RED'} [M] {len(rows)} rows, {len(manifest['files'])} families, scratch {scratch}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
