#!/usr/bin/env bash
# tools/cpp_extract.sh: the corpus/cpp family (#49): the pinned reference's own C++ unit tables, read by an
# instrumented test_bitcoin. The design is the reader of #49 (comment 5858114786); the contract, the inventory
# and the license note are corpus/cpp/INVENTORY.md.
#
# What it does, in order (a stranger holding the pin regenerates the family from this file and
# corpus/cpp/instrument.patch):
#   1. refuses above a 1-minute load of 20 (CLAUDE.md rule 17);
#   2. checks the pinned files the family reads and the recorder calls against their sha256 at
#      bitcoin-sv v1.2.2 (879fc8b42168dd0e608dafd51b39c6dabad37d4d), read by `git show <commit>:<path>`;
#   3. copies the pinned source to $WORK/src (the pinned tree is never modified in place);
#   4. applies corpus/cpp/instrument.patch (the recorder header, the hooks in the instrumented test files, and one
#      build-compatibility hunk for Boost 1.92, labelled in the inventory);
#   5. configures once (the options of the 2026-09-22 reference build) and builds test_bitcoin at $JOBS jobs;
#   6. runs the suites with CPPX_OUT set, each in its own process under the fixed seed SEED; any Boost failure stops here; a passed run
#      writes its receipt,
#      $WORK/receipt.json: the patch's sha256, the test binary's sha256, the dump's sha256, the seed, the run's
#      date and Boost's own counts (test cases and assertions, all passed), whole and per suite;
#   7. shapes the dump into corpus/cpp/<suite>.jsonl and corpus/cpp/manifest.json, checking that every
#      observed result satisfies what its C++ check asserts and that every table row is found in the source,
#      and writes each suite's receipt, corpus/cpp/receipts/<suite>.txt.
# --shape-only skips 3 to 6 and shapes an earlier dump, and only with that dump's receipt: it refuses unless
# the receipt says passed, names this patch's sha256, the binary now in $WORK/build and the dump now in
# $WORK/raw.jsonl, and counts at least one assertion.
# --verify reads the committed family only (no source, no build, no run): every file against the manifest (its
# sha256, its count, its key-masked digest recomputed from the entries' own `masked` lists), every drawn entry's
# mark, every call entry's stack limit, every citation's shape, and every suite's receipt against the manifest.
# No timing is taken and none is written. Usage: tools/cpp_extract.sh [--shape-only | --verify]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SV_SRC="${SV_SRC:-$HOME/bsv/targets/sv-v1.2.2-src}"
WORK="${WORK:-$HOME/bsv/targets/spec-cpp-extract}"
JOBS="${JOBS:-4}"
PATCH="$ROOT/corpus/cpp/instrument.patch"
OUT="$ROOT/corpus/cpp"
SUITES="bint_tests,bn_op_tests,crypto_tests,cscript_tests,instruction_iterator_tests,int_serialization_tests,limited_stack_vector_tests,lrshiftnum_tests,multisig_tests,opcode_tests,script_tests,scriptnum_tests,sighash_tests,sighashtype_tests,sigopcount_tests,transaction_tests,script_P2SH_tests,test_txnvalidator,txvalidationcache_tests,blockcheck_tests,miner_tests_journal,rpc_tests"
COMMIT=879fc8b42168dd0e608dafd51b39c6dabad37d4d
# the seed of the test framework's own random context (test_bitcoin.cpp:49-61, reset for every fixture at 65-67 and 76):
# fixed, so the draws of InsecureRand* are the same at every run; keys from CKey::MakeNewKey use the strong generator
# and stay drawn at run time (the entries say so)
SEED="${CPPX_SEED:-$COMMIT}"

if [ "${1:-}" = "--verify" ]; then
  exec python3 - "$OUT" "$COMMIT" "$SEED" <<'PY'
import gzip, hashlib, json, os, re, sys
out, commit, seed = sys.argv[1:4]
KEY = "sv-node-unit@v1.2.2"
bad = []
m = json.load(open(f"{out}/manifest.json"))
patch_sha = hashlib.sha256(open(f"{out}/instrument.patch", "rb").read()).hexdigest()
if m["instrument_patch_sha256"] != patch_sha:
    bad.append("manifest: instrument_patch_sha256 is not instrument.patch's")
on_disk = sorted(n for n in os.listdir(out) if n.endswith((".jsonl", ".jsonl.gz")))
if on_disk != sorted(f["file"] for f in m["files"]):
    bad.append(f"the files on disk {on_disk} are not the manifest's")
def stable_line(e):
    # the stable form of an entry: every field its own `masked` list names replaced by "drawn" (the shaper's rule)
    e = json.loads(json.dumps(e))
    for f in e.get("masked", []):
        side, name = f.split(".")
        (e["input"] if side == "input" else e["observed"][KEY])[name] = "drawn"
    return json.dumps(e, separators=(",", ":"), sort_keys=False) + "\n"
