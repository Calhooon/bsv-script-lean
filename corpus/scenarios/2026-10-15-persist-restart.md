# mempool persistence across restarts, with and without `-persistmempool` (#81)

[M] 2026-10-15. Scenario `2026-10-15-persist-restart`; [M] sixteen declared steps: the prefix, seven submissions and a fee delta
on one instance, three restarts of that instance on its own data directory (the setting on, off, on), three steps between the
last two (an invalidation, a submission, a generated block) and the final stop. [D] The transitions are `lean/BsvChain/Persist.lean` (`shutdown`, `start`, `load`) over the admission machine
of #62; nothing here is consensus: `-persistmempool` is a node setting (default on, `src/validation.h:197-198`), and the expiry,
the purge age and every load decision are policy.

[D] Initial chain: 120 generated blocks `g1` to `g120` on a fresh isolated instance launched with `genesisactivationheight=100`
(a selected launch input: before Genesis a non-final transaction is refused `bad-txns-nonfinal`, after it the held pool takes it,
`src/validation.cpp:5977-5993`; the status-view scenarios use the same height); the last three are named `A0` (height 118),
`A1` (119) and `A2` (120, the tip). Six coins fund the fixture: `coin1` to `coin6`, the coinbase outputs of `g1` to `g6`, mature at
every tip the scenario reaches (coinbase maturity 100, a consensus constant, `src/consensus/consensus.h:71-75`). Synthetic names
only:

| name | spends | lock time | sequence | role [D] |
|---|---|---|---|---|
| `E` | `coin1` | 0 | final | submitted at `t0`, the oldest entry: expired at the last load |
| `Nold` | `coin2` | `far` (tip + 880) | 0 | held non-final, submitted at `t0`: past the purge age at the last load |
| `K` | `coin3` | 0 | final | the parent; carries a fee delta of 1000 satoshis |
| `D` | `K` | 0 | final | the child: the dump's order puts it after `K` |
| `C` | `coin4` | 0 | final | its input is spent by `Cx`, mined while the setting is off |
| `L` | `coin5` | `tip` (the tip's height at `r0`) | 0 | final at that tip, non-final one block lower: moves to the held pool at the last load |
| `N` | `coin6` | `far` | 0 | held non-final throughout |
| `Cx` | `coin4` | 0 | final | the conflicting spend of `C`'s input, a different output value |

[D] The clock (`clock`, seconds): `t0` 1700000000, `t1` = `t0` + 100, `tr1` = `t0` + 200, `tr2` = `t0` + 300 and `tload` =
`t0` + 1209650, so that at `tload` `E` (entry `t0`) is at the accepted pool's expiry, 1209600 seconds, plus 50 and `K` (entry `t1`)
50 seconds short of it (`src/txmempool.cpp:3209`: kept only when entry time plus expiry is after now). A restart's clock is the
launch's `-mocktime`, which the node sets before its load (`src/init.cpp:3198-3199`; the load reads GetTime once,
`src/txmempool.cpp:3172`); the runner sets the same clock again by RPC after the start. The last restart also launches with
`-mempoolexpirynonfinal=336` (hours: the purge age 1209600 seconds, read at launch, `src/time_locked_mempool.cpp:400-405`), so
`Nold` (entry `t0`) is past it and `N` (entry `t1`) is not.

[D] The restarts, on the instance's own data directory (`Node::restart`, the reference suite's `restart_node`): `r1` with the
setting on (the default) at `tr1`, `r2` with `persistmempool=0` at `tr2`, `r3` with `persistmempool=1` at `tload`. A
restart's shutdown writes the two files when the run had the setting (`src/init.cpp:237-240`), and nothing otherwise, so the files
`r3` reads are the ones `r1`'s run wrote (the stale file: `stale_file_after_run_without`); between them, with the setting off, `A1`
and `A2` are invalidated and `B1` is generated on `A0` holding `Cx`, leaving the tip one block lower than at `r0`. Each step's
`load` is the ledger of `Persist.load` by name: `accepted` and `heldNonFinal` are kept, `expired` and `missingInputs` dropped;
`counts` are the success, failed and expired counts per file the node logs (`src/txmempool.cpp:3259-3261`,
`src/time_locked_mempool.cpp:368-369`). `files_read` names the records of the files the start read: the accepted file in its
order, the held file as a set (its order is the txid order, `src/time_locked_mempool.h:146-152,181-185`, which differs between the
node's bodies and the projection's).

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: `src/init.cpp:158,237-240,495-498,1880-1905,3198-3199,
3543-3551`; `src/txmempool.cpp:1851-1858,1942-1988,2996-3344`; `src/time_locked_mempool.cpp:247-378,400-405`;
`src/validation.cpp:1094-1193,7140-7163`; `src/txn_validator.cpp:142-214`; `src/rpc/blockchain.cpp:380-395`;
`src/rpc/mining.cpp:312-344`.

