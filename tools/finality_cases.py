#!/usr/bin/env python3
"""#60 boundary rows, with literal expectations derived from pinned source.

[SRC] src/validation.cpp:227–341,1094–1124,2646–2663,5977–6074 and
src/block_index.h:720–737 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.
This generator does not call the Lean implementation or a node. The `expected`
column is [D]; #66 supplies the regtest observations. Run from the repo root.
"""
import json
from collections import Counter
from pathlib import Path

PIN = "6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
ROOT = Path(__file__).resolve().parents[1]
rows = []
FINAL = 4294967295  # [SRC] src/primitives/transaction.h:99 at 6504a3af
MONEY = 2100000000000000  # [SRC] src/amount.h:130 at 6504a3af
MEMPOOL = 2147483647  # Existing BsvScript.Params.mempoolHeight
base = dict(version=2, lockTime=0, sequences=[0], genesisHeight=10,
            chronicleHeight=20, csvHeight=5, span=11, capacity=52428800,
            expiry=2419200)
sources = {
    "finality": "src/validation.cpp:227–247",
    "median": "src/block_index.h:720–737; src/validation.cpp:6055–6056",
    "tip": "src/validation.cpp:5977–6037",
    "mempool": "src/validation.cpp:1094–1124; src/policy/policy.h:246–255",
    "block": "src/validation.cpp:5977–5996,6042–6056,6067–6074",
    "sequence": "src/validation.cpp:256–341,362–406,434–435; src/primitives/transaction.h:99–129",
    "flags": "src/policy/policy.h:246–255; src/consensus/consensus.h:84–91",
    "fee": "src/validation.cpp:2646–2663; src/amount.h:130–134",
    "expiry": "src/time_locked_mempool.cpp:627–660",
}

def reject(code, reason):
    return dict(status="rejected", namespace="node", code=code, reason=reason)

final = dict(status="final")
held = dict(status="heldNonFinal")
nonfinal = reject(16, "bad-txns-nonfinal")

def add(kind, boundary, expected, derivation, **inputs):
    row = dict(id=f"{kind}/{boundary}", kind=kind, boundary=boundary,
               label="[D]", source=f"[SRC] {sources[kind]} at {PIN}",
               node="pending #66", expected=expected, derivation=derivation,
               scope="isolated predicate or validation stage, not full transaction admission")
    row.update(base)
    row.update(inputs)
    rows.append(row)

add("finality", "lock-zero", True, "Zero lock time takes the early return.", height=0, time=0)
for lock, expected, name in [(99, True, "below"), (100, False, "equal"), (101, False, "above")]:
    add("finality", f"height-{name}", expected, "Height locks require strict less-than unless every sequence is final.", lockTime=lock, height=100, time=999999999)
for lock, expected in [(499999998, True), (499999999, True), (500000000, False), (500000001, False), (500000002, False)]:
    add("finality", f"threshold-{lock}", expected, "Below 500000000 the selected limit is height; from that value it is time. Equality fails.", lockTime=lock, height=500000000, time=500000000)
for time, expected, name in [(500000009, False, "below"), (500000010, False, "equal"), (500000011, True, "above")]:
    add("finality", f"time-{name}", expected, "The time cutoff must strictly exceed the lock.", lockTime=500000010, height=100, time=time)
for lock, kind in [(101, "height"), (500000010, "time")]:
    add("finality", f"all-final-future-{kind}", True, "All final sequences disable the future lock.", lockTime=lock, sequences=[FINAL, FINAL], height=100, time=500000000)
    add("finality", f"mixed-future-{kind}", False, "One non-final sequence keeps the future lock active.", lockTime=lock, sequences=[FINAL, FINAL-1], height=100, time=500000000)
add("finality", "empty-inputs", True, "The empty input loop returns true; structural validity is a separate gate.", lockTime=500000010, sequences=[], height=0, time=0)
add("finality", "height-ignores-time", False, "A height lock does not compare with the larger time.", lockTime=101, height=100, time=500000011)
add("finality", "time-ignores-height", False, "A time lock does not compare with the larger height.", lockTime=500000010, height=500000011, time=500000009)

