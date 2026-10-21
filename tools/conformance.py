#!/usr/bin/env python3
"""tools/conformance.py: THE CONFORMANCE REPORT (#30; S3, set 4, 2026-09-27). Reads what the harness already records and
writes the page; it decides nothing: every row is a manifest's count or a classifier row (D83c's data), every class has
its citation and its smallest witness, and every witness is reproducible by one command (`tools/witness.sh <id>`).

  python3 tools/conformance.py [--out <path>] [--date YYYY-MM-DD]
      writes the report (default `docs/CONFORMANCE-<date>.md`) from the engine manifests under corpus/witnesses/ (bsv-rs,
      go-sdk, ts-sdk, sv-node; GoBDK's since its record half, 2026-09-27),
      the classifier tables under harness/rules/ and git; REFUSES (exit 1, nothing written) when a manifest carries an
      engine message or node reason outside the drivers' tables, or a class row whose class is not in its engine's table
  python3 tools/conformance.py [--replay-record <docs/records/…>]
      the page names the record of the replay of every witness it cites (`tools/witness.sh` on each id), which it ships with
  python3 tools/conformance.py --ids
      prints every witness id the report cites (one per line), for `tools/witness.sh` replays
  python3 tools/test_conformance.py
      checks complete instance receipt replacements and refusal of changed hashes, another corpus or missing coverage

The classification column (#30's "spec-wrong vs implementation-wrong"): IMPLEMENTATION-WRONG is a class ruled
`impl-wrong` (the reference and the spec agree; the implementation differs); SPEC-SIDE is any class where the REFERENCE
(sv-node) disagrees with the spec (CLAUDE.md rule 4: a spec bug until a human proves otherwise from source; its ruling
and its note say which side of the spec's scope it sits); OPEN is an implementation's class nobody has ruled (D8)."""
import json, os, subprocess, sys, datetime, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# D135 (the owner's ruling of 2026-09-27): the report REDACTS every witness of a class under a
# still-PRIVATE advisory until the advisory publishes. go-sdk's private report of 2026-09-25 is still a draft and covers
# its eight classes of that day (go-sdk's divergence classes in corpus/witnesses/go-sdk/ at 6d20d90, the harness's own
# engine.timeout aside; the plan's PUBLIC-FACTS-2026-09-25 row 3); ts-stack's is published (@bsv/sdk 2.8.8), nothing of it
# redacted. A class S4b files under D135 joins this set on its word; a class leaves it when its advisory publishes.
# go-sdk's sighash.original.truncated-push joined on S4b's word of #51 (comment 5897916282, 2026-09-29): at v1.7.0 its six
# gen entries, withheld under sighash.type.chronicle-bit at v1.5.2, abort in the original digest and stay withheld.
PRIVATE = {"go-sdk": {"expansion.rshiftnum.negative-rounding", "expansion.shift.count-bigint", "flags.version-gate.absent",
                      "limits.maxscriptnumlength", "sighash.dispatch.forkid-bit-without-flag", "sighash.must-use-forkid",
                      "sighash.type.chronicle-bit", "splice.substr.int64-reader", "sighash.original.truncated-push"},
           # S4b's D135 filing of 2026-09-28: ts-stack GHSA-q2qf-rxpc-p222 (private, filed 11:36:57 UTC; the filing record
           # docs/records/20260928-114104-d135-filing-s4b.md; S4b's A15)
           "ts-sdk": {"tx.default-mode.locktime-nops"}}
# PENDING (D135): a class recorded after the drafts, withheld until S4b judges it related or unrelated (a related one moves to
# PRIVATE when S4b files it; an unrelated one leaves this set on S4b's judgment). EMPTY since 2026-09-28 (S4b's A15; the
# judgement, docs/records/20260927-170817-d135-sdk-classes-s4b.md): ts-sdk's tx.default-mode.locktime-nops FILED (PRIVATE
# above), ts-sdk's tx.locktime.discouraged fixed at 2.8.8 by the published advisory's own patch, and
# limits.maxscriptnumlength.policy (ts-sdk and go-sdk) unrelated, a node policy setting.
PENDING = {}
ENGINES = [("bsv-rs", "corpus/witnesses/manifest.json", "harness/rules/bsv-rs.json"),
           ("go-sdk", "corpus/witnesses/go-sdk/manifest.json", "harness/rules/go-sdk.json"),
           ("ts-sdk", "corpus/witnesses/ts-sdk/manifest.json", "harness/rules/ts-sdk.json"),
           # the GoBDK shim's column (#28, D14: a column, never the gate; 2026-09-27), once its record run exists
           ("gobdk", "corpus/witnesses/gobdk/manifest.json", "harness/rules/gobdk.json"),
           ("sv-node", "corpus/witnesses/sv-node/manifest.json", "harness/rules/sv-node.json")]
