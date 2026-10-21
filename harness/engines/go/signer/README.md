# Go signer adapter

The signer column for #145 uses the same pinned module as the verifier runner.
Build with `make gosdk-signer-build`. The default executable is
`harness/target/engines/gosdk-signer`; `GOSDK_SIGNER_BIN` selects an external
output path and `GOSDK_GO` selects the Go executable. Dependencies are offline
and readonly (`GOPROXY=off GOSUMDB=off GOTOOLCHAIN=local`).

```sh
make gosdk-signer-build GOSDK_SIGNER_BIN="$CARGO_TARGET_DIR/engines/gosdk-signer" \
  GOSDK_GO="$HOME/bsv/targets/spec-box/toolchains/go/bin/go"
"$CARGO_TARGET_DIR/engines/gosdk-signer" --corpus "$signer_corpus" --out "$signer_output"
```

`--version` reports the linked module version from Go build metadata. Input and
output default to stdin and stdout; `-` selects either stream explicitly. The
input is the shared corpus Entry plus `signing`, not the verifier's request
envelope. The adapter emits these methods for every nonblank input line, in
this order: `template`, `api-default`, `api-scriptcode`. A row error, missing SDK
path or recovered SDK panic produces `tx_hex: null` with a reason in `note`.
These outcomes do not terminate the stream. File and stream failures exit
nonzero. `expect`, flag words and era metadata do not change the public signing
API's defaults. The node column decides validity.

`template` returns the complete P2PKH template output. Other template names
produce a null result: go-sdk v1.7.2 has no multisig, P2PK or CHECKSIG-in-unlock
template. `api-default` hashes the real previous output's locking script;
`api-scriptcode` substitutes the supplied scriptCode through `SetSourceTxOutput`
with no source transaction attached. Both API methods sign with `PrivateKey.Sign`
and fill `unlock_template`. They never infer a scriptCode or replace a key.
The recorded preimage comes directly from `CalcInputPreimage` for BIP143 or
`CalcInputPreimageLegacy` for legacy/Chronicle-bit hashing. A legacy SINGLE
out-of-range preimage is the SDK's sentinel, explicitly named in the note. [D]

The shared contract is `corpus/signer/README.md`. `scriptcode_hex` is a list of
hex strings, one per CHECKSIG site in execution order. `sig_sites[K]` selects
the site signed by `privkeys[K]`; `pubkeys[K]` is its public key. Multisig keys
can share one site, and an in-script signer can have a site without a host key.
Every input requires `pubkeys`, `unlock_template` and the key-to-site mapping
on every method. The exact names are `p2pkh`, `p2pk`, `multisig-<m>-of-<n>`,
`checksig-in-unlock-a`, `checksig-in-unlock-b`; another name produces
`tx_hex: null` with `unknown template` on every method. Each trace records
both input `index` and CHECKSIG `site`, with scalar hex fields. The recorded
`scriptcode_used_hex` is the script handed to the SDK. [D]

The preimage reader is checked against `CalcInputSignatureHash`: unless the
digest is the SDK's constant-one sentinel, the SDK hash256 of the measured
preimage must match it. A mismatch produces a named null result. [D]

Each `<sigN>` and `<pubN>` token expands to a complete SDK data push, including
the length prefix. Signatures include their sighash byte; public keys use the
row's bytes. Literal hex stays unchanged. The additive `<preimageN>` token
pushes the SDK preimage of site N for #144's OP_PUSH_TX shape. It introduces no
extra JSON fields. Unknown or unavailable tokens yield null with a reason.
P2PKH's public template supplies its own compressed public key and unlocking
script, as the SDK implements them. [D]

The source paths, pin, byte comparisons and command verdicts are in the
[lane record](../../../../docs/records/20261016-192344-s4b-145-signer-adapter-go-s4b.md).
`selfcheck.py --help` describes the offline replay of the #144 witness. [LIT]