medians = [
    ("eleven-unsorted", [11,1,10,2,9,3,8,4,7,5,6], 11, 6),
    ("older-twelfth-ignored", [11,1,10,2,9,3,8,4,7,5,6,0], 11, 6),
    ("eleven-duplicates", [9,9,1,1,1,1,1,9,9,9,9], 11, 9),
    ("short-one", [42], 11, 42),
    ("short-two-upper-middle", [9,1], 11, 9),
    ("short-three", [9,1,5], 11, 5),
    ("short-four-upper-middle", [8,2,6,4], 11, 6),
    ("configured-span", [9,1,5,0,0,0], 3, 5),
    ("empty-total-extension", [], 11, 0),
    ("zero-span-total-extension", [42], 0, 0),
]
for name, times, span, expected in medians:
    add("median", name, expected, "Take the newest span, sort, select index length/2; the declared empty extension is zero.", times=times, span=span)

for time, expected, name in [(500000009, held, "below"), (500000010, held, "equal"), (500000011, final, "above")]:
    add("tip", f"mtp-{name}", expected, "The flagged cutoff is the previous median; a non-final post-Genesis result has no reject code.", lockTime=500000010, tipHeight=10, times=[time], now=500000100, flags=2)
for flags in [-1, 0, 1, 2, 3]:
    add("tip", f"flags-{flags}", final if flags < 2 else held, "Negative flags clamp to zero; only the median flag selects the lower median over adjusted now.", lockTime=500000010, tipHeight=10, times=[500000009], now=500000011, flags=flags)
add("tip", "successor-height", final, "Lock 10 is below successor 11 despite equaling tip 10.", lockTime=10, tipHeight=10, times=[0], now=0, flags=2)
add("tip", "successor-height-equal", held, "Lock 11 equals the successor; the post-Genesis non-final state is retained.", lockTime=11, tipHeight=10, times=[0], now=0, flags=2)
add("tip", "before-genesis-rejected", nonfinal, "At successor 9 before Genesis 10, contextual finality rejects with node code 16.", lockTime=10, tipHeight=8, times=[0], now=0, flags=3)
add("tip", "successor-genesis-held", held, "At successor Genesis height 10, non-final has no contextual rejection.", lockTime=10, tipHeight=9, times=[0], now=0, flags=3)

for capacity, expected in [(0, reject(259, "non-final-pool-full")), (1, held), (52428800, held)]:
    add("mempool", f"capacity-{capacity}", expected, "This early policy gate tests configured capacity for zero, not current occupancy.", lockTime=11, tipHeight=10, times=[0], now=0, capacity=capacity)
add("mempool", "final-zero-capacity", final, "Finality succeeds without consulting non-final capacity.", lockTime=10, tipHeight=10, times=[0], now=0, capacity=0)
add("mempool", "pregenesis-nonstandard", reject(64, "bad-txns-nonfinal"), "Admission maps the contextual invalidity to REJECT_NONSTANDARD before the capacity test.", lockTime=10, tipHeight=8, times=[0], now=0, capacity=0)
add("mempool", "successor-activation-held", held, "The tip selects pre-Genesis flags but the successor contextual check permits holding.", lockTime=10, tipHeight=9, times=[0], now=0)
add("mempool", "adjusted-time-does-not-unlock", held, "The standard word always selects median time, even when adjusted now is later.", lockTime=500000010, tipHeight=10, times=[500000010], now=500000011)