total = 0
for f in m["files"]:
    name, stem = f["file"], f["file"].split(".")[0]
    blob = open(f"{out}/{name}", "rb").read()
    data = gzip.decompress(blob) if name.endswith(".gz") else blob
    err = lambda why: bad.append(f"{name}: {why}")
    if hashlib.sha256(blob).hexdigest() != f["sha256_of_file"]:
        err("sha256_of_file")
    if hashlib.sha256(data).hexdigest() != f["sha256"]:
        err("sha256")
    entries = [json.loads(l) for l in data.decode().splitlines()]
    total += len(entries)
    if len(entries) != f["count"]:
        err(f"count {len(entries)} != {f['count']}")
    if "".join(json.dumps(e, separators=(",", ":"), sort_keys=False) + "\n" for e in entries).encode() != data:
        err("not the canonical JSONL")
    if hashlib.sha256("".join(stable_line(e) for e in entries).encode()).hexdigest() != f["sha256_keys_masked"]:
        err("sha256_keys_masked is not the digest of the file with its entries' masked fields replaced")
    drawn = masked = 0
    for k, e in enumerate(entries, 1):
        if e["id"] != f"cpp-{stem[:-len('_tests')] if stem.endswith('_tests') else stem}-{k:05d}":
            err(f"{e['id']}: id out of order")
        if e["source"]["file"] != f["source"] or not isinstance(e["source"]["line"], int) or e["source"]["line"] < 1:
            err(f"{e['id']}: citation")
        if KEY not in e["expect"]:
            err(f"{e['id']}: no expectation")
        if e["kind"] == "evalscript" and not isinstance(e["input"].get("stack_limit"), int):
            err(f"{e['id']}: no stack_limit")
        if e["kind"] == "predicate" and e.get("layer") not in ("consensus", "policy", "both"):
            err(f"{e['id']}: layer {e.get('layer')}")
        d, k2 = "drawn_at_run_time" in e, e.get("masked")
        drawn += d
        masked += bool(k2)
        if d != bool(k2):
            err(f"{e['id']}: drawn_at_run_time and masked do not go together")
        for fld in k2 or []:
            side, _, nm = fld.partition(".")
            if side not in ("input", "observed") or nm not in (e["input"] if side == "input" else e.get("observed", {}).get(KEY, {})):
                err(f"{e['id']}: masked names {fld}, which the entry does not carry")
    if drawn != f["drawn_at_run_time"]:
        err(f"drawn_at_run_time {drawn} != {f['drawn_at_run_time']}")
    if (f["sha256"] == f["sha256_keys_masked"]) != (masked == 0):
        err("the key-masked digest equals the plain one exactly when no entry is masked: not so here")
    # the suite's receipt
    rp = f"{out}/receipts/{stem}.txt"
    if not os.path.exists(rp):
        err(f"no receipt receipts/{stem}.txt")
        continue
    r = dict(l.split(": ", 1) for l in open(rp).read().splitlines() if ": " in l)
    want = {"file": f"corpus/cpp/{name}", "source": f["source"], "pin": f"bitcoin-sv v1.2.2 ({commit})",
            "entries": str(f["count"]), "sha256_keys_masked": f["sha256_keys_masked"],
            "entries_masked": str(masked), "instrument_patch_sha256": patch_sha, "status": "passed"}
    for k, v in want.items():
        if r.get(k) != v:
            err(f"receipt: {k} is {r.get(k)!r}, the manifest gives {v!r}")
    if r.get("sha256") != f["sha256"] and "sha256_of_the_run" not in r:
        err("receipt: sha256 is not the file's, and the receipt does not give the run's own")
    for k in ("suite", "random_seed", "run_at", "test_cases_passed", "assertions_passed", "cases_with_entries",
              "test_bitcoin_sha256", "raw_sha256"):
        if not r.get(k):
            err(f"receipt: no {k}")
    if not int(r.get("assertions_passed", 0)) > 0:
        err("receipt: no assertion passed")
for b in bad[:40]:
    print("cpp_extract: VERIFY", b)
if bad:
    sys.exit(f"cpp_extract: --verify: {len(bad)} findings: NOT CLEAN")
print(f"cpp_extract: --verify: {len(m['files'])} files, {total} entries, {len(m['files'])} receipts: CLEAN")
PY
fi

load="$(uptime | sed -E 's/.*load averages?: *([0-9.]+).*/\1/')"
if awk -v l="$load" 'BEGIN{exit !(l > 20)}'; then echo "cpp_extract: the 1-minute load is $load (> 20): not starting"; exit 2; fi