ENGINES = [e for e in ENGINES if os.path.exists(os.path.join(ROOT, e[1]))]  # an engine with no manifest yet has no column
# The Teranode INSTANCE's column (#41, #28; S3, lane harness-b-41-s7, 2026-10-06): read from the adapter's manifests under
# harness/engines/instance41/runs/<run>/[<corpus>/]chunk-*.manifest.json, never typed (D83c). Only `chunk-*` files are of
# record; a superseded take keeps a prefixed name beside them (`wall-1-…`, `run-1-rebinding-…`) and is not read. Its rows
# compare the node with the REFERENCE's recorded verdicts, not with the spec, so it has no class rows (§2, §3) and is not
# counted among the implementations of the page's first sentence. The manifests do not carry the reference keys; they are
# the adapter's constants (harness/src/bin/run_teranode.rs:531-535).
INSTANCE_RUNS = "harness/engines/instance41/runs"
# S3's later corpus measurements retain the instance lane's receipts unchanged.
# The index checks both receipt hashes and the corpus identity; the coverage
# checks below still require a complete run.
INSTANCE_REPLACEMENTS = "corpus/instances/teranode/manifest.json"
INSTANCE_REF = {"block": "sv-node@v1.2.2", "mempool": "sv-node-mempool@v1.2.2"}
# every `undecided` and `unfundable` reason a manifest carries falls in exactly one row (the first whose needle it holds) or
# the page is REFUSED: a new reason grows this table first. A node fault is a reason, never a verdict and never a class (D15).
INSTANCE_UNDECIDED = [
    ("outpoint rebinding can change a signature digest", "a signature row: the adapter rebinds outpoints and does not re-sign, because no entry carries its keys", False),
    ("absolute locktime or sequence cannot be rebased", "an absolute locktime or sequence row (tracker comment 5853443740)", False),
    ("CLTV/CSV absolute-height/time row", "a CLTV/CSV row (tracker comment 5853443740)", False),
    ("mixed prevout/spend eras", "a mixed-era row: funding in two era ranges on one chain is not built", False),
    ("era 0: no coinbase output matures", "a pre-Genesis row: no coinbase output matures below the regtest Genesis height", False),
    ("a coinbase-shaped entry", "a coinbase-shaped row: judged as a block's coinbase, and `submitblock` is unimplemented at the pin", False),
    ("Exception thrown from C++ code", "an engine exception on the spend (`UNKNOWN (0): Exception thrown from C++ code`)", True),
    ("ResourceExhausted", "the node's validator gRPC limit of 4 MiB (`ResourceExhausted`)", True),
    ("submission road stopped after a block-context transport failure", "not submitted after the block path's transport failure", True),
    ("deadlock persisted", "the node's store: `STORAGE_ERROR (69): [Spend] deadlock persisted after 3 retries`", True),
    ("failed to decorate previous outputs", "the node could not decorate the previous outputs (a null outpoint)", True)]
INSTANCE_UNFUNDABLE = [
    ("Exception thrown from C++ code", "an engine exception at funding (`UNKNOWN (0): Exception thrown from C++ code`; the record's **Finding.**)", True),
    ("bad-txns-vout-p2sh", "the funding transaction refused with `TX_INVALID (31): bad-txns-vout-p2sh`", True),
    ("TX_MISSING_PARENT", "the null outpoint's parent is missing (`TX_MISSING_PARENT (34)`)", True)]