# [SRC] src/validation.cpp:1101–1106,5998–6004,6026–6028,6042–6056,6067–6074
# at 6504a3af. Literal outcomes for C++17's implementation-defined signed
# integral narrowing on the build targets: two's-complement signed 32-bit int.
# The block cutoff retains int64_t. No node observation is supplied here.
for median, lock, tip_expected, block_expected in [
    (2147483647, 2147483646, final, final),
    (2147483647, 2147483647, held, nonfinal),
    (2147483648, 2147483646, held, final),
    (2147483648, 2147483647, held, final),
]:
    times = list(range(median + 5, median - 6, -1))
    boundary = f"signed-mtp-{median}-lock-{lock}"
    for kind in ("tip", "mempool", "block"):
        add(kind, boundary, block_expected if kind == "block" else tip_expected,
            "The tip caller narrows median 2147483648 to -2147483648; 2147483647 is unchanged. "
            "The block path retains the full median. Lock comparison is strict and sequence zero keeps the lock active.",
            lockTime=lock, tipHeight=10, height=11, times=times, now=2147483660,
            blockTime=2147483660, flags=2,
            source=f"[SRC] src/validation.cpp:1101–1106,5998–6004,6026–6028,6042–6056,6067–6074 at {PIN}")

add("block", "before-csv-own-time", final, "Before CSVHeight 5 the block time 500000011 exceeds the lock.", lockTime=500000010, height=4, times=[500000009], blockTime=500000011)
add("block", "before-csv-equal-own-time", nonfinal, "Before CSV, equality against the block's own time fails.", lockTime=500000010, height=4, times=[500000011], blockTime=500000010)
for time, expected, name in [(500000009, nonfinal, "below"), (500000010, nonfinal, "equal"), (500000011, final, "above")]:
    add("block", f"csv-mtp-{name}", expected, "From CSVHeight inclusive the previous median is the cutoff.", lockTime=500000010, height=5, times=[time], blockTime=500000100)
add("block", "postgenesis-still-rejected", nonfinal, "The block path rejects non-finality after Genesis too.", lockTime=500000010, height=10, times=[500000010], blockTime=500000100)
add("block", "absent-csv-unresolved", dict(status="unresolved"), "An absent census assignment supplies no executable block cutoff.", lockTime=0, height=0, times=[], blockTime=0, csvHeight=None)
add("block", "no-parent-zero-lock", final, "The no-parent median is zero, and zero lock time is final.", height=0, times=[], blockTime=0, csvHeight=0)
add("block", "configured-span", final, "The newest three times have median 500000011, above the lock.", lockTime=500000010, height=5, times=[500000012,500000011,500000009,0,0,0], blockTime=0, span=3)

seqbase = dict(tipHeight=10, times=[1000]*11, coinHeights=[10], flags=1, genesisHeight=100)
def seq(name, expected, why, **changes):
    add("sequence", name, expected, why, **(seqbase | changes))
seq("height-below", True, "10 + 1 - 1 = 10, strictly below successor 11.", sequences=[1])
seq("height-equal", False, "10 + 2 - 1 = 11 equals successor 11.", sequences=[2])
seq("height-above", False, "10 + 3 - 1 = 12 exceeds successor 11.", sequences=[3])
seq("zero-relative", True, "Zero relative height subtracts one using signed arithmetic.", sequences=[0], coinHeights=[0], tipHeight=0, times=[0])
seq("mempool-zero", True, "A mempool coin resolves to 11; 11 + 0 - 1 = 10 passes.", sequences=[0], coinHeights=[MEMPOOL])
seq("mempool-one", False, "A mempool coin resolves to 11; 11 + 1 - 1 = 11 fails.", sequences=[1], coinHeights=[MEMPOOL])
seq("disable-bit", True, "The disable flag ignores all lower lock bits.", sequences=[2147549183])
seq("low-sixteen-mask", True, "Bit 16 contributes nothing: the masked relative height is 1.", sequences=[65537])
seq("mask-maximum", False, "The low sixteen bits can encode relative height 65535.", sequences=[65535])
seq("version-one", True, "Unsigned version 1 disables BIP68.", sequences=[100], version=1)
seq("version-zero", True, "Unsigned version 0 disables BIP68.", sequences=[100], version=0)
seq("negative-version-unsigned", False, "Signed version -1 reads as unsigned 4294967295, so the height lock applies.", sequences=[100], version=-1)
seq("flag-off", True, "Without LOCKTIME_VERIFY_SEQUENCE, the minima remain -1.", sequences=[100], flags=2)
seq("mixed-height-maximum", False, "All input constraints are combined by maximum; the second input fails.", sequences=[1,2], coinHeights=[10,10])
seq("disabled-and-active", True, "A disabled input cannot raise the active input's passing bound.", sequences=[FINAL,1], coinHeights=[10,10])
for cutoff, expected, name in [(510, False, "below"), (511, False, "equal"), (512, True, "above")]:
    seq(f"time-{name}", expected, "Coin height 1 uses ancestor height 0 with median 0; 0 + 512 - 1 = 511.", sequences=[4194305], tipHeight=2, times=[1024,cutoff,0], coinHeights=[1])