[D] Not exercised: a body the pool had moved to its transaction database (the on-disk record, `src/txmempool.cpp:3186-3195`), a
dump file of another version, a failed dump, a shutdown during the load, a residual fee delta of an id outside the pool, a record
admission refuses with a code (the `rejected` reason), and a held record that is final at the load (it would be accepted). Each
has its branch and citation in the module.

| step | action | declared [D] |
|---|---|---|
| p0 | the prefix, 120 blocks | tip `A2`; both pools empty |
| a1 | submit `E` at `t0` | `E` accepted |
| a2 | submit `Nold` at `t0` | `Nold` held |
| a3 | submit `K` at `t1` | `K` accepted |
| a4 | fee delta 1000 on `K` | `K`'s modified fee is its fee plus 1000 satoshis |
| a5 | submit `D` at `t1` | `D` accepted after its parent |
| a6 | submit `C` at `t1` | `C` accepted |
| a7 | submit `L` at `t1` | `L` accepted: final at the tip |
| a8 | submit `N` at `t1` | `N` held |
| r1 | restart, the setting on, at `tr1` | every record kept: pools as before, entry times and `K`'s delta unchanged; counts 5, 0, 0 and 2, 0, 0 |
| r2 | restart, `persistmempool=0`, at `tr2` | nothing read: both pools empty, no load line |
| b1 | invalidate `A1` | tip `A0` |
| b2 | submit `Cx` | `Cx` accepted |
| b3 | generate `B1` holding `Cx` | tip `B1` (height 119); pool empty; `coin4` spent on chain |
| r3 | restart, `persistmempool=1`, at `tload`, purge age 336 hours | the files of `r1`'s run: `E` expired, `K` and `D` accepted, `C` missing inputs, `L` held (non-final at `B1`), `Nold` expired, `N` held; counts 3, 1, 1 and 1, 0, 1 |
| z1 | the final stop | the files written: accepted `K`, `D` in that order; held `L`, `N` |

