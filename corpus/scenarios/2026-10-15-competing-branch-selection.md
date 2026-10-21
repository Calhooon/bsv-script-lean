# Competing branches: selection, the longest-chain mark, invalidate and reconsider (#93)

[M] 2026-10-15, lane s8-93. Scenario `2026-10-15-competing-branch-selection`; [M] seven primary steps after the
common prefix and three variants (`v-unknown` and `v-strict` one step each, `v-tie` two). [D] Every expectation here is read from source through the
Lean model, never measured; the reference column and the Teranode column (`second_oracle`) are both `pending #66`
and wait on #66's cut 2. A disagreement between the columns is a finding with this witness (rule 4), never a
sentence.

[D] Initial chain: the common intake prefix (`seed` in `harness/src/scenarios/core.rs`): 100 generated blocks
`g1` to `g100`, then `base` at height 101 holding `base:coinbase` and the funding transaction `F`. Synthetic
names only: `T` spends `F:fund`; `A` (holding `T`) and `B1` are sibling blocks on `base` of equal work; `B2`
extends `B1`. Every block after `A` is submitted to the reference by `submitblock`. Teranode v0.16.0 answers
`submitblock` as unimplemented (`services/rpc/Server.go:211` at `4edb60a4`; `docs/CONFORMANCE-RPC-CONTRACT.md` row
`submitblock`), so on Teranode `B1` and `B2` arrive from a peer (the runner's peer block source, owed by #66's cut 2)
and carry that peer's `peer_id`, while the generated blocks `g1` to `base` and `A` carry `peer_id` `""`
(`services/blockassembly/Server.go:2099`). No public peer, standing node or wallet is contacted. Nothing is broadcast.

