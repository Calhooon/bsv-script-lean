# inMempool status vocabulary witness

[M] 2026-10-13. Scenario `2026-10-13-status-view-inMempool`; [M] two declared observation steps.
[D] Every word here describes a view, never a rule. The [format and profile](README.md)
provide the common isolated synthetic prefix. The generated [table](../../spec/status-views.md)
uses this id in every no-function cell of its `inMempool` row.

[D] Initial chain: mine the private regtest prefix to height 100, then fund
F in base at height 101. Genesis activation is explicitly set to 100, a
selected scenario input. No public peer or standing node is contacted.
For the held fixture, the OP_TRUE funding output H is mined at height 102;
T has lockTime 103 and sequence zero. The Lean witness shifts this pair to
height 101 / lockTime 102, preserving the held predicate and completed admission.
The other fixtures use the common tip. The Lean projection uses a pre-Genesis
P2SH funding coin at height 99 and eligible OP_TRUE new outputs; the node
uses the independently materialized signed funding bytes recorded with the run.
This is agreement of the stated status class, not byte equality of the two fixtures. Only T is a watched status; raw receipts
also retain all funding and spender bodies, pools, tips and chain-only outputs.

[D] Establish: Submit T with sendrawtransaction. Observe T in getrawmempool and empty held/orphan pools.
Context-change varies explicit independent producer inputs while the node stays
unchanged. Arcade uses an initial UNKNOWN record with receipt absent/present,
with no later event applied; a terminal MINED prior record is incompatible.
For structurally valid T, a signed delayed request without noSend derives unsent,
and signed noSend without sendWith derives nosend. Input-empty rejected T instead
uses believed prior send plus absent/present rejection notification: unknown/invalid.
A wallet's old unprocessed record with updated_at 1, now 100 and abandonedMsecs 10
has the failure step applied; a failed-filter recovery label then changes stored
failed to unfail. It says nothing about current node position or wallet wire status.
A validator HTTP protobuf skip_policy_checks input is rejected before processing
with BadRequest; default options instead produce a declared validation error
with nonempty reason: ErrTxMissingParent with the producer's parent absent for
structurally valid T, or ErrTxInvalid for input-empty T. The source returns
Valid=false WITH this error, so HTTP's error dispatch yields InternalServerError. Propagation ErrInvalidArgument derives BadRequest and
ErrServiceError takes the dispatch default InternalServerError arm. No successful
service response or overload is assumed for the input-empty transaction.
These source-step models are [D]. Lean and Rust verify their predicates and reject
incompatible inputs. The partial MINED, REJECTED, doubleSpend and invalid cells are evaluated separately
from stored Arcade/request history, using actual active or off-active body,
completed rejection receipt and exact spender evidence. Semantic outputs are
explicit expectations under semantic_views; stored context words stay separate.

[SRC] Arcade `models/transaction.go:90-93,110-111,167-176` at `1ae1208e`;
ts-stack `sdk/types.ts:22-34,46,48,50`, `storage/methods/processAction.ts:359-370`,
`monitor/tasks/TaskFailAbandoned.ts:36-46`, `storage/methods/ListActionsSpecOp.ts:123-139`
under `packages/wallet/wallet-toolbox/src/` at `edf6e03d`;
Teranode `services/validator/Server.go:733-740,899-909,970-1002`,
`services/validator/http_options_guard.go:57-59`,
`services/validator/Validator.go:1657-1663,2723-2728`,
`services/validator/ScriptVerifierGoBDK.go:401-433`,
`services/propagation/Server.go:759-790`, `errors/Error_types.go:31,37`
at `v0.16.0` (`4edb60a4`).
[SRC] Node observations and ordered status clauses: DESIGN-S6 sections 2.1,
3 and 5.1 at bitcoin-sv `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`.
No-function on retained cells records a source-step obstruction; partial domains are functions.

| step | T status [D] | client context [D] | node |
|---|---|---|---|
| establish | inMempool | UNKNOWN; unsent; failed; BadRequest; BadRequest | measured agree [X] docs/records/20261013-161732-s6-fix-67-regtest-s3.md |
| context-change | inMempool | RECEIVED; nosend; unfail; InternalServerError; InternalServerError | measured agree [X] docs/records/20261013-161732-s6-fix-67-regtest-s3.md |

[D] Replay compares the two independently declared statuses to the RPC evidence
and Lean executable, checks declared inputs and source predicates, and records all six
Lean cells. The orphan completion additionally binds the count to this one
withheld-parent child and its successful retry. Source words and depth policy
are client views; no definition here adds an admission or block rule.