```json
{
  "id": "2026-10-15-persist-restart",
  "class": "mempool persistence (#81): what a restart keeps, with and without -persistmempool",
  "witness": "#81 done-bar: a regtest scenario restarting the node with and without the parameter",
  "label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "regtest-persist",
    "prefix_blocks": 120,
    "named_blocks": {"A0": 118, "A1": 119, "A2": 120},
    "coins": {"coin1": 1, "coin2": 2, "coin3": 3, "coin4": 4, "coin5": 5, "coin6": 6},
    "launch": "harness/oracle/scenarios.conf plus genesisactivationheight=100; persistmempool unset (the default, on) until r2"
  },
  "clock": {"t0": 1700000000, "t1": 1700000100, "tr1": 1700000200, "tr2": 1700000300, "tload": 1701209650},
  "fixtures": [
    {"name": "E", "spends": "coin1", "lock": "none", "sequence": "final", "variant": 1},
    {"name": "Nold", "spends": "coin2", "lock": "far", "sequence": 0, "variant": 1},
    {"name": "K", "spends": "coin3", "lock": "none", "sequence": "final", "variant": 1},
    {"name": "D", "spends": "K", "lock": "none", "sequence": "final", "variant": 1},
    {"name": "C", "spends": "coin4", "lock": "none", "sequence": "final", "variant": 1},
    {"name": "L", "spends": "coin5", "lock": "tip", "sequence": 0, "variant": 1},
    {"name": "N", "spends": "coin6", "lock": "far", "sequence": 0, "variant": 1},
    {"name": "Cx", "spends": "coin4", "lock": "none", "sequence": "final", "variant": 2}
  ],
  "steps": [
    {"id": "p0", "action": {"type": "prefix"}, "kind": "setup", "rules": ["receive"],
     "expected_observations": {"mempool": [], "non_final_pool": [], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a1", "action": {"type": "submit", "tx": "E", "clock": "t0"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["E"], "non_final_pool": [], "tip": "A2", "entry_times": {"E": "t0"}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a2", "action": {"type": "submit", "tx": "Nold", "clock": "t0"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["E"], "non_final_pool": ["Nold"], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a3", "action": {"type": "submit", "tx": "K", "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["E", "K"], "non_final_pool": ["Nold"], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a4", "action": {"type": "prioritise", "tx": "K", "delta": 1000, "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["E", "K"], "non_final_pool": ["Nold"], "tip": "A2", "fee_deltas": {"K": 1000}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a5", "action": {"type": "submit", "tx": "D", "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["D", "E", "K"], "non_final_pool": ["Nold"], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a6", "action": {"type": "submit", "tx": "C", "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["C", "D", "E", "K"], "non_final_pool": ["Nold"], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a7", "action": {"type": "submit", "tx": "L", "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["C", "D", "E", "K", "L"], "non_final_pool": ["Nold"], "tip": "A2"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "a8", "action": {"type": "submit", "tx": "N", "clock": "t1"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["C", "D", "E", "K", "L"], "non_final_pool": ["N", "Nold"], "tip": "A2",
       "entry_times": {"C": "t1", "D": "t1", "E": "t0", "K": "t1", "L": "t1"}, "fee_deltas": {"K": 1000}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "r1", "action": {"type": "restart", "persistmempool": "default", "clock": "tr1"}, "kind": "restart", "rules": ["persist"],
     "expected_observations": {"mempool": ["C", "D", "E", "K", "L"], "non_final_pool": ["N", "Nold"], "tip": "A2",
       "entry_times": {"C": "t1", "D": "t1", "E": "t0", "K": "t1", "L": "t1"}, "fee_deltas": {"K": 1000},
       "files_read": {"mempool": ["E", "K", "D", "C", "L"], "deltas": [], "non_final": ["N", "Nold"]},
       "load": {"mempool": {"E": "accepted", "K": "accepted", "D": "accepted", "C": "accepted", "L": "accepted"},
                "non_final": {"N": "heldNonFinal", "Nold": "heldNonFinal"}},
       "counts": {"mempool": [5, 0, 0], "non_final": [2, 0, 0]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "r2", "action": {"type": "restart", "persistmempool": false, "clock": "tr2"}, "kind": "restart", "rules": ["persist"],
     "expected_observations": {"mempool": [], "non_final_pool": [], "tip": "A2", "load": null, "counts": null,
       "files_read": {"mempool": ["E", "K", "D", "C", "L"], "deltas": [], "non_final": ["N", "Nold"]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "b1", "action": {"type": "invalidateblock", "block": "A1", "clock": "tr2"}, "kind": "invalidate", "rules": ["invalidate"],
     "expected_observations": {"mempool": [], "non_final_pool": [], "tip": "A0"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "b2", "action": {"type": "submit", "tx": "Cx", "clock": "tr2"}, "kind": "receive", "rules": ["receive"],
     "expected_observations": {"mempool": ["Cx"], "non_final_pool": [], "tip": "A0"},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "b3", "action": {"type": "generate", "block": "B1", "transactions": ["Cx"], "clock": "tr2"}, "kind": "mine", "rules": ["mine"],
     "expected_observations": {"mempool": [], "non_final_pool": [], "tip": "B1", "spent_on_chain": ["coin4"]},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "r3", "action": {"type": "restart", "persistmempool": true, "clock": "tload", "mempoolexpirynonfinal": 336}, "kind": "restart", "rules": ["persist"],
     "expected_observations": {"mempool": ["D", "K"], "non_final_pool": ["L", "N"], "tip": "B1",
       "entry_times": {"D": "t1", "K": "t1"}, "fee_deltas": {"K": 1000},
       "files_read": {"mempool": ["E", "K", "D", "C", "L"], "deltas": [], "non_final": ["N", "Nold"]},
       "load": {"mempool": {"E": "expired", "K": "accepted", "D": "accepted", "C": "missingInputs", "L": "heldNonFinal"},
                "non_final": {"N": "heldNonFinal", "Nold": "expired"}},
       "counts": {"mempool": [3, 1, 1], "non_final": [1, 0, 1]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"},
    {"id": "z1", "action": {"type": "stop"}, "kind": "restart", "rules": ["persist"],
     "expected_observations": {"files_written": {"mempool": ["K", "D"], "deltas": [], "non_final": ["L", "N"]}},
     "label": "[D]", "node": "measured agree [X] docs/records/20261015-130103-s7-81-persist-s1.md"}
  ],
  "replay": "harness/src/scenarios/persist.rs (run_scenarios --persist) on a fresh instance; lean chaincheck --persist for the projection"
}
```
