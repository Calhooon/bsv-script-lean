# corpus/signer: THE SIGNABLE CORPUS (#145 piece 1)

[M] 2026-10-16, S3, lane sign-145a. Unsigned spends with their throwaway keys, written by
`harness/src/bin/signer_gen.rs` (the row type and the hand signer: `harness/src/signer.rs`), so that the SDKs can be
measured as SIGNERS against the pinned node (bitcoin-sv v1.2.3 `6504a3af`) over the emitted hash types, templates and eras
(#145; #144's question is one member of the class). This page is the contract the signer adapters (#145 piece 2, S4b) and the
column (piece 3) read. The counts, seeds and sums are in [`manifest.json`](manifest.json); the families in
[`corpus/INDEX.md`](../INDEX.md) (the signable corpus section); the self-check in the record
[`docs/records/20261016-193439-s3-145a-signer-corpus-s3.md`](../../docs/records/20261016-193439-s3-145a-signer-corpus-s3.md).

The keys are regtest throwaway keys (sha256 of a label and a draw of the family's stream), never a real key; the
outpoints are synthetic (sha256 of the row's id and input index), so no row is a real transaction's.
[D] Nothing here is broadcast. A column judges the signed spends by `verifyscript` with the supplied prevouts, or funds regtest coins with the rows' locking scripts and amounts, replaces the synthetic outpoints with those funded outpoints, and re-signs before submitting to the private chain.

## The shared row format (#145, as chartered; every piece reads and writes it)

A line of `corpus/signer/<family>.jsonl` is the harness corpus Entry (`id`, `family`, `rule`, `tx`: the UNSIGNED
transaction hex with every unlocking script EMPTY, `prevouts`: the coins with locking script hex and satoshis, `params`:
`spend_height`, `era`, `consensus` and `tx_version`, as `corpus/crypto/cases.jsonl` carries them; the evaluator derives the flag word from the heights and configuration, `expect`: left for the column) plus `signing`:
`{"version": <int, 2 unless the row tests version 1>, "locktime": <int>, "inputs": [{"index": <int>, "template":
"p2pkh"|"multisig-<m>-of-<n>"|"checksig-in-unlock-a"|"checksig-in-unlock-b"|"p2pk", "privkeys": [<hex, regtest
throwaway keys, never a real key>], "pubkeys": [<hex>], "sighash_type": <int: ALL|NONE|SINGLE, each with and without
ANYONECANPAY, with FORKID; a Chronicle-bit variant where the row says so; the dedicated 0x03 row omits FORKID>, "sequence": <int>, "sig_sites": [<zero-based site index for each key>], "scriptcode_hex": [<the
scriptCode the NODE computes for each CHECKSIG site at bitcoin-sv v1.2.3 (interpreter.cpp:1471-1481: the lock for a
CHECKSIG in the lock; the unlock from its last OP_CODESEPARATOR plus the lock for a CHECKSIG in the unlock
post-Chronicle), written by the generator, one per site in execution order>], "unlock_template": <the unlocking script
hex with the tokens <sig0>, <sig1>, <pub0> where signatures and keys go>}]}`.

A signer adapter writes, per row and per METHOD, one line of its output file: `{"id", "engine": "go-sdk"|"ts-sdk"|"bsv-rs",
"method": "template"|"api-default"|"api-scriptcode", "tx_hex": <the signed transaction>, "inputs": [{"index", "site",
"preimage_hex", "digest_hex", "scriptcode_used_hex"}], "note"}`; `"template"` is the SDK public template path where one
exists for the row (p2pkh, multisig if the SDK has one), `"api-default"` the SDK signature-hash function with its
default scriptCode, `"api-scriptcode"` the SDK path given the row `scriptcode_hex` (the route #144 names: @bsv/sdk
`TransactionSignature.format` with `subscript`; go-sdk `SetSourceTxOutput` with the scriptCode as the locking script).
A row the adapter cannot sign by a method writes that method with `"tx_hex": null` and the reason in `"note"` (never
silently skipped).

[D] Every input requires `pubkeys` and `unlock_template` for every method. Missing either field produces
`tx_hex: null` with the reason on every method. The exact template vocabulary is `p2pkh`, `p2pk`,
`multisig-<m>-of-<n>`, `checksig-in-unlock-a`, `checksig-in-unlock-b`; any other name produces
`tx_hex: null` with `unknown template` on every method. `version` occurs only in `family`; its inputs
use `p2pkh` or `p2pk`.

[D] Each output trace names its zero-based input `index` and CHECKSIG `site`; `preimage_hex`, `digest_hex`,
and `scriptcode_used_hex` are scalar hex strings for that site. `scriptcode_used_hex` is the script
HANDED to the SDK signing path. An optional `scriptcode_serialized_hex` records the serialized form separately.
The API methods measure every site, then sign key K at `sig_sites[K]`; key count and site count need not agree.

## Site and token contract [D]

ScriptCode rule [SRC]: bitcoin-sv v1.2.3 `6504a3af`, `src/script/interpreter.cpp:1471-1481` and `:1567-1577`; digest dispatch `:2112-2124`. These are the source citations for the scriptCode descriptions below.

- **`scriptcode_hex` is a list**, one hex string per CHECKSIG site of the input in execution order: the unlock's sites
  (the unlock runs before the lock), then the lock's. Each is the scriptCode BEFORE the digest serializes it (the original digest's
  serializer drops OP_CODESEPARATORs itself, `interpreter.cpp:1841-1958`; under FORKID nothing is deleted, `255-263`).
  For p2pkh, p2pk and multisig it is the lock alone; for #144's shapes after Chronicle site 0 is the unlock's tail plus
  the lock and site 1 the lock; before Chronicle the unlock's tail alone (`IsChronicle(flags)`, `1475`).
- **`sig_sites`**: one integer per key, the index into `scriptcode_hex` that key's signature is checked at. Key K is
  `privkeys[K]`, its public key `pubkeys[K]` (always the pair; a multisig input lists its m signers in the lock's
  order, the lock carrying all n keys).
- **The tokens.** `<sigK>` is the DER signature of `privkeys[K]` over the digest of site `sig_sites[K]` with the input's
  `sighash_type`, followed by the type's low byte; `<pubK>` is `pubkeys[K]`; `<preimageN>` (#144's shape B only) is
  the SDK preimage of zero-based CHECKSIG site N under the input's `sighash_type`, which the unlock's in-script signer hashes. Each
  token stands for the MINIMAL PUSH of its bytes (`push_min`: a direct push up to 75 bytes, then PUSHDATA1, PUSHDATA2);
  every other character of the template is script hex, written as is.
- **`reference`**: `{"model", "expect": "valid"|"invalid"}`, the verdict the reference's rule gives by construction;
  an `invalid` row's `note` ends `(expect SCRIPT_ERR_<X>)`. `expect` stays `{}` for the columns.
- **`params`**: `spend_height`, `era`, `consensus: true`, `tx_version`, as `corpus/crypto/cases.jsonl` carries them;
  no explicit `flags` word (the word is derived from the heights, `Params.derive`). Every coin is at the spend's
  height: post-Chronicle 967,896 (`DEFAULT_SPEND_HEIGHT`), post-Genesis 900,000, pre-Genesis 600,000.
- **The tx** carries the row's `version`, `locktime` and every input's `sequence`; an adapter builds its transaction
  from the row's outpoints, sequences, outputs and lock time and must reproduce `tx` with the unlocking scripts empty.

## The families [D]

| family | rows | what |
|---|---|---|
| `p2pkh` | 40 | every type (the six FORKID types and their CHRONICLE-bit twins), SINGLE with the input index past the outputs (five dedicated rows, including 0x03, 0x43 and 0x63; 0x03 is a MUST_USE_FORKID encoding refusal), two, three and five inputs, lock time and sequence words (eight, one NON-FINAL), the eras (post-Genesis, pre-Genesis, the CHRONICLE bit refused before Chronicle twice: ILLEGAL_CHRONICLE), draws |
| `p2pk` | 40 | the same types, SINGLE past the outputs, several inputs, three timing rows, two era rows, draws |
| `multisig` | 40 | 1-of-1, 2-of-3 (each signer pair), 3-of-3 with the dummy OP_0; every type; 3-of-3 under each CHRONICLE-bit type; two inputs; the eras; draws |
| `checksig-in-unlock-a` | 40 | #144's shape A under every type and CHRONICLE-bit type, SINGLE past the outputs, two inputs, draws; each under version 2 and its version-1 twin (refused: SIG_PUSHONLY); the pre-Genesis row (valid over the unlock's tail alone) and the post-Genesis row (SIG_PUSHONLY) |
| `checksig-in-unlock-b` | 41 | #144's shape B (the in-script OP_PUSH_TX signer, its hash type byte the row's) under the six FORKID types, SINGLE past the outputs, two inputs, a lock time and a sequence row, draws; each with its version-1 twin; the post-Genesis row |
| `version` | 40 | p2pkh, p2pk and mixed p2pkh/p2pk spends, each under version 2 and version 1, both valid |

## Regenerate and check

```sh
cd harness && cargo build --release --locked --bin signer_gen
"${CARGO_TARGET_DIR:-target}"/release/signer_gen --out ../corpus/signer     # the manifest's seed and count are the defaults
cd .. && python3 tools/signer_selfcheck.py                                 # determinism, the rows, the control (eval/bsvs)
```

[D] #147 adds bsv-rs 0.5.0 to this protocol. Its public templates support p2pkh, p2pk and multisig for the scopes their options express; unavailable templates or scopes write a named null. The default API uses `SigningContext::compute_sighash`; the explicit API uses `compute_sighash_dispatched_for_signing`. For an original SINGLE constant-one result, `preimage_hex` is empty because there is no serialized preimage; `digest_hex` contains the un-hashed constant and `note` explains it. For bsv-rs `template` and `api-default`, `preimage_hex` is the library's `build_sighash_preimage` on the same parameters; the runner accepts it only when sha256d of it equals the context's digest.