```json
{
  "id": "2026-10-13-status-view-inMempool",
  "class": "status vocabulary view, never a rule",
  "witness": "equal node status; receipt, signed send intent or rejection history, failed-wallet recovery label, HTTP options/response and propagation cause predicates",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "source_date": "2026-10-13",
  "initial_chain": {
    "profile": "regtest-status-views",
    "params": "BsvChain.ChainParams.regtest with explicit genesisHeight 100",
    "config": "README regtest-intake plus genesisactivationheight=100; loopback listener only for orphan witness",
    "active_tip": {
      "block": "base",
      "height": 101
    },
    "mock_time": 1700000000,
    "mempool": [],
    "non_final_pool": [],
    "orphan_pool": [],
    "rejected_journal": {},
    "watched_transactions": [
      "T"
    ],
    "fixture_names": [
      "F",
      "T",
      "P",
      "H",
      "K"
    ],
    "transactions": {
      "T": {
        "value": "unknown",
        "label": "[D]",
        "node": "pending #66",
        "rules": [
          "unchanged"
        ]
      }
    },
    "seen": [
      "F"
    ]
  },
  "steps": [
    {
      "id": "establish",
      "action": {
        "type": "statusFixture",
        "recipe": "inMempool",
        "operations": [
          "Submit T with sendrawtransaction.",
          "Observe T in getrawmempool and empty held/orphan pools."
        ],
        "producer_inputs": {
          "receipt_delivered": false,
          "arcade_prior": "BsvChain.Views.Arcade.UNKNOWN",
          "later_arcade_event": false,
          "signed_complete": true,
          "structurally_valid": true,
          "no_send": false,
          "delayed": true,
          "send_with": false,
          "believed_sent": false,
          "rejection_delivered": false,
          "wallet_before_failure": "BsvChain.Views.WalletTransaction.unprocessed",
          "wallet_updated_at": 1,
          "wallet_now": 100,
          "wallet_abandoned_msecs": 10,
          "wallet_failure_applied": true,
          "failed_filter_selected": true,
          "recovery_label": false,
          "validator_skip_policy_checks": true,
          "validator_response_valid": false,
          "validator_reason": "local producer validation failed",
          "propagation_cause": "ErrInvalidArgument",
          "validator_error_cause": "",
          "validator_parent_known": false
        }
      },
      "kind": "derived status view; unchanged producer-context boundary",
      "rules": [
        "status-view-inMempool",
        "unchanged"
      ],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-033243-s6-72-views-regtest-s3.md",
      "expected_observations": {
        "transactions": {
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-033243-s6-72-views-regtest-s3.md",
            "rules": [
              "status-view-inMempool"
            ]
          }
        },
        "client_views": {
          "Arcade": "UNKNOWN",
          "ProvenTxReqStatus": "unsent",
          "TransactionStatus": "failed",
          "Teranode validator": "BadRequest",
          "Teranode propagation": "BadRequest"
        },
        "client_label": "[D] outputs of Views.contextWords, not producer measurements",
        "status_view_witness": "2026-10-13-status-view-inMempool",
        "node_state_unchanged_from": null,
        "semantic_views": {
          "label": "[D]",
          "outputs": {}
        }
      }
    },
    {
      "id": "context-change",
      "action": {
        "type": "observeClient",
        "context": "alternate",
        "node_transition": false,
        "producer_inputs": {
          "receipt_delivered": true,
          "arcade_prior": "BsvChain.Views.Arcade.UNKNOWN",
          "later_arcade_event": false,
          "signed_complete": true,
          "structurally_valid": true,
          "no_send": true,
          "delayed": false,
          "send_with": false,
          "believed_sent": false,
          "rejection_delivered": false,
          "wallet_before_failure": "BsvChain.Views.WalletTransaction.unprocessed",
          "wallet_updated_at": 1,
          "wallet_now": 100,
          "wallet_abandoned_msecs": 10,
          "wallet_failure_applied": true,
          "failed_filter_selected": true,
          "recovery_label": true,
          "validator_skip_policy_checks": false,
          "validator_response_valid": false,
          "validator_reason": "local producer validation failed",
          "propagation_cause": "ErrServiceError",
          "validator_error_cause": "ErrTxMissingParent",
          "validator_parent_known": false
        }
      },
      "kind": "derived status view; unchanged producer-context boundary",
      "rules": [
        "status-view-inMempool",
        "unchanged"
      ],
      "label": "[D]",
      "node": "measured agree [X] docs/records/20261014-033243-s6-72-views-regtest-s3.md",
      "expected_observations": {
        "transactions": {
          "T": {
            "value": "inMempool",
            "label": "[D]",
            "node": "measured agree [X] docs/records/20261014-033243-s6-72-views-regtest-s3.md",
            "rules": [
              "status-view-inMempool"
            ]
          }
        },
        "client_views": {
          "Arcade": "RECEIVED",
          "ProvenTxReqStatus": "nosend",
          "TransactionStatus": "unfail",
          "Teranode validator": "InternalServerError",
          "Teranode propagation": "InternalServerError"
        },
        "client_label": "[D] outputs of Views.contextWords, not producer measurements",
        "status_view_witness": "2026-10-13-status-view-inMempool",
        "node_state_unchanged_from": "establish",
        "semantic_views": {
          "label": "[D]",
          "outputs": {}
        }
      }
    }
  ],
  "variants": [],
  "replay": {
    "runner": "tools/node_scenarios.sh --status-views-only",
    "node": "measured agree [X] docs/records/20261013-161732-s6-fix-67-regtest-s3.md",
    "client": "[D] derived local input projections only; external programs are not run",
    "record": "docs/records/20261013-161732-s6-fix-67-regtest-s3.md"
  }
}
```