# 2. the pin: path and sha256 of `git show $COMMIT:<path>`
PINNED='
11d60fe2daefe6f842fd06b766eac5b9e5b1119b16bbbe3621f37e6e310e6227 src/test/limitedstack_tests.cpp
aa0622a3f903d775937ccfec3deddc34f0e710bc78704dda59820d7e51222151 src/test/multisig_tests.cpp
f2019cfadf0c7900ba12e747d9db7a10d10f7cfd3d96b317732d3e6e232719e8 src/test/sighash_tests.cpp
d88e742c727ccba7eba3ef2163d4c945cc0ca11330e0aff4363721c94da6a8af src/test/sighashtype_tests.cpp
dcb7c360dbd21328cceafab7f61fa635d722f27a19abb8b4df5b17fc9980c0dc src/test/instruction_iterator_tests.cpp
ef37ce13b26c30ad3afa3fa6354f0522657766d85e686c26a84bafc65ac531b9 src/test/crypto_tests.cpp
a024807aa84062f037beb51244ec0a19b2560938660ff72dfd57506d1b088d26 src/test/cscript_tests.cpp
3b25870d22420af014719d054546576a08596acf623732c8c18c587af96eb2e2 src/test/sigopcount_tests.cpp
355611681ec21dea7c3a66dd2e1cd42a52934aa5237bcf0934b6e0914b65bc52 src/test/big_int_tests.cpp
4f2a19687d5820cc6057ba0c661329db858750084965e9430bdeb43820e98d17 src/test/int_serialization_tests.cpp
cf49929c2cce3420424e1363d29a54c0d46fd4afe07cc361a0819776ee716bf8 src/test/bn_op_tests.cpp
4828e8d8588027717ca1c3c590ff4a1eac849cd464b8a834c41687d81ee6f191 src/test/lrshiftnum_tests.cpp
1a016dbb867f3a756c35b8988d39e70dd58533feacaf7ff00057c4ea92128c2c src/test/opcode_tests.cpp
76b1c1619230408034137f9e958f3d320dedbfddf01f6aaf842740785595698d src/test/script_tests.cpp
f5cfd668d4e7146459582091b977bfd53638e5052e101059ae7592ebbc72c775 src/test/scriptnum_tests.cpp
9d7862d4905ff5d4bce5f72c0c7fc0e966a72b38b70d8fc73f281e66be40a9a6 src/test/webhook_client_tests.cpp
cf843b3e3046b0bcbc83081bf25cd3fbda782258ac06aaf210ff5a8493d4cd0d src/script/script_error.h
e15efdf67691b59ad471ade8aa074f265ffd84d7219da31bbc8856fe535d3a3c src/script/script_flags.h
e1b1ee4f2b70884ebde51da6d46088346053edfd9512d753de7c69b4f6558a7a src/script/interpreter.h
1e2db53427f1a4af75d4f6145b4565e3137a4d8f3fb4eaa49671d1392d2676ee src/script/interpreter.cpp
2504ee336ca8d84b43fa2a7b62dbbbcdc3ee9985360288ecddd49013ff87c4b9 src/script/limitedstack.h
c5c58c7d5270f2d93158035a323cba92b01e20ce16d77fc6fe3c27e5e2ad00f9 src/script/limitedstack.cpp
c346a9554da2afe2d7e2175709a3821cf25e94ca148ad2a94aa0492f2453f085 src/test/transaction_tests.cpp
645b96f48361fcd6bb39c62745694c43df5f5d566300ecfc87a983709952e500 src/script/standard.cpp
98ded950735207a10804e02d847cbae7487c83d3ad7bd7e690da6492b220b1fd src/policy/policy.cpp
1b8b31b4121027fa6f5fc181dc1019ce1bfcfb410e5514f93c434573c96b8d27 src/configscriptpolicy.h
9c827a117a00d1b8dfc8de867b3cbd0ee77c8ffcb3929e6ab1d4edb60a490ff7 src/protocol_era.h
5708d32ceffbeae61a8ba46f49063e8e7ddeb0c6f5e512d647388240a77ceb16 src/test/script_P2SH_tests.cpp
ae5b9aed2bcc53e42bbf8a65da42416594a15adef377c91458b22e26a1d58c38 src/script/sign.cpp
0a08b2dabf4cd8d1910813f21480f2a7346ba90cf2d39a264bf21a60a2bfcd2c src/script/script.cpp
2aee63d1d2bbe554fe5d0a203412134a529042932dcfda1d01266cba3de76027 src/script/standard.h
f6a54858d6ec82e9eac06c52ce6ec9f22eca04008830345b65423d62c9b22f29 src/validation.cpp
c5e5f1e050f46ea6f97dcf5402d85f4f5ca98cfdbd72f266b5ea7bfed6e023a4 src/coins.h
fe359b4746b4e3b29ee2f5e51bf931c129938d6dd5d126068aefee86e9b4c3db src/test/test_txnvalidator.cpp
4514a79d78b3dbd7eafea17685aaf944dd124802255455425e8fb4fb770a3ab0 src/test/test_bitcoin.cpp
7a4af9647e25394e09a4665201bc74ee5cac67bc11ac2592818c9f22dad70e35 src/txn_validator.cpp
78dc840d0608aa124c57d12b2eae66593124e457efaf02bbee409916b6d88398 src/txn_validation_data.h
e068479dfc25b1ee7ebcf72780b36e6976164b8076e7bafff31d78e561dd4fb4 src/primitives/transaction.cpp
e5b9527c0a665ef2059ae9f296a40cd072e78a51b0425663d8c4089aaba1ebc9 src/test/txvalidationcache_tests.cpp
21ccf79f03999ea12ea75ebad3572849a06cf1637f785a621ef3900fc2b94a55 src/coins.cpp
140a863792102208249dee2bc6ba604c6f7bc5aea819238159f5cf12a46bf2b2 src/test/blockcheck_tests.cpp
87b40a828bd95a5c637620f73e46f871b517780a56383effc4ebca79b1e1748b src/config.h
d737a61264e58cd5d8cb383684341c73cdb0919008a4cca87143a51d8e54afc8 src/consensus/consensus.h
9d5f09a06bf59b70b4c53a47e4a3ff299a75c1121a76bba6d112bb6584dc1974 src/test/miner_tests.cpp
bf8ff898abb3388d5fd6bb291cb91089741e86113a51b6065711e1f4d1043af4 src/block_index.h
167e71876ccce8e5e8c11e0db389e1352b952c18d1b77cbba77338ed6ff509b8 src/test/rpc_tests.cpp
67c92675e7f5101a10f1b2ee29abac8fb7a3cf5b90037d8f58ce225693d94c89 src/rpc/rawtransaction.cpp
3b3c8cefddb056a9e4425bebcb21d60988e38fefb0ab043286f86b17700e512c src/script/int_serialization.h
'
echo "$PINNED" | while read -r sum path; do
  [ -n "$sum" ] || continue
  got="$(shasum -a 256 "$SV_SRC/$path" | cut -c1-64)"
  if [ "$got" != "$sum" ]; then echo "cpp_extract: $path is not the pin's ($got != $sum)"; exit 1; fi
done
echo "cpp_extract: the pinned files agree with $COMMIT ($(echo "$PINNED" | grep -c src/) files)"
echo "cpp_extract: instrument.patch sha256 $(shasum -a 256 "$PATCH" | cut -c1-64)"