[D] The Teranode column is read from `lean/BsvChain/Teranode/Chain.lean` at Teranode v0.16.0
(`4edb60a40c6628ff0ef60231c2628efd7103fde5`): the best header is the stored row not marked invalid with the most
`chain_work`, then the smallest `peer_id`, then the smallest insertion id (`best_maximal_work`); the
longest-chain mark clears `unminedSince` for a block's transactions as it joins the main chain and stamps an
absent one, backdated, as it leaves (`mark_off_on_identity`, `mark_on_off_restamps`); `invalidateblock` marks the
block and every descendant invalid at once; `reconsiderblock` revalidates the block in full and refuses one
whose parent is invalid (`reconsider_refuses_under_invalid_parent`). Every Teranode observation is taken with the
blockchain FSM in `RUNNING` (#97; `floater_invalidated_only_running`). The instance runs the defaults, where
optimistic mining is off on every path (`optimistic_off_at_defaults`).

[SRC] bitcoin-sv v1.2.3 at `6504a3aff65ba97c0f6c80962b033e35ecbfed4b`: `src/validation.cpp:4413-4494` (FindMostWorkChain),
`:4561-4824` (ActivateBestChainStep), `:4913-5126` (ActivateBestChain), `:5230-5330` (InvalidateBlock), `:5528-5562`
(ResetBlockFailureFlags, the ancestors at `:5554-5560`); `src/block_index.h:1225-1274` (the equal-work order);
`src/rpc/blockchain.cpp:2732-2768` (invalidateblock, "Block not found" at `:2752-2756`) and `:2770-2818`
(reconsiderblock); `src/txmempool.cpp:2330-2443` (re-admission after a disconnection). Teranode v0.16.0 at
`4edb60a40c6628ff0ef60231c2628efd7103fde5`: `stores/blockchain/sql/GetBestBlockHeader.go:114-137`,
`stores/blockchain/sql/StoreBlock.go:100-437`, `stores/blockchain/sql/InvalidateBlock.go:62-182`,
`stores/blockchain/sql/RevalidateBlock.go:11-72`, `services/rpc/handlers.go:1862-2028`,
`services/blockvalidation/BlockValidation.go:2001-2042`, `services/blockassembly/BlockAssembler.go:1108-1175`,
`stores/utxo/aerospike/longest_chain.go:49-196`, `stores/utxo/sql/sql.go:4892-4941`, `services/blockchain/fsm.go:17-42`.

| step | action | reference [D] | Teranode [D] |
|---|---|---|---|
| c1 | submit `T` | pool `[T]`, tip `base` | the same; `T` unmined |
| c2 | generate `A` on `base` | tip `A`; `T` minedActive | the same; `T`'s `unminedSince` cleared |
| c3 | submit `B1` on `base`, equal work | stored; tip `A` (received earlier) | stored; best `A` (equal work; `A`'s `peer_id` `""` sorts before the delivering peer's, `GetBestBlockHeader.go:135`) |
| c4 | submit `B2` on `B1` | reorg to `B2`; `T` re-admitted to the pool | best `B2`; `T` marked off the longest chain (stamp backdated) |
| c5 | invalidateblock `B1` | `B1`, `B2` failed; tip `A`; `T` minedActive | `B1`, `B2` invalid; best `A`; `T` marked on |
| c6 | reconsiderblock `B2` | `B2` and its ancestor `B1` cleared; tip `B2`; `T` back to the pool | refused, RPC -25 (parent invalid); best `A`; `T` still mined: **the witness** |
| c7 | reconsiderblock `B1` | nothing to clear; tip `B2` | `B1` then `B2` revalidated; best `B2`: the columns meet |
| v-unknown (after c2) | invalidateblock on a hash no node knows | RPC -5 "Block not found" | success, nothing moves (`invalidate_unknown`) |
| v-tie (after c1) | from `base`: `A` delivered by peer `p` and `B1` of equal work by peer `q`, `q` sorting before `p` in the store's text order (a generated `A` carries `""`, which no `peer_id` sorts before, `services/blockassembly/Server.go:2099`) | `A`: tip `A`, `T` minedActive; `B1`: stored, tip `A` (received earlier) | `A`: best `A`, `T`'s `unminedSince` cleared; `B1`: best `B1`, `T` leaves the longest chain with no more work (`equal_work_tie_moves_tip`) |
| v-strict (after c3) | submit `B2` on `B1` | reorg (strictly more work) | best `B2`, strictly more work (`tx_leaves_only_on_more_work`, its `old.work < new.work` case) |

[D] `c3`, `c4` (and so every later step), `v-strict` and `v-tie` need a peer block source on the Teranode instance
(`submitblock` is unimplemented there, `services/rpc/Server.go:211`); `v-tie` needs two, `p` and `q`, with a known
`peer_id` order; the runner's support is owed by #66's cut 2. `v-strict` repeats `c4` as the positive case of #93's third theorem.

```json
{
  "id": "2026-10-15-competing-branch-selection",
  "class": "chain selection and reorg (#93): the best header, the longest-chain mark, invalidate and reconsider on two nodes",
  "witness": "#93: BsvChain.Teranode.Chain.reconsider_descendant_differs (c6), equal_work_tie_moves_tip (v-tie), invalidate_unknown (v-unknown); the agreeing rows: best_maximal_work, tx_leaves_only_on_more_work, mark_off_on_identity",
  "label": "[D]",
  "input_label": "[D]",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "second_oracle_pin": "4edb60a40c6628ff0ef60231c2628efd7103fde5",
  "model": "lean/BsvChain/Teranode/Chain.lean",
  "initial_chain": {"profile": "regtest-intake", "prefix": "core::seed: g1..g100 generated, base at 101 with F", "second_oracle_fsm": "RUNNING"},
  "steps": [
    {"id": "c1", "action": {"type": "submit", "tx": "T"}, "kind": "accept", "rules": ["receive"],
     "expected_observations": {"mempool": ["T"], "tip": {"block": "base", "height": 101}, "transactions": {"T": {"value": "inMempool", "label": "[D]"}}},
     "second_oracle": {"best": "base", "unmined": ["T"], "label": "[D]"},
     "label": "[D]", "node": "pending #66"},
    {"id": "c2", "action": {"type": "mine", "block": "A", "parent": "base"}, "kind": "connect", "rules": ["mine"],
     "expected_observations": {"mempool": [], "tip": {"block": "A", "height": 102}, "transactions": {"T": {"value": "minedActive", "height": 102, "label": "[D]"}}},
     "second_oracle": {"best": "A", "unmined": [], "unminedSince": {"T": null}, "label": "[D]"},
     "label": "[D]", "node": "pending #66"},
    {"id": "c3", "action": {"type": "mine", "block": "B1", "parent": "base", "method": "submitblock", "transactions": ["B1:coinbase"]}, "second_oracle_route": "a peer (submitblock unimplemented, services/rpc/Server.go:211)", "kind": "store", "rules": ["unchanged"],
     "expected_observations": {"mempool": [], "tip": {"block": "A", "height": 102}, "transactions": {"T": {"value": "minedActive", "height": 102, "label": "[D]"}}},
     "second_oracle": {"best": "A", "tie_order": "chain_work DESC, peer_id ASC, id ASC: equal work, A's peer_id \"\" before B1's", "label": "[D]"},
     "label": "[D]", "node": "pending #66"},
    {"id": "c4", "action": {"type": "mine", "block": "B2", "parent": "B1", "method": "submitblock", "transactions": ["B2:coinbase"]}, "second_oracle_route": "a peer (submitblock unimplemented, services/rpc/Server.go:211)", "kind": "reorg", "rules": ["mine"],
     "expected_observations": {"mempool": ["T"], "tip": {"block": "B2", "height": 103}, "transactions": {"T": {"value": "inMempool", "label": "[D]"}}},
     "second_oracle": {"best": "B2", "unmined": ["T"], "unminedSince": {"T": "backdated: max(1, height - 144)"}, "label": "[D]"},
     "label": "[D]", "node": "pending #66"},
    {"id": "c5", "action": {"type": "invalidateBlock", "block": "B1"}, "kind": "reorg", "rules": ["invalidate"],
     "expected_observations": {"mempool": [], "tip": {"block": "A", "height": 102}, "chain_tips": {"A": "active", "B2": "invalid"}, "transactions": {"T": {"value": "minedActive", "height": 102, "label": "[D]"}}},
     "second_oracle": {"best": "A", "invalid": ["B1", "B2"], "unmined": [], "label": "[D]"},
     "label": "[D]", "node": "pending #66"},
    {"id": "c6", "action": {"type": "reconsiderBlock", "block": "B2"}, "kind": "reorg", "rules": ["reconsider"],
     "expected_observations": {"mempool": ["T"], "tip": {"block": "B2", "height": 103}, "chain_tips": {"B2": "active", "A": "valid-fork"}, "transactions": {"T": {"value": "inMempool", "label": "[D]"}}},
     "second_oracle": {"rpc_error": -25, "reason": "parent block is invalid", "best": "A", "invalid": ["B1", "B2"], "unmined": [], "label": "[D]"},
     "divergence": "the reference clears B2's ancestor B1 and activates B2; Teranode refuses B2 under an invalid parent and keeps A (reference_reconsider_clears_ancestors; reconsider_descendant_differs)",
     "label": "[D]", "node": "pending #66"},
    {"id": "c7", "action": {"type": "reconsiderBlock", "block": "B1"}, "kind": "reorg", "rules": ["reconsider"],
     "expected_observations": {"mempool": ["T"], "tip": {"block": "B2", "height": 103}, "transactions": {"T": {"value": "inMempool", "label": "[D]"}}},
     "second_oracle": {"best": "B2", "invalid": [], "unmined": ["T"], "label": "[D]"},
     "label": "[D]", "node": "pending #66"}
  ],
  "variants": [
    {"name": "v-unknown", "fork_after": "c2", "steps": [
      {"id": "u1", "action": {"type": "invalidateBlock", "block": "unknown:00"}, "kind": "rpc", "rules": ["invalidate"],
       "expected_observations": {"rpc_error": -5, "reason": "Block not found", "tip": {"block": "A", "height": 102}},
       "second_oracle": {"rpc_error": null, "best": "A", "label": "[D]"},
       "divergence": "the reference refuses an unknown hash; Teranode answers success and changes nothing (invalidate_unknown)",
       "label": "[D]", "node": "pending #66"}]},
    {"name": "v-tie", "fork_after": "c1", "steps": [
      {"id": "t0", "action": {"type": "mine", "block": "A", "parent": "base", "method": "submitblock", "transactions": ["A:coinbase", "T"], "source": "peer p"}, "second_oracle_route": "a peer (submitblock unimplemented, services/rpc/Server.go:211)", "kind": "connect", "rules": ["mine"],
       "expected_observations": {"mempool": [], "tip": {"block": "A", "height": 102}, "transactions": {"T": {"value": "minedActive", "height": 102, "label": "[D]"}}},
       "second_oracle": {"best": "A", "unmined": [], "unminedSince": {"T": null}, "label": "[D]"},
       "label": "[D]", "node": "pending #66"},
      {"id": "t1", "action": {"type": "mine", "block": "B1", "parent": "base", "method": "submitblock", "transactions": ["B1:coinbase"], "source": "peer q, whose peer_id sorts before p's (a generated A carries \"\", which no peer_id sorts before, services/blockassembly/Server.go:2099)"}, "second_oracle_route": "a peer (submitblock unimplemented, services/rpc/Server.go:211)", "kind": "store", "rules": ["unchanged"],
       "expected_observations": {"mempool": [], "tip": {"block": "A", "height": 102}, "transactions": {"T": {"value": "minedActive", "height": 102, "label": "[D]"}}},
       "second_oracle": {"best": "B1", "unmined": ["T"], "label": "[D]"},
       "divergence": "equal work: the reference keeps the block received earlier, Teranode takes the smaller peer_id (tie_rules_differ; equal_work_tie_moves_tip)",
       "label": "[D]", "node": "pending #66"}]},
    {"name": "v-strict", "fork_after": "c3", "steps": [
      {"id": "s1", "action": {"type": "mine", "block": "B2", "parent": "B1", "method": "submitblock", "transactions": ["B2:coinbase"]}, "second_oracle_route": "a peer (submitblock unimplemented, services/rpc/Server.go:211)", "kind": "reorg", "rules": ["mine"],
       "expected_observations": {"mempool": ["T"], "tip": {"block": "B2", "height": 103}},
       "second_oracle": {"best": "B2", "work": "strictly more than A's", "unmined": ["T"], "label": "[D]"},
       "label": "[D]", "node": "pending #66"}]}
  ],
  "replay": {"runner": "owed by #66 cut 2: both columns on one fresh regtest instance each", "boundary": "the tip, the chain tips, the pool, T's status and the RPC errors after each step; Teranode's unminedSince read from the UTXO store", "record": "pending #66"}
}
```
