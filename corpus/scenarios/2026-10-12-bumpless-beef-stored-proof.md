# A stored bump-less BEEF does not establish inclusion

[M] Scenario `2026-10-12-bumpless-beef-stored-proof`; [M] 10 declared steps. Every expected
observation below and in JSON is [D]; every node verdict is `measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md`.
The [format, regtest profile and rule citations](README.md) are normative
for this seed. This page contains synthetic names only.

## Class and witness

[D] A raw transaction with missing ancestry is stored after a zero-bump
shortcut. The wallet later returns an incomplete assembly from that stored
stub and its strict credit door refuses it. The legacy application still
announces `Paid`. The audit stored the stub while the subject was unmined;
b1 supplies that admission context. This seed deliberately delays delivery
until after b2 mines `T`, so b3 also tests that even a real mined transaction
cannot be authenticated by a path-less, header-less envelope. Storage and
active-chain inclusion are different observations.

## Initial chain and steps

[D] Use `regtest-intake` from the format page. Named bodies, blocks and
outpoints are symbolic fixtures for #66 to materialize, never incident bytes.
The JSON specifies delivery boundaries as well as node actions. Variants
restart at their named checkpoint, including that checkpoint's client history.

[D] Primary b1–b6 separates mining, stub storage, the wallet's refusal,
proof checking and ledger credit. `U` is built locally but never submitted;
it stays `unknown` to the node even when the wallet accepts its credit.
The refusal in b4 carries `F`'s BUMP without its transaction entry to expose
the missing-source check; that BUMP is not a proof of `T` or `U`.
A header/path for `T` is absent until b5.
[M] 2026-10-13: #65 implements `verifyPath` and S6-1's membership-or-collision
theorem with explicit commitment/shape premises; #75's codec remains owed.
The runner now sends the fetched branch to Lean for root verification.

[D] Variant q1–q4 invalidates A, expires re-admitted T, mines T on B and checks
a replacement path. A remains invalid while B is selected, avoiding an
unresolved tie. The old path remains a root-equality witness for A and has no
active inclusion in B. q3 and q4 have the same node status with different
client evidence. `client_evidence.status` is the format's conservative
projection; it never overwrites the node's `transactions` status.

[D] q2 executes the format's explicit `action.trigger` RPC batch after
changing mock time: `LimitMempoolSize` completes expiry and applies the
mining-journal removal before pool reads ([SRC]
`src/validation.cpp:847–879`, `src/txmempool.cpp:2201–2221`; DESIGN-S6 §2.1
row 14 and §2.5). Its implementation is owed to #66. The event adds no
transaction or rejection, so the expected pool sets and node statuses are
unchanged. Before changing `tracker_T` or `client_evidence.status`, q2
delivers the completed result, fresh empty accepted/non-final sets, the
unchanged active base and A's retained T body with off-active confirmations.
DESIGN-S6 §3 rows 2–4 then fail and row 5 applies ([SRC] pool observations
`src/rpc/blockchain.cpp:440–502`; off-active confirmations
`src/rpc/blockchain.cpp:79–90`). q3 retains this delivered stale evidence
while its replacement body/path is withheld.

## Expected observations per machine

[D] `F` remains `minedActive 101` throughout. The table abbreviates the exact
pool, tip, transaction and client observations in JSON; the rule ids expand to
DESIGN-S6 sections/rows and pinned source lines in README. The client column
is the divergent history under test; a later repair is explicitly named.

