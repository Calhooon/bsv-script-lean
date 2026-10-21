[export: 11 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
# Recorded seed results [LIT] 2026-09-30T00:33:03.155230+00:00

Model: Codex GPT-6.1-Sol. Compiled source [LIT] `e39ba468c3c9bef42f6041509914767f81f34a79`.

Implementation [LIT] `bsv-rs`: exported entries [X] 10000, paired verdict cells [D] 20000; spec export sha256 [M] `1cc694d9446d17cedf784bd404d1727e54b225ac7a4d43ee4caec34070d26607`.
```text
harness/run 2026-09-30 00:27:21 UTC: --impl bsv-rs --spec recorded
the tree: e39ba46 (uncommitted changes)
GREEN seed: (every divergence explained by a rule with its citation)
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
run_diff: seed/seed.jsonl (10000 entries) vs bsv-rs 0.3.30 (the recorded configuration EngineConfig { require_push_only: true, memory_limit: None, flags: Some(ScriptFlags(0x3d47ff: P2SH|STRICTENC|DERSIG|LOW_S|NULLDUMMY|SIGPUSHONLY|MINIMALDATA|DISCOURAGE_UPGRADABLE_NOPS|CLEANSTACK|CHECKLOCKTIMEVERIFY|CHECKSEQUENCEVERIFY|NULLFAIL|SIGHASH_FORKID|GENESIS|UTXO_AFTER_GENESIS|CHRONICLE|UTXO_AFTER_CHRONICLE)), per_input_words: false }; the spec column under the entry's own word per input (its explicit flags when it carries them, else engine::word_for with its params.consensus: the block word when consensus), the spec-mempool column under the standard word per input (engine::word_for, never the entry's flags), from the entry's spend height and the coin's height; entries with a pre-Genesis spend or coin, not applicable to bsv-rs (undecided): 0); the spec at spec@8fde74b (sv-mainnet-default); 0.2s
  agree: spec-mempool 10000 (like-for-like, the standard word), spec 10000 (the entry's own params: the block word when consensus); bsv-rs undecided 0 (a pre-Genesis input, or an abort on an entry the spec does not decide); aborts filed as witnesses (D15: `engine.resource-abort`, `engine.exception`) 0; the spec undefined-in-reference (Q7, reported, never counted) 0; without a spec verdict 0; recorded bsv-rs verdicts disagreeing with the live run 0; bsv-rs messages outside the table 0
| column | rule | entries | ruling | witness | decided by |
|---|---|---|---|---|---|
[withheld at export: a sibling tree's line]
run_diff: GREEN (every divergence explained by a rule with its citation)
```

Implementation [LIT] `go-sdk`: exported entries [X] 10000, paired verdict cells [D] 20000; spec export sha256 [M] `1cc694d9446d17cedf784bd404d1727e54b225ac7a4d43ee4caec34070d26607`.
```text
harness/run 2026-09-30 00:27:17 UTC: --impl go-sdk --spec recorded
the tree: e39ba46 (uncommitted changes)
GREEN seed: (every divergence explained by a rule with its citation)
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
  word: spend 967896, utxo 967896, consensus false -> 0x3D47FF
  word: spend 967896, utxo 967896, consensus true -> 0x3D462F
  agree: spec 9988, spec-mempool 9010; engine aborts filed as witnesses (D15) 0 (timeouts 0, of which 0 decided on the 10× re-run, D15a; process deaths 0, of which 0 recovered in a fresh process); undecided runs (the adapter's own codes or no spec verdict, never a witness) 0; the spec undefined-in-reference (Q7, reported, never counted) 0; without a spec verdict 0; engine codes/messages outside the tables 0; adapter errors 0
  reference bits the engine has no flag for (reported per run, 10000 runs): SCRIPT_CHRONICLE ×20000, SCRIPT_GENESIS ×20000
| column | rule | entries | ruling | witness | decided by |
|---|---|---|---|---|---|
| spec | `flags.version-gate.absent` | 12 | impl-wrong | `witness-go-sdk-seed-spec-flags.version-gate.absent-seed-009309` | interpreter.cpp:40–44 EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1) at the seven sites 285 (LOW_S), 433 (MINIMALDATA), 801 (MINIMALIF), 1493 and 1643 (NULLFAIL), 1666 (NULLDUMMY), 2441 (CLEANSTACK) and the SIGPUSHONLY read at 2327; go-sdk v1.5.2 scriptflag/scriptflag.go:1–86 (no spend-era flag: SCRIPT_CHRONICLE and SCRIPT_GENESIS have no image), thread.go:232 (clean stack), 342 (push-only), 753 (high S), operations.go:2059/2301 (NULLFAIL), 2178 (NULLDUMMY), 408/411 (MINIMALIF), opcodeparser.go:95–129 and number.go:424 (minimal data), every one on the flag alone; ts-sdk 2.8.0 Spend.ts:341–366 (#shouldEnforceMinimalData/LowS/NullDummy/SigPushOnly/CleanStack return #hasFlag(...) when explicit flags are given, the transaction version never read), 1090–1096 (MINIMALIF), 1613/1737 (NULLFAIL) |
| spec-mempool | `flags.version-gate.absent` | 990 | impl-wrong | `witness-go-sdk-seed-spec-mempool-flags.version-gate.absent-seed-000068` | interpreter.cpp:40–44 EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1) at the seven sites 285 (LOW_S), 433 (MINIMALDATA), 801 (MINIMALIF), 1493 and 1643 (NULLFAIL), 1666 (NULLDUMMY), 2441 (CLEANSTACK) and the SIGPUSHONLY read at 2327; go-sdk v1.5.2 scriptflag/scriptflag.go:1–86 (no spend-era flag: SCRIPT_CHRONICLE and SCRIPT_GENESIS have no image), thread.go:232 (clean stack), 342 (push-only), 753 (high S), operations.go:2059/2301 (NULLFAIL), 2178 (NULLDUMMY), 408/411 (MINIMALIF), opcodeparser.go:95–129 and number.go:424 (minimal data), every one on the flag alone; ts-sdk 2.8.0 Spend.ts:341–366 (#shouldEnforceMinimalData/LowS/NullDummy/SigPushOnly/CleanStack return #hasFlag(...) when explicit flags are given, the transaction version never read), 1090–1096 (MINIMALIF), 1613/1737 (NULLFAIL) |
  tier-2 notes (both invalid, the codes differ; never a divergence):
    spec: spec SCRIPT_ERR_BAD_OPCODE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 55
    spec: spec SCRIPT_ERR_DIV_BY_ZERO vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_EVAL_FALSE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 15
    spec: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs go-sdk SCRIPT_ERR_BAD_OPCODE: 3
    spec: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 2
    spec: spec SCRIPT_ERR_INVALID_OPERAND_SIZE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_BAD_OPCODE: 24
    spec: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 41
    spec: spec SCRIPT_ERR_MOD_BY_ZERO vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_PUBKEYTYPE vs go-sdk SCRIPT_ERR_BAD_OPCODE: 1
    spec: spec SCRIPT_ERR_PUSH_SIZE vs go-sdk SCRIPT_ERR_IMPOSSIBLE_ENCODING: 2
    spec: spec SCRIPT_ERR_PUSH_SIZE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 3
    spec: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs go-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    spec: spec SCRIPT_ERR_SIG_DER vs go-sdk SCRIPT_ERR_SIG_HASHTYPE: 3
    spec: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs go-sdk SCRIPT_ERR_BAD_OPCODE: 1
    spec: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 10
    spec: spec SCRIPT_ERR_VERIFY vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_BAD_OPCODE vs go-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_BAD_OPCODE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 54
    spec-mempool: spec SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 2
    spec-mempool: spec SCRIPT_ERR_DIV_BY_ZERO vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs go-sdk SCRIPT_ERR_CLEANSTACK: 74
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs go-sdk SCRIPT_ERR_MINIMALDATA: 2
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs go-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 21
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 14
    spec-mempool: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs go-sdk SCRIPT_ERR_BAD_OPCODE: 3
    spec-mempool: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 2
    spec-mempool: spec SCRIPT_ERR_INVALID_OPERAND_SIZE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_SPLIT_RANGE vs go-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_BAD_OPCODE: 24
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_MINIMALDATA: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 2
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 41
    spec-mempool: spec SCRIPT_ERR_MOD_BY_ZERO vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_PUBKEYTYPE vs go-sdk SCRIPT_ERR_BAD_OPCODE: 1
    spec-mempool: spec SCRIPT_ERR_PUSH_SIZE vs go-sdk SCRIPT_ERR_IMPOSSIBLE_ENCODING: 1
    spec-mempool: spec SCRIPT_ERR_PUSH_SIZE vs go-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_PUSH_SIZE vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 3
    spec-mempool: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs go-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    spec-mempool: spec SCRIPT_ERR_SIG_DER vs go-sdk SCRIPT_ERR_SIG_HASHTYPE: 3
    spec-mempool: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs go-sdk SCRIPT_ERR_BAD_OPCODE: 1
    spec-mempool: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 10
    spec-mempool: spec SCRIPT_ERR_VERIFY vs go-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
[withheld at export: a sibling tree's line]
run_engine: GREEN (every divergence explained by a rule with its citation)
```

Implementation [LIT] `ts-sdk`: exported entries [X] 10000, paired verdict cells [D] 20000; spec export sha256 [M] `1cc694d9446d17cedf784bd404d1727e54b225ac7a4d43ee4caec34070d26607`.
```text
harness/run 2026-09-30 00:27:19 UTC: --impl ts-sdk --spec recorded
the tree: e39ba46 (uncommitted changes)
GREEN seed: (every divergence explained by a rule with its citation)
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
  word: spend 967896, utxo 967896, consensus false -> 0x3D47FF
  word: spend 967896, utxo 967896, consensus true -> 0x3D462F
  agree: default/spec 9840, default/spec-mempool 10000, spec 9988, spec-mempool 9010; engine aborts filed as witnesses (D15) 0 (timeouts 0, of which 0 decided on the 10× re-run, D15a; process deaths 0, of which 0 recovered in a fresh process); undecided runs (the adapter's own codes or no spec verdict, never a witness) 0; the spec undefined-in-reference (Q7, reported, never counted) 0; without a spec verdict 0; engine codes/messages outside the tables 0; adapter errors 0
  reference bits the engine has no flag for (reported per run, 10000 runs): CHECKLOCKTIMEVERIFY ×20000, CHRONICLE ×20000
| column | rule | entries | ruling | witness | decided by |
|---|---|---|---|---|---|
| default/spec | `flags.policy-as-consensus` | 160 | open | `witness-ts-sdk-seed-default-spec-flags.policy-as-consensus-seed-000296` | policy.h:178–190 (MINIMALDATA, NULLDUMMY, CLEANSTACK are standard-set flags; verify_script_flags.cpp:32–81 never sets them in a block word; blockScriptFlags_policy_off); ts-sdk 2.8.0 Spend.ts:315–317 (#isRelaxed = version > 1) and 341–366 (without explicit flags every restriction follows !#isRelaxed) |
| spec | `flags.version-gate.absent` | 12 | impl-wrong | `witness-ts-sdk-seed-spec-flags.version-gate.absent-seed-009309` | interpreter.cpp:40–44 EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1) at the seven sites 285 (LOW_S), 433 (MINIMALDATA), 801 (MINIMALIF), 1493 and 1643 (NULLFAIL), 1666 (NULLDUMMY), 2441 (CLEANSTACK) and the SIGPUSHONLY read at 2327; go-sdk v1.5.2 scriptflag/scriptflag.go:1–86 (no spend-era flag: SCRIPT_CHRONICLE and SCRIPT_GENESIS have no image), thread.go:232 (clean stack), 342 (push-only), 753 (high S), operations.go:2059/2301 (NULLFAIL), 2178 (NULLDUMMY), 408/411 (MINIMALIF), opcodeparser.go:95–129 and number.go:424 (minimal data), every one on the flag alone; ts-sdk 2.8.0 Spend.ts:341–366 (#shouldEnforceMinimalData/LowS/NullDummy/SigPushOnly/CleanStack return #hasFlag(...) when explicit flags are given, the transaction version never read), 1090–1096 (MINIMALIF), 1613/1737 (NULLFAIL) |
| spec-mempool | `flags.version-gate.absent` | 990 | impl-wrong | `witness-ts-sdk-seed-spec-mempool-flags.version-gate.absent-seed-000068` | interpreter.cpp:40–44 EnforceNonMalleability(flags, v) = !(IsChronicle(flags) && v > 1) at the seven sites 285 (LOW_S), 433 (MINIMALDATA), 801 (MINIMALIF), 1493 and 1643 (NULLFAIL), 1666 (NULLDUMMY), 2441 (CLEANSTACK) and the SIGPUSHONLY read at 2327; go-sdk v1.5.2 scriptflag/scriptflag.go:1–86 (no spend-era flag: SCRIPT_CHRONICLE and SCRIPT_GENESIS have no image), thread.go:232 (clean stack), 342 (push-only), 753 (high S), operations.go:2059/2301 (NULLFAIL), 2178 (NULLDUMMY), 408/411 (MINIMALIF), opcodeparser.go:95–129 and number.go:424 (minimal data), every one on the flag alone; ts-sdk 2.8.0 Spend.ts:341–366 (#shouldEnforceMinimalData/LowS/NullDummy/SigPushOnly/CleanStack return #hasFlag(...) when explicit flags are given, the transaction version never read), 1090–1096 (MINIMALIF), 1613/1737 (NULLFAIL) |
  tier-2 notes (both invalid, the codes differ; never a divergence):
    default/spec: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs ts-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    default/spec-mempool: spec SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS vs ts-sdk SCRIPT_ERR_BAD_OPCODE: 1
    default/spec-mempool: spec SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS vs ts-sdk SCRIPT_ERR_EVAL_FALSE: 1
    default/spec-mempool: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs ts-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    spec: spec SCRIPT_ERR_BAD_OPCODE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 87
    spec: spec SCRIPT_ERR_DIV_BY_ZERO vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_EVAL_FALSE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 15
    spec: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 4
    spec: spec SCRIPT_ERR_INVALID_OPERAND_SIZE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 61
    spec: spec SCRIPT_ERR_MOD_BY_ZERO vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_PUBKEYTYPE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec: spec SCRIPT_ERR_PUSH_SIZE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 3
    spec: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs ts-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    spec: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 11
    spec: spec SCRIPT_ERR_VERIFY vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_BAD_OPCODE vs ts-sdk SCRIPT_ERR_MINIMALDATA: 4
    spec-mempool: spec SCRIPT_ERR_BAD_OPCODE vs ts-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 7
    spec-mempool: spec SCRIPT_ERR_BAD_OPCODE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 86
    spec-mempool: spec SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 2
    spec-mempool: spec SCRIPT_ERR_DIV_BY_ZERO vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs ts-sdk SCRIPT_ERR_MINIMALDATA: 2
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs ts-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 21
    spec-mempool: spec SCRIPT_ERR_EVAL_FALSE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 14
    spec-mempool: spec SCRIPT_ERR_IMPOSSIBLE_ENCODING vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 4
    spec-mempool: spec SCRIPT_ERR_INVALID_OPERAND_SIZE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_SPLIT_RANGE vs ts-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs ts-sdk SCRIPT_ERR_MINIMALDATA: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs ts-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_INVALID_STACK_OPERATION vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 61
    spec-mempool: spec SCRIPT_ERR_MOD_BY_ZERO vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_PUBKEYTYPE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
    spec-mempool: spec SCRIPT_ERR_PUSH_SIZE vs ts-sdk SCRIPT_ERR_SCRIPTNUM_MINENCODE: 1
    spec-mempool: spec SCRIPT_ERR_PUSH_SIZE vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 3
    spec-mempool: spec SCRIPT_ERR_SCRIPTNUM_OVERFLOW vs ts-sdk SCRIPT_ERR_PUBKEY_COUNT: 1
    spec-mempool: spec SCRIPT_ERR_UNBALANCED_CONDITIONAL vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 11
    spec-mempool: spec SCRIPT_ERR_VERIFY vs ts-sdk SCRIPT_ERR_SIG_PUSHONLY: 1
[withheld at export: a sibling tree's line]
run_engine: GREEN (every divergence explained by a rule with its citation)
```

Rust passing tests [D] 25; failing tests [D] 0, re-derived from `20260930-002539-harness31-rust-final-s3.txt`.
The corpus and all corpus/witnesses files are unchanged on the draft branch relative to main [X].
Command [LIT] git diff --quiet origin/main origin/s3-c56-harness -- corpus; exit [X] 0.