ORDER = ["seed", "flow", "arith", "stack", "crypto", "bytes", "eras", "gen", "tx", "million"]
NUMBER = {3: "three", 4: "four", 5: "five", 6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten", 11: "eleven", 12: "twelve"}   # the page's first sentence counts the engines with a manifest and the corpora they ran


def load(p):
    return json.load(open(os.path.join(ROOT, p), encoding="utf-8"))


def git(*a):
    return subprocess.run(["git", "-C", ROOT, *a], capture_output=True, text=True).stdout.strip()


def agree_of(engine, c):
    if engine == "bsv-rs":
        return {"spec": c.get("agree_block"), "spec-mempool": c.get("agree_mempool")}, c.get("undecided")
    return dict(c.get("agree") or {}), c.get("undecided_runs")


def aborts_of(c):
    # the runs a driver filed as witnesses under D15 (run_engine.rs's manifest; R3 on #32 counts the SDK decode refusals among them)
    if "aborts_as_witnesses" not in c:
        return "–"
    n, dr = c.get("aborts_as_witnesses") or 0, c.get("decode_refusals") or 0
    return f"{n} ({dr} decode refusals, R3)" if dr else f"{n}"


def pin_of(engine, c):
    if engine == "bsv-rs":
        return c.get("bsv-rs") or "bsv-rs"
    if engine == "sv-node":
        return c.get("node") or "sv-node"
    return c.get("engine") or engine


def classification(engine, ruling):
    if engine == "sv-node":
        return "SPEC-SIDE"
    return "IMPLEMENTATION-WRONG" if ruling == "impl-wrong" else "OPEN"


def instance_manifest_files(refusals):
    import hashlib
    base = os.path.join(ROOT, INSTANCE_RUNS)
    files = sorted(glob.glob(os.path.join(base, "*", "chunk-*.manifest.json")) + glob.glob(os.path.join(base, "*", "*", "chunk-*.manifest.json")))
    record = None
    if os.path.exists(os.path.join(ROOT, INSTANCE_REPLACEMENTS)):
        index = load(INSTANCE_REPLACEMENTS)
        record = index["record"]
        for old, replacement in index["replacements"].items():
            old_path = os.path.join(ROOT, old)
            new_path = os.path.join(ROOT, replacement["file"])
            try:
                if old_path not in files:
                    raise ValueError("superseded receipt is not an active instance manifest")
                with open(old_path, "rb") as stream:
                    old_bytes = stream.read()
                with open(new_path, "rb") as stream:
                    new_bytes = stream.read()
                for data, expected in ((old_bytes, replacement["superseded_sha256"]), (new_bytes, replacement["sha256"])):
                    if hashlib.sha256(data).hexdigest() != expected:
                        raise ValueError("receipt sha256 differs from the replacement index")
                if json.loads(old_bytes)["corpus"]["path"] != json.loads(new_bytes)["corpus"]["path"]:
                    raise ValueError("replacement names another corpus")
                files[files.index(old_path)] = new_path
            except (OSError, ValueError, KeyError) as error:
                refusals.append(f"instance replacement/{old}: {error}")
    return files, record


def instance_section(refusals):
    """The instance's lines for §1, from its manifests; [] when it has none."""
    import hashlib
    files, replacement_record = instance_manifest_files(refusals)
    if not files or refusals:
        return []
    corpora, ident, chains, fold, records = {}, {}, {}, {}, [replacement_record] if replacement_record else []
    for f in files:
        m = json.load(open(f, encoding="utf-8"))
        rel = os.path.relpath(f, ROOT)
        name = m["corpus"]["path"].split("/")[1]
        c = corpora.setdefault(name, {"entries": m["corpus"]["manifest_count"], "chunks": [], "counts": {}, "sha": hashlib.sha256(open(f, "rb").read()).hexdigest()})
        if c["entries"] != m["corpus"]["manifest_count"]:
            refusals.append(f"instance/{name}: chunk manifests disagree on the corpus's entry count")
        c["chunks"].append((m["corpus"]["run_from"], m["corpus"]["run_count"], rel))
        for path, n in m["counts"].items():
            t = c["counts"].setdefault(path, {})
            for k, v in n.items():
                t[k] = t.get(k, 0) + v
        inst = m["instance"]
        for k in ("tag", "commit", "binary_sha256", "native_client_sha256", "host"):
            ident.setdefault(k, set()).add(inst.get(k))
        ident.setdefault("block", set()).add(m["paths"]["block"])
        ident.setdefault("regtest", set()).add(json.dumps(m["mapping"]["regtest"], sort_keys=True))
        ident.setdefault("basis", set()).add(m["mapping"]["basis"])
        ch = chains.setdefault(inst["settings_hash"], {"settings": inst["settings"], "corpora": [], "tips": []})
        if name not in ch["corpora"]:
            ch["corpora"].append(name)
        ch["tips"] += [m["initial_tip"]["blocks"], m["final_tip"]["blocks"]]
        for kind, table, rows in (("undecided", INSTANCE_UNDECIDED, m["undecided"]), ("unfundable", INSTANCE_UNFUNDABLE, m["unfundable"])):
            for r in rows:
                hit = next((t for t in table if t[0] in r["reason"]), None)
                if hit is None:
                    refusals.append(f"instance/{name}: {kind} reason outside the table: `{r['reason'][:120]}`")
                    continue
                b = fold.setdefault((kind, hit[1]), {"by_id": hit[2], "n": {}, "ids": []})
                b["n"][(name, r["path"])] = b["n"].get((name, r["path"]), 0) + 1
                b["ids"].append((r["id"], r["path"]))
                c["counts"][r["path"]].setdefault("_" + kind, 0)
                c["counts"][r["path"]]["_" + kind] += 1
    for k, v in ident.items():
        if len(v) != 1:
            refusals.append(f"instance: the manifests disagree on `{k}` ({len(v)} values)")
    for name, c in corpora.items():
        at = 0
        for frm, cnt, rel in sorted(c["chunks"]):
            if frm != at:
                refusals.append(f"instance/{name}: chunks leave a gap or overlap at entry {at} ({rel})")
            at = frm + cnt
        if at != c["entries"]:
            refusals.append(f"instance/{name}: chunks cover {at} of {c['entries']} entries")
        for path, t in c["counts"].items():
            for kind in ("undecided", "unfundable"):
                if t.get(kind, 0) != t.get("_" + kind, 0):
                    refusals.append(f"instance/{name}/{path}: `{kind}` counts {t.get(kind, 0)} but the manifest names {t.get('_' + kind, 0)}")
            if sum(t.get(k, 0) for k in ("agreeing", "disagreeing", "unfundable", "undecided", "no_reference")) != t["entries"]:
                refusals.append(f"instance/{name}/{path}: the counts do not sum to the entries")
    one = {k: next(iter(v)) for k, v in ident.items()}
    tag, ref_b, ref_m = one["tag"], INSTANCE_REF["block"], INSTANCE_REF["mempool"]
    L = ["### teranode-instance (#41, #28)", "",
         f"The node itself, not its engine alone: Teranode `{tag}` at `{one['commit']}`, run on the {one['host']} under its test settings¹. "
         f"Its columns compare the node's answers with the REFERENCE's verdicts recorded in each corpus (`{ref_b}` for `block`, `{ref_m}` for `mempool`), "
         f"not with the spec; the classifier has not read them (no disagreement to classify). `unfundable`: the node refused to create the entry's "
         f"previous outputs³; `undecided`: no verdict, by name in the manifest². Written by `tools/conformance.py` from the manifests under `{INSTANCE_RUNS}/`"
         + (f" and the checked replacements indexed by `{INSTANCE_REPLACEMENTS}`." if replacement_record else "."), "",
         "| corpus | entries | the implementation | compared with | column | agree | disagree | unfundable | undecided | the manifest's sha256 |",
         "|---|---|---|---|---|---|---|---|---|---|"]
    for name in [c for c in ORDER if c in corpora] + sorted(c for c in corpora if c not in ORDER):
        c = corpora[name]
        sha = f"{len(c['chunks'])} chunk manifests" if len(c["chunks"]) > 1 else f"`{c['sha'][:12]}…`"
        for i, path in enumerate(p for p in ("block", "mempool") if p in c["counts"]):
            t = c["counts"][path]
            nr = f" (+{t['no_reference']} without a recorded reference)" if t.get("no_reference") else ""
            L.append(f"| `corpus/{name}` | {c['entries'] if i == 0 else ''} | {'teranode@' + tag if i == 0 else ''} | {ref_b + ' (recorded)' if i == 0 else ''} | `{path}` | "
                     f"{t['agreeing']} | {t['disagreeing']}{nr} | {t['unfundable']} | {t['undecided']} | {sha if i == 0 else ''} |")
    order = sorted(chains.items(), key=lambda kv: -len(kv[1]["corpora"]))
    main_h, main_c = order[0]

    def flat(d, pre=""):
        out = {}
        for k, v in d.items():
            out.update(flat(v, f"{pre}{k}.") if isinstance(v, dict) else {f"{pre}{k}": json.dumps(v)})
        return out
    others = []
    for h, ch in order[1:]:
        a, b = flat(main_c["settings"]), flat(ch["settings"])
        diff = sorted(k.split(".")[-1] for k in set(a) | set(b) if a.get(k) != b.get(k))
        others.append(f"the `{'`, `'.join(ch['corpora'])}` run's chain: `{h[:16]}…`, differing in {', '.join('`' + d + '`' for d in diff)}")
    rt = json.loads(one["regtest"])
    chain_words = "; ".join(f"`{'`, `'.join(ch['corpora'])}` on the chain of settings hash `{h[:8]}…` (tips {min(ch['tips'])} to {max(ch['tips'])})" for h, ch in order)
    for f in sorted(glob.glob(os.path.join(ROOT, "docs", "records", "*-instance41-seed.md")) + glob.glob(os.path.join(ROOT, "docs", "records", "*-instance41-corpora.md"))):
        records.append(os.path.relpath(f, ROOT))
    runs = sorted({os.path.dirname(x[2]) for c in corpora.values() for x in c["chunks"]})
    L += ["", f"¹ Binary sha256 `{one['binary_sha256']}`; settings hash `{main_h}`" + (f" ({'; '.join(others)})" if others else "") +
          f"; native validator client `{one['native_client_sha256']}`; regtest at the heights the manifests name (Genesis {rt['genesis']}, Chronicle {rt['chronicle']}, "
          f"coinbase maturity {rt['coinbase_maturity']}; {one['basis']}): {chain_words}. The manifests: " + ", ".join(f"`{r}/`" for r in runs) +
          "; the records " + " and ".join(f"`{r}`" for r in records) + ". THE LIMIT: the `block` column is the node's validator call, "
          f"not a block's acceptance (the manifests' `paths.block`: \"{one['block']}\").", ""]
    for mark, kind, table in (("²", "undecided", INSTANCE_UNDECIDED), ("³", "unfundable", INSTANCE_UNFUNDABLE)):
        L.append(f"{mark} `{kind}`, by reason, from the manifests' `{kind}` fields (a corpus's count stands for both paths unless split by path; "
                 "an engine or node fault is a reason, never a verdict nor a class, D15):")
        for label in dict.fromkeys(t[1] for t in table):
            b = fold.get((kind, label))
            if b is None:
                continue
            per = {}
            for (cn, path), n in b["n"].items():
                per.setdefault(cn, {})[path] = n
            cells = []
            for cn in [c for c in ORDER if c in per] + sorted(c for c in per if c not in ORDER):
                p = per[cn]
                cells.append(f"`{cn}` {p.get('block', 0)}" if p.get("block", 0) == p.get("mempool", 0) else f"`{cn}` block {p.get('block', 0)} · mempool {p.get('mempool', 0)}")
            ids = ""
            if b["by_id"]:
                by = {}
                for i, path in b["ids"]:
                    by.setdefault(i, []).append(path)
                ids = "; " + ", ".join(f"`{i}`" + ("" if len(ps) == 2 else f" ({ps[0]})") for i, ps in sorted(by.items()))
            total = len({i for i, _ in b["ids"]})
            L.append(f"- {label}: {total} entr{'y' if total == 1 else 'ies'}; " + ", ".join(cells) + ids)
        L.append("")
    return L


CPP_REPLAY = "corpus/cpp/replay"


def cpp_section():
    """#49 items 2 and 3: the reference's C++ unit tables (`corpus/cpp`), one row per file. Every number is read: the file's
    entries from `corpus/cpp/manifest.json`; what has a spend form, what is undecided and what is not replayable from the
    projection's ledger (`corpus/cpp/replay/<name>/ledger.json`, `tools/cpp_replay.py`); the columns' agreements and classified
    runs from the bsv-rs and sv-node manifests (the corpus `cpp-<stem>`); the node against the unit's own assertion from the
    ledger's `judge` (`tools/cpp_replay.py judge`). [] when the family has no ledger yet."""
    base = os.path.join(ROOT, CPP_REPLAY)
    if not os.path.isdir(base):
        return []
    cm = {f["file"]: f for f in load("corpus/cpp/manifest.json")["files"]}
    bm = load("corpus/witnesses/manifest.json")
    sm = load("corpus/witnesses/sv-node/manifest.json") if os.path.exists(os.path.join(ROOT, "corpus/witnesses/sv-node/manifest.json")) else {}
    L = ["### the reference's C++ unit tables (`corpus/cpp`, #49), per file", "",
         "Each file of `corpus/cpp` (unit tables harvested at bitcoin-sv v1.2.2, `879fc8b42`, retained as a historical source snapshot) is projected by `tools/cpp_replay.py` "
         "into spends where a spend runs the same computation (an `EvalScript` call's stack rebuilt by minimal pushes in the unlocking "
         "script; a `VerifyScript` call; the `CheckInputs` and `CScriptCheck` predicates), each under the call's own flag word, and run "
         "through the four columns: the spec (`eval/bsvs corpus`), bsv-rs (`run_diff`), the node's consensus instance and its policy "
         "instance (`run_svnode`). The `spec` column is the call's word on the consensus instrument; `spec-mempool` is the relay word of "
         "the projected heights on the policy instance, a differential of its own and not the unit's call. Every other entry is "
         "undecided by name (the reason per entry in the file's ledger); `replayable: false` entries are counted apart. The last "
         "column is the node's `spec` verdict against what the C++ check asserts (rule 15: a disagreement is the reference against "
         "itself, recorded and never adjusted). That assertion comparison remains the ledger's historical `sv-node@v1.2.2` column; "
         "the active script comparisons in this table and above use the joined spec keys and `sv-node@v1.2.3`.", "",
         "| file | entries | a spend form | undecided | not replayable | bsv-rs: agree `spec` · `spec-mempool` · classified · the call's word in the crate's scope | sv-node: agree `spec` · `spec-mempool` · classified | the node vs the unit's assertion: agree · disagree · no assertion |",
         "|---|---|---|---|---|---|---|---|"]
    tot = [0] * 14
    for name in sorted(os.listdir(base)):
        lp = os.path.join(base, name, "ledger.json")
        if not os.path.exists(lp):
            continue
        led = json.load(open(lp, encoding="utf-8"))
        f = os.path.basename(led["source"])
        n = cm.get(f, {}).get("count")
        und = sum(led["undecided"].values())
        # the file's corpora: its own, and one per node configuration for the calls with their own chain context (the ledger's
        # `corpora`, lane cpp-era-49); a manifest figure is summed over them, None when no corpus of the file has a row
        corpora = led.get("corpora") or [name]
        bs = [bm[c] for c in corpora if c in bm]
        vs = [sm[c] for c in corpora if c in sm]
        def total(rows, pick):
            return sum(int(pick(r) or 0) for r in rows) if rows else None
        bcl = total(bs, lambda r: sum(int(x.get("entries") or 0) for x in r.get("rules") or []))
        vcl = total(vs, lambda r: sum(int(x.get("entries") or 0) for x in r.get("rules") or []))
        j = (led.get("judge") or {}).get("asserted") or {}
        cells = [n, led["projected"], und, led["not_replayable"],
                 total(bs, lambda r: r.get("agree_block")), total(bs, lambda r: r.get("agree_mempool")), bcl,
                 total(vs, lambda r: (r.get("agree") or {}).get("spec")), total(vs, lambda r: (r.get("agree") or {}).get("spec-mempool")), vcl,
                 j.get("agree"), j.get("disagree"), j.get("none"), (led.get("judge") or {}).get("bsvrs_word_in_scope")]
        for i, c in enumerate(cells):
            tot[i] += c or 0
        fmt = lambda x: "–" if x is None else f"{x:,}"
        L.append(f"| `corpus/cpp/{f}` | {fmt(cells[0])} | {fmt(cells[1])} | {fmt(cells[2])} | {fmt(cells[3])} | "
                 f"{fmt(cells[4])} · {fmt(cells[5])} · {fmt(cells[6])} · {fmt(cells[13])} | {fmt(cells[7])} · {fmt(cells[8])} · {fmt(cells[9])} | "
                 f"{fmt(cells[10])} · {fmt(cells[11])} · {fmt(cells[12])} |")
    L.append(f"| the family | {tot[0]:,} | {tot[1]:,} | {tot[2]:,} | {tot[3]:,} | {tot[4]:,} · {tot[5]:,} · {tot[6]:,} · {tot[13]:,} | "
             f"{tot[7]:,} · {tot[8]:,} · {tot[9]:,} | {tot[10]:,} · {tot[11]:,} · {tot[12]:,} |")
    L += ["", "(– : no run; a file with no spend form has a ledger and no corpus. The classified runs are the `cpp-<stem>` rows of "
          "§2, each with its citation and its smallest witness. bsv-rs refuses a word without SIGHASH_FORKID, GENESIS or "
          "UTXO_AFTER_GENESIS (`engine.word-out-of-scope`), so on a word outside its scope an agreement is two refusals and not a "
          "judgment; the last bsv-rs figure counts the spends whose word the crate judges. `txvalidationcache_tests`' `CheckInputs` "
          "calls carry their own chain context, so they are projected at the test's own era, one corpus per node configuration "
          "(`cpp-txvalidationcache-t<tip>-g<genesis>-c<chronicle>`, the ledger's `groups`), each run on the lane's own instances "
          "started with those activation heights on a chain of the fixture's shape, the coins read from that chain "
          "(`tools/cpp_era_run.sh`); its row sums them.)", ""]
    return L


def main():
    args = sys.argv[1:]
    date = args[args.index("--date") + 1] if "--date" in args else datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    out = args[args.index("--out") + 1] if "--out" in args else os.path.join(ROOT, "docs", f"CONFORMANCE-{date}.md")
    replay = args[args.index("--replay-record") + 1] if "--replay-record" in args else None
    refusals, sections, classes, ids = [], [], [], []
    qualified = []   # R2 (the owner's ruling on #32, 2026-10-05): the agreements that hold at the instance's activation context only
    excluded = {}    # the block-context rule each such agreement turns on, recorded from source by the manifest (never a run's result)
    for engine, mpath, rpath in ENGINES:
        m, table = load(mpath), load(rpath)
        known = set(table.get("classes", {}))
        rows = []
        for corpus in [c for c in ORDER if c in m] + sorted(c for c in m if c not in ORDER):
            c = m[corpus]
            for k in ("unknown_messages", "unknown_descriptions", "unknown_reasons"):
                if c.get(k):
                    refusals.append(f"{engine}/{corpus}: `{k}` is not empty ({len(c[k])}): a driver's table must grow first")
            agree, undecided = agree_of(engine, c)
            for col, k in (c.get("agree_instance_qualified") or {}).items():
                ctx = c.get("activation_context") or {}
                qualified.append({"engine": engine, "corpus": corpus, "column": col, "entries": k, "ctx": ctx,
                                  "ids": [(q.get("id"), q.get("verdict")) for q in c.get("instance_qualified") or [] if q.get("column") == col]})
                if ctx.get("excluded_rule"):
                    excluded[ctx["excluded_rule"]] = ctx
            classified = {}
            for r in c.get("rules") or []:
                classified[r.get("column")] = classified.get(r.get("column"), 0) + int(r.get("entries") or 0)
                cls = r.get("rule")
                if cls not in known and not cls.startswith("engine."):
                    refusals.append(f"{engine}/{corpus}: class `{cls}` is not in `{rpath}`")
                cdef = table.get("classes", {}).get(cls, {})
                ruling = r.get("ruling") or cdef.get("ruling") or ("mechanism" if cls.startswith("engine.") else "")
                wid = r.get("witness") or ""
                ids.append(wid)
                classes.append({"engine": engine, "corpus": corpus, "column": r.get("column"), "class": cls, "entries": r.get("entries"),
                                "ruling": ruling, "witness": wid, "from": r.get("from"),
                                # the classifier's CURRENT text first (D83: the table is the data; a manifest row carries a copy of it as
                                # of its recording, rules.rs's Explanation), the copy only for a class the table no longer defines
                                "decided_by": cdef.get("decided_by") or r.get("decided_by") or "",
                                "kind": "MECHANISM" if cls.startswith("engine.") else classification(engine, ruling)})
            cols = sorted(set(agree) | set(classified))
            rows.append((corpus, c.get("entries"), c.get("spec"), pin_of(engine, c), c.get("sha256"), c.get("file"), agree, undecided, classified, cols,
                         c.get("witnesses"), aborts_of(c)))
        sections.append((engine, rows))
    if "--ids" in args:
        print("\n".join(sorted(set(i for i in ids if i))))
        return 0
    if refusals:
        print("conformance: REFUSED (nothing written):\n  " + "\n  ".join(refusals))
        return 1
    reference_manifest = load("corpus/witnesses/sv-node/manifest.json") if any(e[0] == "sv-node" for e in ENGINES) else {}
    reference_keys = sorted({key for c in reference_manifest.values() for key in (c.get("node"),
                            c.get("node", "").replace("sv-node@", "sv-node-mempool@")) if key})
    reference_text = " / ".join(f"`{key}`" for key in reference_keys)
    node_spec_keys = sorted({key for c in reference_manifest.values() for key in (c.get("spec_recorded_keys") or {}).values()})
    node_spec_text = " / ".join(f"`{key}`" for key in node_spec_keys)
    historic_path = "corpus/witnesses/sv-node-v1.2.2/manifest.json"
    historic = load(historic_path) if os.path.exists(os.path.join(ROOT, historic_path)) else {}
    historical_reader_counts = {name: sum(int(r.get("entries", 0)) for r in historic.get(name, {}).get("rules", [])
                               if r.get("column") == "spec" and r.get("rule") == "reference.v1.2.3.int64-overflow") for name in ("gen", "road")}
    inst = instance_section(refusals)
    has_instance = bool(inst)
    if refusals:
        print("conformance: REFUSED (nothing written):\n  " + "\n  ".join(refusals))
        return 1
    head = git("rev-parse", "--short", "HEAD")
    n_corpora = len({r[0] for _, rows_ in sections for r in rows_})   # counted, never written by hand (the tenth, corpus/million, 2026-09-28)
    L = [f"# The conformance report of {date} (#30)", "",
         f"**What this page stands for.** Every disagreement between the spec's evaluator and {NUMBER.get(len(sections), len(sections))} implementations of BSV script, "
         f"on the {NUMBER.get(n_corpora, n_corpora)} generated corpora, at the commit `{head}`, each with its class, the citation that decides it and its smallest "
         f"witness, reproducible by one command (`tools/witness.sh <witness-id>`). Written by `tools/conformance.py` from the engine "
         f"manifests under `corpus/witnesses/` and the classifier tables under `harness/rules/` (D83c); nothing on this page is "
         f"decided here. The drivers are RED on a divergence no table explains and `rules_check` (the tripwire's harness leg) "
         f"replays the go-sdk, ts-sdk, gobdk and sv-node manifests from their recorded verdicts and bsv-rs's live, including the combined gate/script tx road and its separate BIP34-context agreements. Every divergence below is classified `[X]`; the two recorded tx finality disagreements remain SPEC-SIDE under `tx.finality.out-of-scope`." + (f" Every witness this page cites was REPLAYED through `tools/witness.sh`: the record `{replay}`." if replay else " The witnesses' replay record: NOT YET (a page without one does not ship)."), "",
         "**The classification** (#30's spec-wrong vs implementation-wrong). IMPLEMENTATION-WRONG: the reference and the spec agree, "
         "the implementation differs (a class ruled `impl-wrong`). SPEC-SIDE: the REFERENCE disagrees with the spec (CLAUDE.md rule 4: "
         "a spec bug until a human proves otherwise from source; the class's note says whether the rule sits outside the spec's scope "
         "or is a gap in it). OPEN: an implementation's class ruled open by the owner (a mode or a node's policy setting, never a "
         "consensus divergence) or one nobody has ruled yet (D8). MECHANISM: an engine abort or timeout filed as a witness (D15), never "
         "counted as agreement and never as an undecided run as well; its ruling column carries its disposition. An SDK's refusal to "
         "decode a transaction the reference decides is such an abort (`engine.decode-refusal`, the owner's ruling R3 on #32, "
         "2026-10-05): implementation-wrong, the engine's script status undecided, the spec's script verdict kept. A script verdict "
         "is not a transaction's validity: that class does not establish an engine failure on a transaction the reference would "
         "accept. The ts-sdk's `default/…` columns are its default mode (@bsv/sdk without `verifyFlags`): their classes are scoped "
         "to that mode, the four consensus omissions of the mode ruled implementation-wrong and its policy-only omissions kept "
         "apart as OPEN (the owner's ruling R4 on #32, 2026-10-05).", "",
         "## 1. The runs, per implementation, per corpus, per column", ""]
    for engine, rows in sections:
        if engine == "sv-node" and inst:
            L += inst
            inst = []
        L += [f"### {engine}", ""]
        if engine in ("go-sdk", "ts-sdk", "gobdk"):
            compared_specs = sorted({key for row in rows for key in (row[2], row[2].replace("spec@", "spec-mempool@"))})
            compared_text = " / ".join(f"`{key}`" for key in compared_specs)
            L += [f"The recorded implementation keys in the table are compared with {compared_text}. "
                  f"The current node reference keys are {reference_text}. Prior v1.2.2 comparisons remain in the "
                  "manifests' histories; these full SDK columns were reclassified offline with original implementation verdicts retained.", ""]
        elif engine == "sv-node":
            L += [f"The current reference columns are {reference_text}, compared with {node_spec_text} from the rebuilt evaluator. "
                  "The tx and road columns include its transaction gate. " +
                  ("The reading of record at v1.2.3 is a defined refusal ([SRC] `int_serialization.h:61\u2013118`, `script_num.cpp:80\u201391` at `6504a3af`); the previous pin's reading and its measurements are recorded in material withheld from the public edition at the maintainers' request (group `d8-node-team-discretion`). ") +
                  "The recorded block tx finality scope boundary remains separately classified.", ""]
        L += ["| corpus | entries | the implementation | the spec | column | agree | classified | undecided (the corpus) | aborts filed as witnesses (D15; the corpus) | the witness file's sha256 (the manifest's) |", "|---|---|---|---|---|---|---|---|---|---|"]
        for corpus, n, spec, pin, sha, f, agree, und, clsd, cols, wit, ab in rows:
            for i, col in enumerate(cols):
                L.append(f"| `corpus/{corpus}` | {n if i == 0 else ''} | {pin if i == 0 else ''} | {spec if i == 0 else ''} | `{col}` | {agree.get(col, '–')} | {clsd.get(col, 0)} | {und if i == 0 else ''} | {ab if i == 0 else ''} | {('`' + (sha or '')[:12] + '…`') if i == 0 else ''} |")
        L.append("")
        rows_q = [q for q in qualified if q["engine"] == engine]
        if rows_q:
            L += [f"**{engine}: the agreements at the instance's activation context only** (the owner's ruling R2 on #32, 2026-10-05). "
                  "The `agree` column above counts the ordinary agreements; these are counted apart, never in it: each is a recorded "
                  "verdict of the instance that would move at mainnet's activation height of the rule named.", "",
                  "| corpus | column | agree at the instance's context only | the entries (the recorded verdict) | the instance's BIP34 height | mainnet's |", "|---|---|---|---|---|---|"]
            for q in rows_q:
                ctx = q["ctx"]
                L.append(f"| `corpus/{q['corpus']}` | `{q['column']}` | {q['entries']} | " + ", ".join(f"`{i}` ({v})" for i, v in q["ids"])
                         + f" | {ctx.get('bip34_height', '–'):,} ({ctx.get('bip34_source', '')}) | {ctx.get('mainnet_bip34_height', '–'):,} ({ctx.get('mainnet_bip34_source', '')}) |")
            L.append("")
    L += inst
    L += cpp_section()
    L += ["## 2. Every class, with its citation and its smallest witness", "",
          "A class under a still-private security advisory is WITHHELD on this page until the advisory publishes (D135): its row keeps "
          "its kind, its ruling, its corpus and column and its count; its name, its witness and its citation are withheld.", ""]
    withholding_path = "corpus/witnesses/withholding-history.json"
    withholding = load(withholding_path) if os.path.exists(os.path.join(ROOT, withholding_path)) else {}
    if withholding:
        L += [f"The published redacted rows below are retained verbatim from `{withholding.get('source_page')}` at "
              f"`{withholding.get('source_commit')}`. They are historical placeholders: their counts belong to that page's "
              "previous comparison keys. Current classified counts are in §1 and in the active engine manifests. "
              "No current private class name, witness or citation is printed here.", ""]
    for engine, _ in sections:
        rows = [c for c in classes if c["engine"] == engine]
        L += [f"### {engine} ({len(rows)} class rows)", "", "| class | kind | ruling | corpus · column | entries | smallest witness (replay: `tools/witness.sh <id>`) | decided by |", "|---|---|---|---|---|---|---|"]
        for c in sorted(rows, key=lambda x: (x["kind"], x["class"], x["corpus"], x["column"] or "")):
            if c["class"] in PRIVATE.get(engine, ()):
                if engine in withholding.get("rows_by_engine", {}):
                    continue
                L.append(f"| (a class under a still-private advisory: withheld, D135) | {c['kind']} | {c['ruling']} | `{c['corpus']}` · `{c['column']}` | {c['entries']} | (withheld until the advisory publishes) | (withheld) |")
                continue
            if c["class"] in PENDING.get(engine, ()):
                L.append(f"| (a class under D135's judgment: withheld until it is judged) | {c['kind']} | {c['ruling']} | `{c['corpus']}` · `{c['column']}` | {c['entries']} | (withheld) | (withheld) |")
                continue
            L.append(f"| `{c['class']}` | {c['kind']} | {c['ruling']} | `{c['corpus']}` · `{c['column']}` | {c['entries']} | `{c['witness']}` | {c['decided_by'].replace('|', '/')} |")
        prior_rows = withholding.get("rows_by_engine", {}).get(engine, [])
        if prior_rows:
            L += ["", f"**{engine}: the preserved historical redaction rows.** The following counts belong to the "
                  "previous page; the current classified totals are in §1.", "",
                  "| class | kind | ruling | corpus · column | historical entries | smallest witness | decided by |",
                  "|---|---|---|---|---|---|---|", *prior_rows]
        L.append("")
    by = {}
    for c in classes:
        by.setdefault((c["engine"], c["kind"]), set()).add(c["class"])
    L += ["## 3. The counts", "", "| implementation | IMPLEMENTATION-WRONG | SPEC-SIDE | OPEN | MECHANISM |", "|---|---|---|---|---|"]
    for engine, _ in sections:
        L.append(f"| {engine} | " + " | ".join(str(len(by.get((engine, k), ()))) for k in ("IMPLEMENTATION-WRONG", "SPEC-SIDE", "OPEN", "MECHANISM")) + " |")
    L += ["", "(distinct classes per implementation; a class seen in several corpora or columns is counted once here and listed per row in §2)", "",
          "## 4. Not in this report", "",
          ("" if has_instance else "Teranode's INSTANCE column (#41: the node itself, waiting on the owner's item A2; its script engine is in this report as the "
          "GoBDK column, #28, D14: a column, never the gate). ") + "The mutators and the random scripts (#26's remaining families); "
          + ("the entries of the reference's C++ unit tables that have no spend form (§1's `corpus/cpp` table: the undecided column, "
             "each entry's reason in its file's ledger)." if os.path.isdir(os.path.join(ROOT, CPP_REPLAY)) else "the reference's C++ unit tables (lean #49)."), ""]
    for rule in sorted(excluded):
        ctx = excluded[rule]
        L += [f"**Excluded from the transaction gate, from source, not measured `[SRC]`:** {rule}. "
              f"The recorded reference context is {ctx.get('instance')}. Mainnet's BIP34 height is "
              f"{ctx.get('mainnet_bip34_height'):,} ({ctx.get('mainnet_bip34_source')}); the instance's is "
              f"{ctx.get('bip34_height'):,} ({ctx.get('bip34_source')}). No run of this report executes it; "
              "the agreements that turn on it are listed apart in §1.", ""]
    open(out, "w", encoding="utf-8").write("\n".join(L))
    print(f"conformance: wrote {os.path.relpath(out, ROOT)} ({len(classes)} class rows, {len(set(ids))} witnesses) at {head}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