| step | T status [D] | other status [D] | client observations [D] | source rules | node |
|---|---|---|---|---|---|
| b1 | inMempool | U=unknown | absent; not attempted; pending; pending; T display=unconfirmed | receive | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| b2 | minedActive 102 | U=unknown | absent; not attempted; pending; pending; T display=unconfirmed | mine | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| b3 | minedActive 102 | U=unknown | completed/proven (stored, unchecked); not attempted; pending; pending; T display=unconfirmed | unchanged, path | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| b4 | minedActive 102 | U=unknown | completed/proven (stored, unchecked); refused: InputNamesNoElement; POT_INTERNALIZED / Paid (legacy, no ledger credit); REFUSED; T display=unconfirmed | unchanged | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| b5 | minedActive 102 | U=unknown | completed/proven (checked A); refusal retained; not retried; credit pending (corrected receipt); PARKED; T display=confirmed | path, unchanged | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| b6 | minedActive 102 | U=unknown | completed/proven (checked A); credited; POT_INTERNALIZED / Paid (ledger-backed); LANDED; T display=confirmed | unchanged, path | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| q1 | inMempool | U=unknown | completed/proven (stale A latch); credited; Paid; LANDED; T display=unconfirmed | invalidate, path | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| q2 | onStaleBranch | U=unknown | completed/proven (stale A latch); credited; Paid; LANDED; T display=unconfirmed | expiry, path | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| q3 | minedActive 102 | U=unknown | completed/proven (stale A latch); credited; Paid; LANDED; T display=unconfirmed | mine, path | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |
| q4 | minedActive 102 | U=unknown | completed/proven (checked B); credited; Paid; LANDED; T display=confirmed | path, unchanged | measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md |

## Trace as data

[M] #64 spec projection: `chaincheck` executes the mapped chain/pool steps on explicit derived P2SH fixtures and an assumed prefix; the added `spec` fields record agreement for accepted/held sets, tip, chain tips and chain UTXOs. Client, transaction-status and path assertions remain [D] and owed; node columns remain measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md.

