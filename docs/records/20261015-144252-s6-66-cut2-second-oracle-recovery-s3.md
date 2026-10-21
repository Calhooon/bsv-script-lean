[export: 1 line withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# #66 cut 2: q2's runner support recovered and landed (S3, the gateway)

[withheld at export: a sibling tree's line]

## The ten files (commit by pathspec, two commits by seat)

- `corpus/scenarios/2026-10-14-conflicting-spends-order.md` (#90's scenario, modified: `F1` and `F2` each spend one of the two outputs of the height-1 coinbase, a height-2 coinbase being below `COINBASE_MATURITY` 100 at height 101, [SRC] src/consensus/consensus.h:75 and src/validation.cpp:2617-2623 at `6504a3af`)
- `corpus/scenarios/2026-10-15-sentinel-refusal-pair.md` (#91's scenario, new: pair (1) the same-block parent, pair (2) the promiscuous word)
- `harness/rules/second-oracle-scenarios.json` (new: the scenario classes `scenario.header-median.regtest-warning` and `scenario.reconsider.revalidation-refused`, both readings cited at both pins, both rulings open)
- `harness/src/scenarios/spends.rs` (new: the two scenarios' driver: `submitConcurrent` on two RPC connections released by one barrier, the `store_mempool_one_of` and `spenders` judging, the non-judging rule, `fork_after: "initial"` variants)
- `harness/src/scenarios/branch.rs` (new: the seven chain branch cases, the cited unrealizable reasons for `precious`, `missing-body`, `body-return` and `receipt-order`)
- `harness/src/scenarios/{intake,mod,road,teranode}.rs` (modified: `pair_transactions` and `sentinel_transactions` and `signed`, the scenario list, the road's projection)
- `harness/engines/teranode/client.rs` (S4b, modified: `RPC_URL` `pub(crate)`, the second concurrent connection)

## Verification (this lane, before the commit)

- #90's issue text against the builder: `A` spends `F1:fund` then `F2:fund`, `B` the reverse order, `C` and `D` each `F1:fund` alone; the concurrent pair submits on two connections under one barrier (the reference column's `submit_concurrent` idiom). Match.
- #91's issue text against the scenario and the rules keys: pair (1) consensus on the same-block parent, pair (2) policy non-judging; the classes' `when.id_in` name `header/time-at-median` and `chain-invalidate-reconsider`. Match.
- `CARGO_BUILD_JOBS=4 cargo build --locked --bin run_scenarios` in `harness/`: green, 8.66 s, the Studio's load under 20.
- `tools/scenario_metadata_check.py`: green on every leg; `tools/cite_check.py` over the touched files: green, every active anchor holds at the pin.

## Owed

- The runs: #90's and #91's scenarios and the pending and no-verdict re-runs on a fresh instance (the quarantine Opus lane; the runs wait on the instance, slices 2 and 3 of the tasks file).
- The four divergences' Findings and the two deferred receipt reads (this lane's slices 4 and 5).
- Hygiene (the tasks file's slice 6 asks one line of it): each instance log's settings echo carries the regtest wallet key (WIF) and a p2p shared key; regtest-only, and a fresh wallet key per run keeps it that way.