seq("time-zero-clamped-ancestor", True, "Coin height zero clamps its preceding ancestor to zero; zero relative time yields -1.", sequences=[4194304], tipHeight=0, times=[0], coinHeights=[0])
seq("time-uses-coin-predecessor", False, "Coin height 2 uses ancestor height 1, whose short-chain upper median is 500; 500 + 512 - 1 = 1011 exceeds tip median 500.", sequences=[4194305], tipHeight=2, times=[2000,500,0], coinHeights=[2])
seq("time-mempool-one", False, "The mempool coin uses the tip's median as its base; a nonzero relative time cannot pass.", sequences=[4194305], coinHeights=[MEMPOOL])
seq("missing-coin", False, "Fresh pre-Genesis checking refuses an absent/spent input before calculation.", coinHeights=[None], flags=0, version=1)
seq("height-vector-mismatch", False, "The model refuses a malformed vector instead of truncating zip.", coinHeights=[])
seq("missing-ancestor", False, "A required absent ancestor supplies no sequence verdict.", sequences=[4194305], tipHeight=10, times=[1000], coinHeights=[1])
seq("genesis-minus-one", False, "At tip 9 below Genesis 10 the height lock is evaluated.", sequences=[100], tipHeight=9, coinHeights=[9], genesisHeight=10)
seq("genesis-at-tip-short-circuit", True, "At Genesis tip 10, return true before reading a missing coin vector or times.", sequences=[100], coinHeights=[], times=[], genesisHeight=10)
seq("genesis-after-tip-short-circuit", True, "After Genesis, missing coins and lock flags are not inspected here.", tipHeight=11, sequences=[100], coinHeights=[None], times=[], genesisHeight=10)

for height, expected in [(9,3),(10,2),(20,2)]:
    add("flags", f"era-{height}", expected, "Median time is always selected; sequence verification is selected only before Genesis.", tipHeight=height)
for name, value_in, value_out, expected in [
    ("zero", 0, 0, dict(status="ok",fee=0)),
    ("one", 1, 0, dict(status="ok",fee=1)),
    ("max-minus-one", MONEY-1, 0, dict(status="ok",fee=MONEY-1)),
    ("max", MONEY, 0, dict(status="ok",fee=MONEY)),
    ("max-plus-one", MONEY+1, 0, reject(16,"bad-txns-fee-outofrange")),
    ("below-out", 0, 1, reject(16,"bad-txns-in-belowout")),
    ("negative-input-stage", -1, 0, reject(16,"bad-txns-in-belowout")),
    ("equal-max-values", MONEY, MONEY, dict(status="ok",fee=0)),
    ("subtract-one", MONEY, 1, dict(status="ok",fee=MONEY-1)),
]:
    add("fee", name, expected, "Isolated fee stage: below-out precedes MoneyRange of the exact difference; #61 checks input values earlier.", valueIn=value_in, valueOut=value_out)
for name, now, expiry, expected in [("below",109,10,False),("equal",110,10,True),("above",111,10,True),("clock-backward",99,10,False),("zero-expiry",100,0,True),("backward-zero-expiry",99,0,False)]:
    add("expiry", name, expected, "Signed elapsed time must be at least the configured age; periodic finality revalidation has priority.", insertionTime=100, now=now, expiry=expiry)

path = ROOT / "corpus/chain/finality/finality.jsonl"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text("".join(json.dumps(row, separators=(",", ":"), ensure_ascii=False) + "\n" for row in rows))
print(f"finality_cases: {len(rows)} derived rows; " + ", ".join(f"{k}={v}" for k,v in Counter(r['kind'] for r in rows).items()))