```json
{
  "id": "2026-10-12-bumpless-beef-stored-proof",
  "class": "bump-less BEEF stored as proven ancestry, then the wallet refuses its own credit",
  "witness": "zero-BUMP stored stub stops ancestry; F BUMP lacks its transaction entry; provenance in the intake record",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "initial_chain": {
    "profile": "regtest-intake",
    "input_label": "[D]",
    "params": "BsvChain.ChainParams.regtest",
    "config": "README.md initial-chain profile",
    "active_tip": {
      "block": "base",
      "height": 101
    },
    "mock_time": 1700000000,
    "adjusted_time_offset": 0,
    "mempool": [],
    "non_final_pool": [],
    "orphan_pool": [],
    "rejected_journal": {},
    "seen": [
      "F"
    ],
    "watched_transactions": [
      "F",
      "T",
      "U"
    ],
    "transactions": {
      "F": {
        "value": "minedActive",
        "label": "[D]",
        "rules": [
          "mine"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
        "height": 101
      },
      "T": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md"
      },
      "U": {
        "value": "unknown",
        "label": "[D]",
        "rules": [
          "unchanged"
        ],
        "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md"
      }
    }
  },
  "steps": [
    {
      "id": "b1",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "submit",
        "transaction": "T",
        "now": 1700000000,
        "client_input": "raw T only; node pool receipt not delivered to the client"
      },
      "kind": "policy admission; consensus prerequisites",
      "rules": [
        "receive"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [
          "T"
        ],
        "non_final_pool": [],
        "tip": {
          "block": "base",
          "height": 101
        },
        "chain_tips": [
          {
            "block": "base",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "rules": [
              "receive"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "unspent",
          "T:credit": "absent",
          "U:credit": "absent"
        },
        "evidence": [
          "getrawmempool = [T]; getrawnonfinalmempool = []; getbestblockhash = base",
          "U has never been submitted; complete journal has no matching clause"
        ],
        "client_views": {
          "wallet_T": "absent",
          "wallet_credit_U": "not attempted",
          "app_U": "pending",
          "credit_receipt": "pending",
          "stored_proof_header": null,
          "tracker_T": {
            "value": "unknown"
          },
          "application_T": "unconfirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "unknown"
          },
          "seen_body": [
            "T"
          ],
          "path_header": null,
          "checked_active_inclusion": false,
          "basis": "no checked active inclusion; raw-body delivery is only seen"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "base",
              "status": "active"
            }
          ],
          "mempool": [
            "T"
          ],
          "non_final_pool": [],
          "tip": {
            "block": "base",
            "height": 101
          },
          "utxos": {
            "F:fund": "unspent",
            "T:credit": "absent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "b2",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "mine",
        "branch": "A",
        "parent": "base",
        "block": "A",
        "transactions": [
          "T"
        ],
        "assembly": "observed (#72): the node's generatetoaddress body; the machine replays it [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "now": 1700000001,
        "client_input": "withhold the header and path"
      },
      "kind": "consensus inclusion/finality; no client inclusion evidence",
      "rules": [
        "mine"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "getblock A contains T at height 102 with positive confirmations; getbestblockhash = A",
          "node body evidence is retained by the harness, not delivered to the client",
          "gettxout T:credit is unspent; no U receipt"
        ],
        "client_views": {
          "wallet_T": "absent",
          "wallet_credit_U": "not attempted",
          "app_U": "pending",
          "credit_receipt": "pending",
          "stored_proof_header": null,
          "tracker_T": {
            "value": "unknown"
          },
          "application_T": "unconfirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "unknown"
          },
          "seen_body": [
            "T"
          ],
          "path_header": null,
          "checked_active_inclusion": false,
          "basis": "no checked active inclusion; raw-body delivery is only seen"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "A",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "A",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "T:credit": "unspent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "b3",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "serveBeef",
        "subject": "T",
        "raw_transactions": [
          "T"
        ],
        "bumps": [],
        "headers": [],
        "missing_sources": [
          "F"
        ],
        "client_input": "legacy zero-bump store bypass writes completed/proven"
      },
      "kind": "client storage; no node transition or inclusion proof",
      "rules": [
        "unchanged",
        "path"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine",
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "repeat b2 node observations",
          "BEEF contains no path and no header; raw T still names absent F",
          "wallet storage is the defective view under test, not a node acceptance"
        ],
        "client_views": {
          "wallet_T": "completed/proven (stored, unchecked)",
          "wallet_credit_U": "not attempted",
          "app_U": "pending",
          "credit_receipt": "pending",
          "stored_proof_header": null,
          "tracker_T": {
            "value": "unknown"
          },
          "application_T": "unconfirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "unknown"
          },
          "seen_body": [
            "T"
          ],
          "path_header": null,
          "checked_active_inclusion": false,
          "basis": "no checked active inclusion; raw-body delivery is only seen"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "A",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "A",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "T:credit": "unspent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "b4",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "walletRoundTrip",
        "subject": "U",
        "build": "U spends T:credit; legacy stored T stops the ancestry walk",
        "raw_transactions": [
          "T",
          "U"
        ],
        "bumps": [
          "F path only; no F transaction entry"
        ],
        "headers": [],
        "client_input": "strict door refuses the incomplete assembly; legacy application latches POT_INTERNALIZED/Paid"
      },
      "kind": "client ancestry/receipt; no node rejection",
      "rules": [
        "unchanged"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine",
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "repeat b2 node observations; U remains unsubmitted and unknown",
          "local strict body check finds F missing; adding its BUMP alone supplies no transaction entry",
          "wallet receipt refused; ledger U:credit absent; node rejected journal unchanged"
        ],
        "client_views": {
          "wallet_T": "completed/proven (stored, unchecked)",
          "wallet_credit_U": "refused: InputNamesNoElement",
          "app_U": "POT_INTERNALIZED / Paid (legacy, no ledger credit)",
          "credit_receipt": "REFUSED",
          "stored_proof_header": null,
          "tracker_T": {
            "value": "unknown"
          },
          "application_T": "unconfirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "unknown"
          },
          "seen_body": [
            "T"
          ],
          "path_header": null,
          "checked_active_inclusion": false,
          "basis": "no checked active inclusion; raw-body delivery is only seen"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "A",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "A",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "T:credit": "unspent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "b5",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "checkPath",
        "transaction": "T",
        "block": "A",
        "rpc": "getmerkleproof",
        "codec": "#75 owed",
        "verifyPath": "BsvChain.verifyPath (#65, 2026-10-13)",
        "checks": [
          "subject leaf and index/path shape",
          "root equals A header root",
          "A is on active chain",
          "S6-1 membership-or-collision theorem under its stated commitment hypothesis"
        ],
        "client_input": "deliver and check path/header; retry budget is exhausted without another wallet call"
      },
      "kind": "consensus inclusion evidence; client scheduling policy",
      "rules": [
        "path",
        "unchanged"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine",
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "getmerkleproof T for A; getblock A selected active body still contains T",
          "record leaf index, siblings, header and Lean verifyPath; #75 codec remains owed",
          "getrawmempool = []; no node call involving U"
        ],
        "client_views": {
          "wallet_T": "completed/proven (checked A)",
          "wallet_credit_U": "refusal retained; not retried",
          "app_U": "credit pending (corrected receipt)",
          "credit_receipt": "PARKED",
          "stored_proof_header": "A",
          "tracker_T": {
            "value": "minedActive",
            "height": 102
          },
          "application_T": "confirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "minedActive",
            "height": 102
          },
          "seen_body": [
            "T"
          ],
          "path_header": "A",
          "checked_active_inclusion": true,
          "basis": "path"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "A",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "A",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "T:credit": "unspent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    },
    {
      "id": "b6",
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
      "action": {
        "type": "walletRoundTrip",
        "subject": "U",
        "raw_transactions": [
          "T",
          "U"
        ],
        "bumps": [
          "checked T path to A"
        ],
        "headers": [
          "A"
        ],
        "client_input": "manual retry of the repaired complete envelope; accept the credit into the wallet ledger"
      },
      "kind": "client ledger receipt; node state unchanged",
      "rules": [
        "unchanged",
        "path"
      ],
      "expected_observations": {
        "label": "[D]",
        "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
        "mempool": [],
        "non_final_pool": [],
        "tip": {
          "block": "A",
          "height": 102
        },
        "chain_tips": [
          {
            "block": "A",
            "status": "active"
          }
        ],
        "transactions": {
          "F": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 101
          },
          "T": {
            "value": "minedActive",
            "label": "[D]",
            "rules": [
              "mine",
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "height": 102
          },
          "U": {
            "value": "unknown",
            "label": "[D]",
            "rules": [
              "unchanged"
            ],
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
          }
        },
        "utxos": {
          "F:fund": "spent",
          "T:credit": "unspent",
          "U:credit": "absent"
        },
        "evidence": [
          "repeat b5 node and proof observations",
          "strict assembly now terminates at checked T; wallet ledger records U:credit",
          "U has not been submitted to the node; wallet credit cannot manufacture node inclusion"
        ],
        "client_views": {
          "wallet_T": "completed/proven (checked A)",
          "wallet_credit_U": "credited",
          "app_U": "POT_INTERNALIZED / Paid (ledger-backed)",
          "credit_receipt": "LANDED",
          "stored_proof_header": "A",
          "tracker_T": {
            "value": "minedActive",
            "height": 102
          },
          "application_T": "confirmed"
        },
        "client_evidence": {
          "label": "[D]",
          "node": "pending #66",
          "status": {
            "value": "minedActive",
            "height": 102
          },
          "seen_body": [
            "T"
          ],
          "path_header": "A",
          "checked_active_inclusion": true,
          "basis": "path"
        }
      },
      "spec": {
        "agree": true,
        "label": "[M]",
        "observed": {
          "chain_tips": [
            {
              "block": "A",
              "status": "active"
            }
          ],
          "mempool": [],
          "non_final_pool": [],
          "tip": {
            "block": "A",
            "height": 102
          },
          "utxos": {
            "F:fund": "spent",
            "T:credit": "unspent",
            "U:credit": "absent"
          }
        },
        "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
        "runner": "chaincheck",
        "run_utc": "2026-10-12T19:22:17Z"
      }
    }
  ],
  "variants": [
    {
      "id": "invalidate-expire-remine",
      "fork_after": "b6",
      "steps": [
        {
          "id": "q1",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "invalidateBlock",
            "block": "A",
            "now": 1700000002,
            "completion": "clean undo and policy re-admission completed",
            "client_input": "deliver chain event and fresh pool observation; keep legacy wallet proven latch"
          },
          "kind": "operator invalidation; consensus undo; policy re-admission",
          "rules": [
            "invalidate",
            "path"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "mempool": [
              "T"
            ],
            "non_final_pool": [],
            "tip": {
              "block": "base",
              "height": 101
            },
            "chain_tips": [
              {
                "block": "base",
                "status": "active"
              },
              {
                "block": "A",
                "status": "invalid"
              }
            ],
            "transactions": {
              "F": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 101
              },
              "T": {
                "value": "inMempool",
                "label": "[D]",
                "rules": [
                  "invalidate"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              },
              "U": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "unchanged"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              }
            },
            "utxos": {
              "F:fund": "unspent",
              "T:credit": "absent",
              "U:credit": "absent"
            },
            "evidence": [
              "getbestblockhash = base; getchaintips A invalid; getblock A confirmations = -1",
              "getrawmempool = [T]; old path still recomputes A root but A is not active",
              "U remains unknown to the node; active inclusion must be withdrawn"
            ],
            "client_views": {
              "wallet_T": "completed/proven (stale A latch)",
              "wallet_credit_U": "credited",
              "app_U": "Paid",
              "credit_receipt": "LANDED",
              "stored_proof_header": "A",
              "tracker_T": {
                "value": "inMempool"
              },
              "application_T": "unconfirmed"
            },
            "client_evidence": {
              "label": "[D]",
              "node": "pending #66",
              "status": {
                "value": "inMempool"
              },
              "seen_body": [
                "T"
              ],
              "path_header": "A",
              "checked_active_inclusion": false,
              "basis": "no checked active inclusion; raw-body delivery is only seen"
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [
                "T"
              ],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "T:credit": "absent",
                "U:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "q2",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "advanceTime",
            "now": 1701209603,
            "maintenance": "accepted-pool expiry completed",
            "condition": "now > q1 re-admission time + cfg.mempoolExpiry",
            "trigger": {
              "type": "rpc",
              "rpc": "sendrawtransactions",
              "transactions": [
                "sweep0",
                "sweep1"
              ],
              "after": "setmocktime(now) returned; no pending fixture validation",
              "completion": "both input-empty rejection receipts returned; new Expired 1 transactions from the memory pool log line captured; fresh pools read",
              "effects": {
                "accepted_pool": "remove T and descendants; no auxiliary admission",
                "mining_journal": "remove expired T before RPC completion",
                "chain_and_node_journals": "unchanged fixture chain and journals; two auxiliary rejection receipts recorded separately",
                "size_eviction": "none; profile has no memory pressure"
              },
              "sources": [
                "[SRC] src/rawtxvalidator.cpp:54-92,126-138",
                "[SRC] src/txn_validator.cpp:216-228,303-314",
                "[SRC] src/rpc/rawtransaction.cpp:2134-2155",
                "[SRC] src/validation.cpp:853-856"
              ]
            },
            "client_input": "after trigger completion, deliver the completed maintenance result and fresh getrawmempool = [], getrawnonfinalmempool = [], getbestblockhash = base, getchaintips A invalid and getblock A containing T with confirmations = -1; retain the old A path and legacy wallet proven latch"
          },
          "kind": "policy expiry; stale proof retained",
          "rules": [
            "expiry",
            "path",
            "invalidate"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "base",
              "height": 101
            },
            "chain_tips": [
              {
                "block": "base",
                "status": "active"
              },
              {
                "block": "A",
                "status": "invalid"
              }
            ],
            "transactions": {
              "F": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 101
              },
              "T": {
                "value": "onStaleBranch",
                "label": "[D]",
                "rules": [
                  "expiry",
                  "invalidate"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              },
              "U": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "unchanged"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              }
            },
            "utxos": {
              "F:fund": "unspent",
              "T:credit": "absent",
              "U:credit": "absent"
            },
            "evidence": [
              "setmocktime returned; action.trigger returned with T EXPIRY removal and mining-journal change applied; getrawmempool = []; getrawnonfinalmempool = []",
              "getbestblockhash = base; getblock A still contains T with confirmations = -1; settled empty pools and unchanged isolated orphan history exclude DESIGN-S6 \u00a73 rows 2\u20134, so row 5 applies",
              "deliver these fresh pool, active-tip and off-active body observations to the client before tracker_T and client_evidence.status change; the old A path remains a root-equality witness without active inclusion"
            ],
            "client_views": {
              "wallet_T": "completed/proven (stale A latch)",
              "wallet_credit_U": "credited",
              "app_U": "Paid",
              "credit_receipt": "LANDED",
              "stored_proof_header": "A",
              "tracker_T": {
                "value": "onStaleBranch"
              },
              "application_T": "unconfirmed"
            },
            "client_evidence": {
              "label": "[D]",
              "node": "pending #66",
              "status": {
                "value": "onStaleBranch"
              },
              "seen_body": [
                "T"
              ],
              "path_header": "A",
              "checked_active_inclusion": false,
              "basis": "delivered completed expiry and fresh empty accepted/non-final sets, unchanged active base and retained off-active A body containing T; DESIGN-S6 \u00a72.1 row 14, \u00a72.5 and \u00a73 rows 2\u20135; old A path has no active inclusion"
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "base",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "base",
                "height": 101
              },
              "utxos": {
                "F:fund": "unspent",
                "T:credit": "absent",
                "U:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "q3",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "mine",
            "branch": "B",
            "parent": "base",
            "block": "B",
            "transactions": [
              "T"
            ],
            "method": "submitblock",
            "now": 1701209604,
            "client_input": "deliver B header but withhold the replacement path/body"
          },
          "kind": "consensus re-inclusion; client still lacks current path",
          "rules": [
            "mine",
            "path"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "B",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "B",
                "status": "active"
              },
              {
                "block": "A",
                "status": "invalid"
              }
            ],
            "transactions": {
              "F": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 101
              },
              "T": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 102
              },
              "U": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "unchanged"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              }
            },
            "utxos": {
              "F:fund": "spent",
              "T:credit": "unspent",
              "U:credit": "absent"
            },
            "evidence": [
              "getbestblockhash = B; getblock B contains T at height 102 with positive confirmations",
              "A remains invalid; no equal-work eligible candidate competes",
              "client keeps the old path to A; it cannot use that path to claim inclusion in B"
            ],
            "client_views": {
              "wallet_T": "completed/proven (stale A latch)",
              "wallet_credit_U": "credited",
              "app_U": "Paid",
              "credit_receipt": "LANDED",
              "stored_proof_header": "A",
              "tracker_T": {
                "value": "onStaleBranch"
              },
              "application_T": "unconfirmed"
            },
            "client_evidence": {
              "label": "[D]",
              "node": "pending #66",
              "status": {
                "value": "onStaleBranch"
              },
              "seen_body": [
                "T"
              ],
              "path_header": "A",
              "checked_active_inclusion": false,
              "basis": "retain q2 delivered empty-pool and off-active A-body evidence; B header delivered without replacement body/path, so no checked active inclusion in B"
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "B",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "B",
                "height": 102
              },
              "utxos": {
                "F:fund": "spent",
                "T:credit": "unspent",
                "U:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        },
        {
          "id": "q4",
          "label": "[D]",
          "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
          "action": {
            "type": "checkPath",
            "transaction": "T",
            "block": "B",
            "rpc": "getmerkleproof",
            "codec": "#75 owed",
            "verifyPath": "BsvChain.verifyPath (#65, 2026-10-13)",
            "checks": [
              "leaf identity and shape",
              "B header root",
              "B active membership",
              "S6-1 theorem under stated hypothesis"
            ],
            "client_input": "replace the stale path and recheck inclusion"
          },
          "kind": "consensus inclusion evidence; no new node transition",
          "rules": [
            "path",
            "unchanged"
          ],
          "expected_observations": {
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
            "mempool": [],
            "non_final_pool": [],
            "tip": {
              "block": "B",
              "height": 102
            },
            "chain_tips": [
              {
                "block": "B",
                "status": "active"
              },
              {
                "block": "A",
                "status": "invalid"
              }
            ],
            "transactions": {
              "F": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 101
              },
              "T": {
                "value": "minedActive",
                "label": "[D]",
                "rules": [
                  "mine",
                  "unchanged"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md",
                "height": 102
              },
              "U": {
                "value": "unknown",
                "label": "[D]",
                "rules": [
                  "unchanged"
                ],
                "node": "measured agree [X] docs/records/20261014-032012-s6-72-regtest-s3.md"
              }
            },
            "utxos": {
              "F:fund": "spent",
              "T:credit": "unspent",
              "U:credit": "absent"
            },
            "evidence": [
              "getmerkleproof T for B and selected active B body; record the complete replacement evidence",
              "getbestblockhash = B; old A proof remains only a history record"
            ],
            "client_views": {
              "wallet_T": "completed/proven (checked B)",
              "wallet_credit_U": "credited",
              "app_U": "Paid",
              "credit_receipt": "LANDED",
              "stored_proof_header": "B",
              "tracker_T": {
                "value": "minedActive",
                "height": 102
              },
              "application_T": "confirmed"
            },
            "client_evidence": {
              "label": "[D]",
              "node": "pending #66",
              "status": {
                "value": "minedActive",
                "height": 102
              },
              "seen_body": [
                "T"
              ],
              "path_header": "B",
              "checked_active_inclusion": true,
              "basis": "path"
            }
          },
          "spec": {
            "agree": true,
            "label": "[M]",
            "observed": {
              "chain_tips": [
                {
                  "block": "A",
                  "status": "invalid"
                },
                {
                  "block": "B",
                  "status": "active"
                }
              ],
              "mempool": [],
              "non_final_pool": [],
              "tip": {
                "block": "B",
                "height": 102
              },
              "utxos": {
                "F:fund": "spent",
                "T:credit": "unspent",
                "U:credit": "absent"
              }
            },
            "scope": "symbolic chain/pool projection; standard P2SH fixture; assumed prefix; client/path/status projections owed",
            "runner": "chaincheck",
            "run_utc": "2026-10-12T19:22:17Z"
          }
        }
      ]
    }
  ],
  "replay": {
    "node": "measured agree [X] docs/records/20261013-032121-s6-66b-regtest-s3.md",
    "runner": "#66",
    "views": "#67",
    "verifyPath": "BsvChain.verifyPath (#65, 2026-10-13)",
    "proof_codec": "#75 owed",
    "client_columns": "derived local histories, not client runs"
  }
}
```

## Replay and boundary

[D] #66 owes node/evaluator replay, actual RPC receipts, maintenance-completion
evidence and the divergence report. #67 owes the client view functions or
no-function witnesses; the table is in README. No wallet, broadcaster or
node was run for this filing. Block-path inclusion and finality are consensus;
pool admission, non-final holding, expiry and eviction are policy. Operator
invalidation/reconsideration are settings, not a most-work theorem.