if [ "${1:-}" != "--shape-only" ]; then
  # 3. the copy; 4. the patch (patch writes the three files anew, so make rebuilds them)
  mkdir -p "$WORK"
  rsync -a --delete --exclude='.gdbinit' "$SV_SRC/" "$WORK/src/"
  ( cd "$WORK/src" && patch -p1 --forward --quiet < "$PATCH" )
  # 5. configure once, as the reference build of 2026-09-22 (its CMakeCache: Release, hardening off, wallet,
  # ZMQ, bench, miner and UPnP off); CMAKE_POLICY_VERSION_MINIMUM for cmake 4 against leveldb's crc32c
  if [ ! -f "$WORK/build/CMakeCache.txt" ]; then
    cmake -S "$WORK/src" -B "$WORK/build" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTING=ON -DUSE_HARDENING=OFF -DBUILD_BITCOIN_WALLET=OFF -DBUILD_BITCOIN_ZMQ=OFF \
      -DBUILD_BITCOIN_BENCH=OFF -DBUILD_BITCOIN_MINER=OFF -DBUILD_BITCOIN_UPNP=OFF -DENABLE_TCMALLOC=OFF \
      "-DCMAKE_CXX_FLAGS=-Wno-error=cast-align -Wno-unknown-warning-option" > "$WORK/configure.log" 2>&1
  fi
  cmake --build "$WORK/build" --target test_bitcoin -j"$JOBS" > "$WORK/build.log" 2>&1 \
    || { tail -20 "$WORK/build.log"; echo "cpp_extract: the build failed ($WORK/build.log)"; exit 1; }
  # 6. the run, and its receipt
  # each suite runs in its own process: a suite can change the global config and leave it changed
  # (bn_op_tests.cpp:390-392, operands_too_large), and a later suite in the same process would then record
  # other parameters; one process per suite makes every file a function of its own suite alone
  rm -f "$WORK/raw.jsonl" "$WORK/receipt.json" "$WORK/run.log" "$WORK/run.ranges"
  for suite in ${SUITES//,/ }; do
    from="$( [ -f "$WORK/raw.jsonl" ] && wc -l < "$WORK/raw.jsonl" || echo 0 )"
    TEST_BITCOIN_RANDOM_SEED="$SEED" CPPX_OUT="$WORK/raw.jsonl" "$WORK/build/src/test/test_bitcoin" --run_test="$suite" \
      --log_level=error --report_level=short > "$WORK/run.$suite.log" 2>&1 \
      || { tail -20 "$WORK/run.$suite.log"; echo "cpp_extract: a Boost check failed in $suite: no entry is written"; exit 1; }
    cat "$WORK/run.$suite.log" >> "$WORK/run.log"
    echo "$suite $((from)) $(( $(wc -l < "$WORK/raw.jsonl") ))" >> "$WORK/run.ranges"
    echo "cpp_extract: $suite: $(grep -E 'assertions out of' "$WORK/run.$suite.log" | tr -s ' ')"
  done
  python3 - "$WORK" "$PATCH" "$SUITES" "$SEED" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" <<'PY'
import hashlib, json, re, sys
work, patch, suites, seed, run_at = sys.argv[1:6]
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
log = open(f"{work}/run.log").read()
ms = list(re.finditer(r'Test module "[^"]*" has passed with:\s*\n\s*(\d+) test cases out of \d+ passed.*?\n\s*(\d+) assertions out of (\d+) passed', log, re.S))
if len(ms) != len(suites.split(",")) or any(m.group(2) != m.group(3) or int(m.group(2)) == 0 for m in ms):
    sys.exit("cpp_extract: the run's logs do not say every assertion of every suite passed: no receipt is written")
cases, asserts = sum(int(m.group(1)) for m in ms), sum(int(m.group(2)) for m in ms)
# per suite: Boost's counts of its own process, and the records of the dump that process wrote (from, to)
ranges = [l.split() for l in open(f"{work}/run.ranges")]
if [r[0] for r in ranges] != suites.split(","):
    sys.exit("cpp_extract: the run's ranges do not name the suites in order: no receipt is written")
per_suite = {r[0]: {"test_cases_passed": int(m.group(1)), "assertions_passed": int(m.group(2)),
                    "records": [int(r[1]), int(r[2])]} for r, m in zip(ranges, ms)}
json.dump({"status": "passed", "suites": suites, "random_seed": seed, "run_at": run_at, "processes": len(ms),
           "test_cases_passed": cases, "assertions_passed": asserts, "per_suite": per_suite,
           "instrument_patch_sha256": sha(patch),
           "test_bitcoin_sha256": sha(f"{work}/build/src/test/test_bitcoin"), "raw_sha256": sha(f"{work}/raw.jsonl")},
          open(f"{work}/receipt.json", "w"), indent=2)
print(f"cpp_extract: receipt written: {cases} test cases, {asserts} assertions passed")
PY
fi

# the receipt gate: the dump is shaped only with the receipt of a passed run of this patch and this build
python3 - "$WORK" "$PATCH" "$SUITES" <<'PY'
import hashlib, json, os, sys
work, patch, suites = sys.argv[1:4]
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
def refuse(why):
    sys.exit(f"cpp_extract: REFUSED to shape: {why}")
if not os.path.exists(f"{work}/receipt.json"):
    refuse(f"no receipt at {work}/receipt.json (run the script without --shape-only)")
r = json.load(open(f"{work}/receipt.json"))
if r.get("status") != "passed" or not r.get("assertions_passed", 0) > 0:
    refuse("the receipt does not record a passed run with assertions")
if r.get("suites") != suites:
    refuse(f"the receipt's suites {r.get('suites')} are not {suites}")
if r.get("instrument_patch_sha256") != sha(patch):
    refuse("the receipt's patch sha256 is not corpus/cpp/instrument.patch's")
if not os.path.exists(f"{work}/build/src/test/test_bitcoin") or r.get("test_bitcoin_sha256") != sha(f"{work}/build/src/test/test_bitcoin"):
    refuse("the receipt's test_bitcoin sha256 is not the build's")
if not os.path.exists(f"{work}/raw.jsonl") or r.get("raw_sha256") != sha(f"{work}/raw.jsonl"):
    refuse("the receipt's dump sha256 is not raw.jsonl's")
print(f"cpp_extract: receipt accepted: {r['assertions_passed']} assertions passed, patch {r['instrument_patch_sha256'][:8]}")
PY

# 7. the shape
python3 - "$WORK/raw.jsonl" "$SV_SRC" "$OUT" "$(shasum -a 256 "$PATCH" | cut -c1-64)" "$WORK/src" "$WORK/receipt.json" "$COMMIT" <<'PY'
import difflib, gzip, hashlib, io, json, os, re, sys
from collections import Counter, defaultdict

raw, src, out, patch_sha, patched, receipt_path, commit = sys.argv[1:8]
PIN = f"bitcoin-sv v1.2.2 ({commit})"
receipt = json.load(open(receipt_path))
KEY = "sv-node-unit@v1.2.2"

def read(path):
    return open(f"{src}/{path}", encoding="utf-8").read()

# the error names, in the enum's order at the pin (script_error.h: SCRIPT_ERR_OK = 0, then one per line)
errors, n = {}, 0
for m in re.finditer(r"^\s*(SCRIPT_ERR_\w+)\s*(?:=\s*(\d+))?\s*,?", read("src/script/script_error.h"), re.M):
    if m.group(2) is not None:
        n = int(m.group(2))
    errors[n] = m.group(1)
    n += 1
# the flag names at the pin (script_flags.h: NAME = (1U << k))
flags = {int(m.group(2)): m.group(1)
         for m in re.finditer(r"^\s*(SCRIPT_\w+)\s*=\s*\(1U << (\d+)\)", read("src/script/script_flags.h"), re.M)}

def flag_names(word):
    return [flags[k] for k in sorted(flags) if word >> k & 1 and flags[k] != "SCRIPT_FLAG_LAST"]

def elem_bytes(e):
    if isinstance(e, str):
        return bytes.fromhex(e)
    if "runs" in e:
        return b"".join(bytes.fromhex(b) * c for b, c in e["runs"])
    return None  # sha256 only

def elem_len(e):
    return len(e) // 2 if isinstance(e, str) else e["len"]

def check(rec):
    """Every assertion the C++ check made holds of the observed result, or the recorder is wrong."""
    if rec["kind"] == "predicate":
        return None  # a predicate's hook writes what the check asserts; the receipt shows the check passed
    ob, ex = rec["observed"], rec["expect"]
    if ex is None:
        return "no CPPX_EXPECT after this call"
    st = ob.get("stack", [])
    if "stack_limit" in ex and ex["stack_limit"] != rec.get("stack_limit"):
        return "stack_limit"
    if "status" in ex and ob["status"] != ex["status"]:
        return "status"
    if ex.get("fails") and ob["status"] == 0:
        return "fails"
    if "stack_size" in ex and len(st) != ex["stack_size"]:
        return "stack_size"
    if "stack" in ex and st != ex["stack"]:
        return "stack"
    if "stack_top" in ex and (not st or st[-1] != ex["stack_top"]):
        return "stack_top"
    if "top_len" in ex and (not st or elem_len(st[-1]) != ex["top_len"]):
        return "top_len"
    for ix, off, b in ex.get("bytes_at", []):
        e = elem_bytes(st[ix])
        if e is None or e[off] != int(b, 16):
            return "bytes_at"
    for ix, v in ex.get("elems_at", []):
        if not -len(st) <= ix < len(st) or elem_bytes(st[ix]) != elem_bytes(v):
            return "elems_at"
    for ix, v in ex.get("nums_at", []):
        if not -len(st) <= ix < len(st) or script_num(elem_bytes(st[ix])) != script_num(elem_bytes(v)):
            return "nums_at"
    return None

def script_num(b):
    """A script number's value: little-endian magnitude, the sign in the top bit of the last byte."""
    if not b:
        return 0
    v = int.from_bytes(b, "little")
    top = 1 << (8 * len(b) - 1)
    return -(v & ~top) if v & top else v

# a test_data table: the line of every row (a brace at depth 1 of the initializer), comments and literals skipped
def table_rows(text, case):
    start = text.index(f"BOOST_AUTO_TEST_CASE({case})")
    nxt = text.find("BOOST_AUTO_TEST_CASE(", start + 1)
    body = text[start: nxt if nxt > 0 else len(text)]
    m = re.search(r"test_data\s*=?\s*\{", body)
    if not m:
        return None
    i, depth, rows, flat, fresh = start + m.end() - 1, 0, [], [], False
    while True:
        c = text[i]
        if text.startswith("//", i):
            i = text.index("\n", i); continue
        if text.startswith("/*", i):
            i = text.index("*/", i) + 2; continue
        if c == "'" and not text[i - 1].isalnum():  # a character literal; after a digit, a digit separator (20'000)
            i = text.index("'", i + 2) + 1; continue
        if c == '"':
            i = text.index('"', i + 1) + 1; continue
        if depth == 1 and fresh and not c.isspace() and c not in ",}":
            flat.append(text.count("\n", 0, i) + 1)
            fresh = False
        if c == "{":
            depth += 1
            if depth == 1:
                fresh = True
            if depth == 2:
                rows.append(text.count("\n", 0, i) + 1)
        elif c == "}":
            depth -= 1
            if depth == 0:
                return rows or flat
        elif c == "," and depth == 1:
            fresh = True
        i += 1

# The recorder sees the PATCHED file's lines (the include and the hooks shift them, and a call written over
# several lines reports one of them). Every cited line is mapped back to the pin through a line diff of the
# patched file against the pinned one, then moved up to the line where the call starts (the callee's name).
HELPERS = r"\b(?:Check\w+|Run\w+|Test(?:BitwiseOpcodes|Builder|MaxSigOps|Vector|SHA1|SHA256|RIPEMD160|IsStandardWithScriptFactory)|Verify(?:WithFlag)?|CreateCreditAndSpend|ReplaceRedeemScript|ProcessTxnsSynchApi|ValidateCheckInputsForAllFlags|Test_CreateNewBlock_validity)\("
CALLS = r"\b(?:EvalScript|VerifyScript)\("
def line_map(path):
    a = read(path).split("\n")
    b = open(f"{patched}/{path}", encoding="utf-8").read().split("\n")
    m = {}
    for ia, ib, n in difflib.SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks():
        for k in range(n):
            m[ib + k + 1] = ia + k + 1
    return m, a
maps = {}
def to_pin(path, line, callee):
    if path not in maps:
        maps[path] = line_map(path)
    m, a = maps[path]
    if callee is None:
        # a predicate's hook is a line the patch added just before (or just after the call of) the check it
        # transcribes: its citation is the next pinned line below it, which must be a check
        for k in range(line + 1, line + 6):
            if k in m:
                if not any("BOOST_" in a[j] for j in range(m[k] - 1, m[k] + 2)) and not re.search(HELPERS, a[m[k] - 1]):
                    sys.exit(f"cpp_extract: {path}:{m[k]} at the pin: no check, or call of a checking helper, on or just below the line under a predicate's hook")
                return m[k]
        sys.exit(f"cpp_extract: {path}:{line} (patched): no pinned line below a predicate's hook")
    if line not in m:
        sys.exit(f"cpp_extract: {path}:{line} (patched) is a line the patch added; no pin line")
    pl = m[line]
    for back in range(0, 12):
        if re.search(callee, a[pl - 1 - back]):
            return pl - back
    sys.exit(f"cpp_extract: {path}:{pl} at the pin: no call found above it")
def pin_chain(path, chain, kind):
    leaf = None if kind == "predicate" else CALLS
    return [to_pin(path, l, leaf if i == len(chain) - 1 else HELPERS) for i, l in enumerate(chain)]

# the cases whose rows the harness already replays from the vendored JSON (INVENTORY.md section 2, COVERED):
# their calls are recorded by the shared helper and dropped here, counted in the manifest
COVERED = {("src/test/script_tests.cpp", "script_build"), ("src/test/script_tests.cpp", "script_json_test"),
           ("src/test/transaction_tests.cpp", "tx_valid"), ("src/test/transaction_tests.cpp", "tx_invalid")}

recs = [json.loads(l) for l in open(raw)]
# each source file's suite: the process whose records of the dump are that file's (one suite, one file)
suite_of = {}
for sname, ps in receipt.get("per_suite", {}).items():
    for path in {r["file"] for r in recs[ps["records"][0]:ps["records"][1]]}:
        if suite_of.setdefault(path, sname) != sname:
            sys.exit(f"cpp_extract: {path} has records from two suites, {suite_of[path]} and {sname}")
if len(set(suite_of.values())) != len(suite_of):
    sys.exit("cpp_extract: one suite wrote records of two files")

# THE MASK. An entry is masked only if it is marked drawn_at_run_time, and in it only the fields a key from
# CKey::MakeNewKey feeds; the entry names them in its own `masked` list, and the stable digest replaces exactly
# those. A field is fed when it is
#   a transaction (it carries the keyed script or a signature, or spends an outpoint whose id commits to one);
#   a script that holds a push of 20 bytes or more (a key, a signature, or the hash of a keyed script), or is
#     recorded by its digest only; a script of small pushes and opcodes (`00`, `0051`) holds nothing drawn;
#   a stack that holds an element of 20 bytes or more (a failed call leaves its keys on the stack).
# Two fields hold such a push and are not fed, named here by file, case and line (None: every line of the case):
# the locking script of chronicle_scriptsig_checksig's two builders is the file's fixed key (keys.pubkey0,
# script_tests.cpp:1667), the drawn key (1662) being in their unlocking script; and the unlocking script of
# GetTxSigOpCost's call at sigopcount_tests.cpp:363 is a signature written in the source (338, 346).
FIXED = {("src/test/script_tests.cpp", "chronicle_scriptsig_checksig", None): {"input.script_pubkey"},
         ("src/test/sigopcount_tests.cpp", "GetTxSigOpCost", 363): {"input.script_sig"}}
KEY_PUSH = re.compile(r"21(?:02|03)[0-9a-f]{64}")
def has_long_push(script):
    if not isinstance(script, str):
        return True  # recorded by its runs or its digest: beyond 4,096 bytes
    b, i = bytes.fromhex(script), 0
    while i < len(b):
        op = b[i]; i += 1
        if op <= 75: n = op
        elif op == 76 and i < len(b): n = b[i]; i += 1
        elif op == 77 and i + 1 < len(b): n = int.from_bytes(b[i:i + 2], "little"); i += 2
        elif op == 78 and i + 3 < len(b): n = int.from_bytes(b[i:i + 4], "little"); i += 4
        else: continue
        if n >= 20:
            return True
        i += n
    return False
def fed_fields(path, case, e):
    fed = []
    fixed = FIXED.get((path, case, None), set()) | FIXED.get((path, case, e["source"]["line"]), set())
    # the fields in this order (a transaction is tx, tx_from, tx_to, coin_tx or a numbered coin_tx_<k>)
    for f in ("script", "script_sig", "script_pubkey", "tx", "tx_from", "tx_to", "coin_tx", "prevouts",
              *sorted(k for k in e["input"] if re.fullmatch(r"coin_tx_\d+", k)), "stack"):
        if f not in e["input"]:
            continue
        v = e["input"][f]
        if f.startswith("script"):
            yes = has_long_push(v)
        elif f == "stack":
            yes = any(not isinstance(x, str) or len(x) >= 40 for x in v)
        else:
            yes = True
        if yes and f"input.{f}" not in fixed:
            fed.append(f"input.{f}")
    st = e.get("observed", {}).get(KEY, {}).get("stack")
    if st is not None and any(not isinstance(x, str) or len(x) >= 40 for x in st):
        fed.append("observed.stack")
    return fed
dropped = Counter()
kept_recs = []
for r in recs:
    r.setdefault("kind", "evalscript")
    if (r["file"], r["case"]) in COVERED:
        dropped[(r["file"], r["case"])] += 1
        continue
    r["chain"] = pin_chain(r["file"], r["chain"], r["kind"])
    r["line"] = r["chain"][0]
    kept_recs.append(r)
recs = kept_recs
by_file = defaultdict(list)
for r in recs:
    by_file[r["file"]].append(r)
# calls made at once on threads are written in the order they finish, which varies between runs: each such group
# is put back in the order the calls were made (their index), in the places the group occupies
for path, rs in by_file.items():
    slots = defaultdict(list)
    for i, r in enumerate(rs):
        if r["kind"] != "predicate" and (r["expect"] or {}).get("concurrent"):
            slots[(r["case"], r["line"])].append(i)
    for idx in slots.values():
        ordered = sorted((rs[i] for i in idx), key=lambda r: r["seq"])
        for i, r in zip(idx, ordered):
            rs[i] = r

bad = [(r["case"], r["line"], r["seq"], check(r)) for r in recs if check(r)]
if bad:
    for b in bad[:20]:
        print("cpp_extract: UNSATISFIED", b)
    sys.exit(f"cpp_extract: {len(bad)} records whose observed result does not satisfy their check")

previous = {}
if os.path.exists(f"{out}/manifest.json"):
    previous = {f["source"]: f for f in json.load(open(f"{out}/manifest.json"))["files"]}
manifest = {"corpus": "cpp", "pin": PIN, "reader": "tools/cpp_extract.sh + corpus/cpp/instrument.patch",
            "instrument_patch_sha256": patch_sha, "engine_key": KEY,
            "license": ("derived from the reference's test sources; each file's license_header is its source's own "
                        "notice: the Open BSV License Version 5, or MIT (the pin's COPYING redirects to LICENSE, which "
                        "carries the MIT License from its line 60); corpus/cpp/LICENSE is byte for byte the pin's"),
            "files": []}
for path in sorted(by_file):
    suite = path.split("/")[-1][:-len(".cpp")]
    stem = suite[:-len("_tests")] if suite.endswith("_tests") else suite
    text = read(path)
    calls = [r for r in by_file[path] if r["kind"] != "predicate" and len(r["chain"]) == 1]
    groups = Counter((r["case"], r["line"]) for r in calls)
    looped = {(r["case"], r["line"]) for r in calls if "loop" in r["expect"] or r["expect"].get("concurrent")}
    rowmap = {}
    for (case, line), cnt in groups.items():
        if (case, line) in looped:
            if any("loop" not in r["expect"] and not r["expect"].get("concurrent")
                   for r in calls if (r["case"], r["line"]) == (case, line)):
                sys.exit(f"cpp_extract: {path} {case}: line {line} mixes loop and table calls")
            continue
        rows = table_rows(text, case)
        if cnt > 1:
            if rows is None:
                sys.exit(f"cpp_extract: {path} {case}: {cnt} calls at line {line} and no test_data table")
            if len(rows) != cnt:
                sys.exit(f"cpp_extract: {path} {case}: {len(rows)} table rows in the source, {cnt} calls recorded at line {line}")
            rowmap[(case, line)] = rows
    entries, fams = [], Counter()
    unrep = 0
    for k, r in enumerate(by_file[path], 1):
        fam = f"cpp/{suite}/{r['case']}"
        fams[fam] += 1
        source = {"file": path, "line": r["line"], "case": r["case"], "call": r["seq"]}
        if len(r["chain"]) > 1:
            source["chain"] = r["chain"]
        head = {"id": f"cpp-{stem}-{k:05d}", "family": fam, "rule": f"cpp.{suite}.{r['case']}", "kind": r["kind"]}
        if r["kind"] == "predicate":
            # a predicate: its name, its layer (policy, consensus or both: never a policy value as consensus), its
            # arguments and what the check asserts it returns
            # an argument recorded by its length and digest only (above 4,096 bytes in more than 4,096 runs) makes the
            # entry not replayable from the file alone
            digest_only = any(isinstance(v, dict) and "sha256" in v for v in r["args"].values())
            unrep += digest_only
            # where a check asserts less than the call returns, the hook's own second call gives what the build returned
            seen = r["expect"].pop("_observed", None)
            e = {**head, "source": source, "predicate": r["predicate"], "layer": r["layer"], "input": r["args"],
                 "expect": {KEY: r["expect"]}, **({"observed": {KEY: seen}} if seen is not None else {}),
                 "replayable": not digest_only}
            if r.get("note"):
                e["note"] = r["note"]
            if r.get("drawn"):
                e["drawn_at_run_time"] = r["drawn"]
                e["masked"] = fed_fields(path, r["case"], e)
            entries.append(e)
            continue
        ex, ob = r["expect"], r["observed"]
        exp = {}
        if ex.get("status") == 0:
            exp["verdict"] = "ok"
        elif "status" in ex or ex.get("fails"):
            exp["verdict"] = "error"
        else:
            exp["verdict"] = "unasserted"
        if ex.get("status", 0) != 0:
            exp["error"] = errors[ex["status"]]
        for f in ("stack_size", "stack", "stack_top", "top_len", "bytes_at", "elems_at", "nums_at"):
            if f in ex:
                exp[f] = ex[f]
        if (r["case"], r["line"]) in rowmap:
            source["row_line"] = rowmap[(r["case"], r["line"])][r["seq"]]
        if "loop" in ex:
            source["loop_index"] = ex["loop"]
        if ex.get("concurrent"):
            source["concurrent"] = True
        inp = {"flags": r["flags"], "flag_names": flag_names(r["flags"]), "params": r["params"],
               "checker": r["checker"], "tx_version": r["tx_version"]}
        for f in ("tx", "n_in", "amount"):
            if f in r:
                inp[f] = r[f]
        observed = {"error": errors[ob["status"]] if ob["status"] is not None else None}
        if r["kind"] == "evalscript":
            inp.update({"script": r["script"], "stack": r["stack_in"], "stack_limit": r["stack_limit"]})
            # the observed stack is written only where the check does not assert the whole stack (where it does,
            # the two are equal: check() above)
            if "stack" not in ex:
                observed["stack"] = ob["stack"]
            elems = [r["script"], *r["stack_in"], *ob["stack"]]
        else:
            inp.update({"script_sig": r["script_sig"], "script_pubkey": r["script_pubkey"]})
            elems = [r["script_sig"], r["script_pubkey"]]
        replayable = all(isinstance(e, str) or "runs" in e for e in elems)
        unrep += not replayable
        e = {**head, "source": source, "input": inp, "expect": {KEY: exp}, "observed": {KEY: observed},
             "replayable": replayable}
        if "note" in ex:
            e["note"] = ex["note"]
        if ex.get("drawn"):
            e["drawn_at_run_time"] = ex["drawn"]
        elif (path, r["case"]) == ("src/test/opcode_tests.cpp", "opcode_limit_tests") and isinstance(r["script"], str) \
                and KEY_PUSH.search(r["script"]):
            # the case's hook does not name its draw: the scripts built by dummy_multisig_with_pubkey carry one key
            # from CKey::MakeNewKey three times (opcode_tests.cpp:1264-1277), each as a 33-byte push
            e["drawn_at_run_time"] = "a key from CKey::MakeNewKey, opcode_tests.cpp:1264-1277"
        if "drawn_at_run_time" in e:
            e["masked"] = fed_fields(path, r["case"], e)
        entries.append(e)
    body = "".join(json.dumps(e, separators=(",", ":"), sort_keys=False) + "\n" for e in entries)
    data = body.encode()
    name = f"{suite}.jsonl"
    # the stable digest (THE MASK, above): the JSONL with, in each entry that carries a `masked` list, exactly the
    # fields the list names replaced by "drawn"; an entry without the list is hashed as it is written, so a file
    # with no drawn entry has one digest, and --verify recomputes this digest from the committed file alone
    for e in entries:
        if "drawn_at_run_time" in e and not e["masked"]:
            sys.exit(f"cpp_extract: {e['id']} is drawn at run time and no field of it is fed by a key")
    def masked_entry(e):
        if "masked" not in e:
            return e
        e = json.loads(json.dumps(e))
        for f in e["masked"]:
            side, fname = f.split(".")
            (e["input"] if side == "input" else e["observed"][KEY])[fname] = "drawn"
        return e
    stable = "".join(json.dumps(masked_entry(e), separators=(",", ":"), sort_keys=False) + "\n" for e in entries)
    masked = hashlib.sha256(stable.encode()).hexdigest()
    # a committed file whose key-masked digest this run reproduces is kept byte for byte (its keys are an earlier
    # run's draw); every other file is written anew
    was = previous.get(path)
    kept = (was is not None and was["sha256_keys_masked"] == masked and was["count"] == len(entries)
            and os.path.exists(f"{out}/{was['file']}")
            and hashlib.sha256(open(f"{out}/{was['file']}", "rb").read()).hexdigest() == was["sha256_of_file"])
    if kept:
        name = was["file"]
    else:
        for old in (f"{out}/{name}", f"{out}/{name}.gz"):
            if os.path.exists(old):
                os.remove(old)
        # a file above 50 MB is written gzipped (GitHub refuses a file above 100 MB): level 9, no name, mtime 0,
        # so the bytes are the same at every run; the digest of record is the uncompressed JSONL's
        if len(data) > 50_000_000:
            buf = io.BytesIO()
            with gzip.GzipFile(filename="", mode="wb", compresslevel=9, fileobj=buf, mtime=0) as g:
                g.write(data)
            name += ".gz"
            open(f"{out}/{name}", "wb").write(buf.getvalue())
        else:
            open(f"{out}/{name}", "wb").write(data)
    verdicts = Counter(e["expect"][KEY].get("verdict", "predicate") for e in entries)
    manifest["files"].append({
        "file": name, "source": path, "source_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "license_header": [l[2:].strip() for l in text.split("\n")[:8] if l.startswith("//")],
        "count": len(entries), "sha256": was["sha256"] if kept else hashlib.sha256(data).hexdigest(),
        "sha256_of_file": hashlib.sha256(open(f"{out}/{name}", "rb").read()).hexdigest(),
        "sha256_keys_masked": masked,
        "verdicts": dict(sorted(verdicts.items())), "not_replayable": unrep,
        "tables_by_row": len(rowmap), "kinds": dict(sorted(Counter(e["kind"] for e in entries).items())),
        "drawn_at_run_time": sum("drawn_at_run_time" in e for e in entries),
        "covered_not_extracted": {c: n for (f, c), n in sorted(dropped.items()) if f == path},
        "families": dict(sorted(fams.items()))})
    if kept and hashlib.sha256(data).hexdigest() != was["sha256"]:
        manifest["files"][-1]["kept"] = ("the file on disk, an earlier run's key draw: this run drew other keys "
                                         "and reproduced its key-masked digest")
    # the suite's receipt: the run's evidence for this file, one page per suite
    ps = receipt.get("per_suite", {}).get(suite_of.get(path))
    if ps is None:
        sys.exit(f"cpp_extract: the receipt has no per-suite counts for {path}: run the script without --shape-only")
    mf = manifest["files"][-1]
    os.makedirs(f"{out}/receipts", exist_ok=True)
    lines = [f"suite: {suite_of[path]}", f"source: {path}", f"pin: {PIN}", f"file: corpus/cpp/{name}", "status: passed",
             f"test_cases_passed: {ps['test_cases_passed']}", f"assertions_passed: {ps['assertions_passed']}",
             f"cases_with_entries: {len({e['family'] for e in entries})}", f"entries: {len(entries)}",
             f"sha256: {mf['sha256']}", f"sha256_keys_masked: {masked}",
             f"entries_masked: {sum('masked' in e for e in entries)}"]
    if kept and hashlib.sha256(data).hexdigest() != mf["sha256"]:
        lines.append(f"sha256_of_the_run: {hashlib.sha256(data).hexdigest()}")
    lines += [f"random_seed: {receipt['random_seed']} (TEST_BITCOIN_RANDOM_SEED, test_bitcoin.cpp:49-67)",
              f"run_at: {receipt['run_at']}", f"instrument_patch_sha256: {patch_sha}",
              f"test_bitcoin_sha256: {receipt['test_bitcoin_sha256']}", f"raw_sha256: {receipt['raw_sha256']}",
              f"command: TEST_BITCOIN_RANDOM_SEED=<random_seed> CPPX_OUT=<dump> test_bitcoin --run_test={suite_of[path]}"]
    open(f"{out}/receipts/{suite}.txt", "w").write("\n".join(lines) + "\n")
    print(f"cpp_extract: {suite}.jsonl {len(entries)} entries {dict(sorted(verdicts.items()))}, "
          f"{unrep} not replayable, {len(rowmap)} tables cited by row")
json.dump(manifest, open(f"{out}/manifest.json", "w"), indent=2)
open(f"{out}/manifest.json", "a").write("\n")
PY
