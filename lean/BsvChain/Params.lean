import BsvScript.Params

/-!
# Chain-layer configuration (#59)

The census is `docs/PARAMETERS.md` §8. This library imports the script library;
the script library does not import this one (checked by `tools/check_parameters.py`).
Every source below is [SRC] bitcoin-sv v1.2.3 at
`6504a3aff65ba97c0f6c80962b033e35ecbfed4b` (paths relative to that repository).

`NodeConfig.defaults` is a library template, not a daemon launch configuration.
Three values require explicit operator input at launch: `excessiveBlockSize`,
inherited `maxStackMemoryUsageConsensus`, and `blockMinTxFee`. Their template
values are the reference's library initializers, never implicit launch defaults.
All sizes, times and zero sentinels below are resolved as each field documents.
Per-network data are `ChainParams` below and the census in §8.3; since #69
(2026-10-13) the transitions read them through `lean/BsvChain/Eras.lean`
(`bip30Enforced`, `checkBlockVersion`, `nextWorkPath`, `NetworkData`), with the
proofs in `Properties/Eras.lean`. Operator lists,
request overrides, scheduling choices and `now` are explicit transition inputs
or state, as DESIGN-S6 §§1–2 specifies; they are not invented global constants.
The node settings retain their qualified kind; the frozen lists remain the
operator-list mechanism of #70. No setting substitutes for #65's inclusion proof.
-/

namespace BsvChain

/-- The pinned network data of PARAMETERS §8.3 (DESIGN-S6 §4.1).
All fields are consensus parameters. Presence is optional as a launch input.
An Option height records an absent source assignment, never a disabled rule:
STN omits BIP65, BIP66 and CSV [SRC] src/chainparams.cpp:1195–1304,
src/consensus/params.h:23–28 and src/chainparams.h:115 at `6504a3af`.
Hash values are unsigned integers; time values are seconds. -/
structure ChainParams where
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:20–21 at `6504a3af`.
  Read: src/validation.cpp:5965,6085–6092. Initialization: the per-network definitions below. -/
  bip34Height : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:23–24 at `6504a3af`.
  Read: src/validation.cpp:5967; src/verify_script_flags.cpp:46–48. Initialization: the per-network definitions below. -/
  bip65Height : Option Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:25–26 at `6504a3af`.
  Read: src/validation.cpp:5966; src/verify_script_flags.cpp:42–44. Initialization: the per-network definitions below. -/
  bip66Height : Option Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:27–28 at `6504a3af`.
  Read: src/validation.cpp:3465,6046–6049; src/verify_script_flags.cpp:50–52. Initialization: the per-network definitions below. -/
  csvHeight : Option Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:29–30 at `6504a3af`.
  Read: src/verify_script_flags.cpp:54–59. Initialization: the per-network definitions below. -/
  uahfHeight : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:31–32 at `6504a3af`.
  Read: src/pow.cpp:107–113; src/verify_script_flags.cpp:65–69. Initialization: the per-network definitions below. -/
  daaHeight : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:33–37 at `6504a3af`.
  Read: src/protocol_era.cpp:21–46; src/init.cpp:2609–2612. Initialization: the per-network definitions below. -/
  genesisHeight : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:33–38 at `6504a3af`.
  Read: src/protocol_era.cpp:21–46; src/init.cpp:2613–2616. Initialization: the per-network definitions below. -/
  chronicleHeight : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:39 at `6504a3af`.
  Read: src/verify_script_flags.cpp:38–40. Initialization: the per-network definitions below. -/
  p2shHeight : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:19 at `6504a3af`.
  Read: src/validation.cpp:2252–2262. Initialization: the per-network definitions below. -/
  subsidyHalvingInterval : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:42 at `6504a3af`.
  Read: src/pow.cpp:101–103,150–170. Initialization: the per-network definitions below. -/
  powLimit : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:46–48 at `6504a3af`.
  Read: src/pow.cpp:27–38,128–145. Initialization: the per-network definitions below. -/
  powTargetTimespan : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:45 at `6504a3af`.
  Read: src/pow.cpp:44–49,267–269. Initialization: the per-network definitions below. -/
  powTargetSpacing : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:43 at `6504a3af`.
  Read: src/pow.cpp:44–61,267–270. Initialization: the per-network definitions below. -/
  powAllowMinDifficultyBlocks : Bool
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:44 at `6504a3af`.
  Read: src/pow.cpp:106–109. Initialization: the per-network definitions below. -/
  powNoRetargeting : Bool
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:20–22 at `6504a3af`.
  Read: src/validation.cpp:3088–3095. Initialization: the per-network definitions below. -/
  bip34Hash : Nat
  /-- Kind: consensus. Presence: optional.
  [SRC] Definition: src/consensus/params.h:18 at `6504a3af`.
  Read: src/validation.cpp:3044,6152. Initialization: the per-network definitions below. -/
  hashGenesisBlock : Nat
  deriving DecidableEq, Repr

/-- mainnet source assignments [SRC] src/chainparams.cpp at `6504a3af`.
Census: PARAMETERS §8.3; each value cites its initialization.
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#genesis-2020-02-04 at v1.2.2 (the Genesis height only).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#chronicle-2026-04-07 at v1.2.2 (the Chronicle height only).
[LIT] https://protocol.bsvblockchain.org/specification/consensus-rules#genesis-block-rule at v1.2.2 (`hashGenesisBlock` only). -/
def ChainParams.mainnet : ChainParams :=
  {
    -- [SRC] src/chainparams.cpp:1038 at `6504a3af`.
    bip34Height := 227931
    -- [SRC] src/chainparams.cpp:1042 at `6504a3af`.
    bip65Height := some 388381
    -- [SRC] src/chainparams.cpp:1044 at `6504a3af`.
    bip66Height := some 363725
    -- [SRC] src/chainparams.cpp:1046 at `6504a3af`.
    csvHeight := some 419328
    -- [SRC] src/chainparams.cpp:1065 at `6504a3af`.
    uahfHeight := 478558
    -- [SRC] src/chainparams.cpp:1068 at `6504a3af`.
    daaHeight := 504031
    -- [SRC] src/chainparams.cpp:18,1071 at `6504a3af`.
    genesisHeight := 620538
    -- [SRC] src/chainparams.cpp:23,1074 at `6504a3af`.
    chronicleHeight := 943816
    -- [SRC] src/chainparams.cpp:28,1076 at `6504a3af`.
    p2shHeight := 173805
    -- [SRC] src/chainparams.cpp:1037 at `6504a3af`.
    subsidyHalvingInterval := 210000
    -- [SRC] src/chainparams.cpp:1047–1048 at `6504a3af`.
    powLimit := 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    -- [SRC] src/chainparams.cpp:1050 at `6504a3af`.
    powTargetTimespan := 1209600
    -- [SRC] src/chainparams.cpp:1051 at `6504a3af`.
    powTargetSpacing := 600
    -- [SRC] src/chainparams.cpp:1052 at `6504a3af`.
    powAllowMinDifficultyBlocks := false
    -- [SRC] src/chainparams.cpp:1053 at `6504a3af`.
    powNoRetargeting := false
    -- [SRC] src/chainparams.cpp:1039–1040 at `6504a3af`.
    bip34Hash := 0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8
    -- [SRC] src/chainparams.cpp:1096–1099 at `6504a3af`.
    hashGenesisBlock := 0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f
  }

/-- testnet source assignments [SRC] src/chainparams.cpp at `6504a3af`.
Census: PARAMETERS §8.3; each value cites its initialization.
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#genesis-2020-02-04 at v1.2.2 (the Genesis height only).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#chronicle-2026-04-07 at v1.2.2 (the Chronicle height only). -/
def ChainParams.testnet : ChainParams :=
  {
    -- [SRC] src/chainparams.cpp:1334 at `6504a3af`.
    bip34Height := 21111
    -- [SRC] src/chainparams.cpp:1338 at `6504a3af`.
    bip65Height := some 581885
    -- [SRC] src/chainparams.cpp:1340 at `6504a3af`.
    bip66Height := some 330776
    -- [SRC] src/chainparams.cpp:1342 at `6504a3af`.
    csvHeight := some 770112
    -- [SRC] src/chainparams.cpp:1361 at `6504a3af`.
    uahfHeight := 1155875
    -- [SRC] src/chainparams.cpp:1364 at `6504a3af`.
    daaHeight := 1188697
    -- [SRC] src/chainparams.cpp:20,1367 at `6504a3af`.
    genesisHeight := 1344302
    -- [SRC] src/chainparams.cpp:25,1370 at `6504a3af`.
    chronicleHeight := 1713168
    -- [SRC] src/chainparams.cpp:30,1372 at `6504a3af`.
    p2shHeight := 519
    -- [SRC] src/chainparams.cpp:1333 at `6504a3af`.
    subsidyHalvingInterval := 210000
    -- [SRC] src/chainparams.cpp:1343–1344 at `6504a3af`.
    powLimit := 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    -- [SRC] src/chainparams.cpp:1346 at `6504a3af`.
    powTargetTimespan := 1209600
    -- [SRC] src/chainparams.cpp:1347 at `6504a3af`.
    powTargetSpacing := 600
    -- [SRC] src/chainparams.cpp:1348 at `6504a3af`.
    powAllowMinDifficultyBlocks := true
    -- [SRC] src/chainparams.cpp:1349 at `6504a3af`.
    powNoRetargeting := false
    -- [SRC] src/chainparams.cpp:1335–1336 at `6504a3af`.
    bip34Hash := 0x0000000023b3a96d3484e5abb3755c413e7d41500f8e2a5c3f0dd01299cd8ef8
    -- [SRC] src/chainparams.cpp:1387–1390 at `6504a3af`.
    hashGenesisBlock := 0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943
  }

/-- stn source assignments [SRC] src/chainparams.cpp at `6504a3af`.
Census: PARAMETERS §8.3; each value cites its initialization. -/
def ChainParams.stn : ChainParams :=
  {
    -- [SRC] src/chainparams.cpp:1212 at `6504a3af`.
    bip34Height := 100000000
    -- [SRC] src/chainparams.cpp:1195–1304 at `6504a3af`.
    bip65Height := none
    -- [SRC] src/chainparams.cpp:1195–1304 at `6504a3af`.
    bip66Height := none
    -- [SRC] src/chainparams.cpp:1195–1304 at `6504a3af`.
    csvHeight := none
    -- [SRC] src/chainparams.cpp:1225 at `6504a3af`.
    uahfHeight := 15
    -- [SRC] src/chainparams.cpp:1228 at `6504a3af`.
    daaHeight := 2200
    -- [SRC] src/chainparams.cpp:19,1231 at `6504a3af`.
    genesisHeight := 100
    -- [SRC] src/chainparams.cpp:24,1234 at `6504a3af`.
    chronicleHeight := 250
    -- [SRC] src/chainparams.cpp:29,1236 at `6504a3af`.
    p2shHeight := 1
    -- [SRC] src/chainparams.cpp:1211 at `6504a3af`.
    subsidyHalvingInterval := 210000
    -- [SRC] src/chainparams.cpp:1214 at `6504a3af`.
    powLimit := 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    -- [SRC] src/chainparams.cpp:1215 at `6504a3af`.
    powTargetTimespan := 1209600
    -- [SRC] src/chainparams.cpp:1216 at `6504a3af`.
    powTargetSpacing := 600
    -- [SRC] src/chainparams.cpp:1218 at `6504a3af`.
    powAllowMinDifficultyBlocks := false
    -- [SRC] src/chainparams.cpp:1219 at `6504a3af`.
    powNoRetargeting := false
    -- [SRC] src/chainparams.cpp:1213 at `6504a3af`.
    bip34Hash := 0
    -- [SRC] src/chainparams.cpp:1206–1209 at `6504a3af`.
    hashGenesisBlock := 0x000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943
  }

/-- regtest source assignments [SRC] src/chainparams.cpp at `6504a3af`.
Census: PARAMETERS §8.3; each value cites its initialization.
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#genesis-2020-02-04 at v1.2.2 (the Genesis height only).
[LIT] https://protocol.bsvblockchain.org/specification/upgrade-history#chronicle-2026-04-07 at v1.2.2 (the Chronicle height only). -/
def ChainParams.regtest : ChainParams :=
  {
    -- [SRC] src/chainparams.cpp:1463 at `6504a3af`.
    bip34Height := 100000000
    -- [SRC] src/chainparams.cpp:1466 at `6504a3af`.
    bip65Height := some 1351
    -- [SRC] src/chainparams.cpp:1468 at `6504a3af`.
    bip66Height := some 1251
    -- [SRC] src/chainparams.cpp:1470 at `6504a3af`.
    csvHeight := some 576
    -- [SRC] src/chainparams.cpp:1487 at `6504a3af`.
    uahfHeight := 0
    -- [SRC] src/chainparams.cpp:1490 at `6504a3af`.
    daaHeight := 0
    -- [SRC] src/chainparams.cpp:21,1493 at `6504a3af`.
    genesisHeight := 10000
    -- [SRC] src/chainparams.cpp:26,1496 at `6504a3af`.
    chronicleHeight := 15000
    -- [SRC] src/chainparams.cpp:31,1498 at `6504a3af`.
    p2shHeight := 1
    -- [SRC] src/chainparams.cpp:1460 at `6504a3af`.
    subsidyHalvingInterval := 150
    -- [SRC] src/chainparams.cpp:1471–1472 at `6504a3af`.
    powLimit := 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    -- [SRC] src/chainparams.cpp:1474 at `6504a3af`.
    powTargetTimespan := 1209600
    -- [SRC] src/chainparams.cpp:1475 at `6504a3af`.
    powTargetSpacing := 600
    -- [SRC] src/chainparams.cpp:1476 at `6504a3af`.
    powAllowMinDifficultyBlocks := true
    -- [SRC] src/chainparams.cpp:1477 at `6504a3af`.
    powNoRetargeting := true
    -- [SRC] src/chainparams.cpp:1464 at `6504a3af`.
    bip34Hash := 0
    -- [SRC] src/chainparams.cpp:1512–1515 at `6504a3af`.
    hashGenesisBlock := 0x0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206
  }

/-- Project the script heights without filling absent source assignments.
[SRC] src/verify_script_flags.cpp:32–78 at `6504a3af`; field identities are
PARAMETERS §8.3. STN needs resolved source evidence before this projection exists. -/
def ChainParams.toScript? (p : ChainParams) : Option BsvScript.Params.ChainParams := do
  let bip65Height ← p.bip65Height
  let bip66Height ← p.bip66Height
  let csvHeight ← p.csvHeight
  return { p2shHeight := p.p2shHeight, bip65Height, bip66Height, csvHeight,
           uahfHeight := p.uahfHeight, daaHeight := p.daaHeight,
           genesisHeight := p.genesisHeight, chronicleHeight := p.chronicleHeight }

/-- Policy scheduler choices [SRC] src/txn_validation_config.h:11–27 at `6504a3af`.
The UNKNOWN sentinel is refused by src/config.cpp:782–795. Indexed in §8.2's
ptvTaskScheduleStrategy row. -/
inductive PTVTaskScheduleStrategy where
  | chainDetector
  | topoSort
  deriving DecidableEq, Repr

/-- Chain-layer configuration, extending the existing script configuration.
The inherited fields and the additional fields have ordered census rows in §8.
The `policy (node setting)` fields are local switches, including observation and
operator-list companion settings; they are not shared consensus constants. -/
structure NodeConfig extends BsvScript.Params.NodeConfig where
  /-- Kind: policy. Default: `10000`. Presence: optional.
  Units: transactions.
  [SRC] Definition: src/validation.h:86; initialization: src/config.cpp:49
  at `6504a3af`. Read: src/validation.cpp:783–792,1313–1318.
  receiveTx checks the accepted ancestor count. -/
  limitAncestorCount : Nat := 10000

  /-- Kind: policy. Default: `1000000000`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/policy/policy.h:87; initialization: src/config.cpp:83
  at `6504a3af`. Read: src/validation.cpp:938–945,4111.
  receiveTx trims the pool; disconnectBlock caps its temporary disconnect pool. 1,000 decimal MB,
  resolved to bytes. -/
  maxMempool : Nat := 1000000000

  /-- Kind: policy. Default: `52428800`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/policy/policy.h:89; initialization: src/time_locked_mempool.cpp:400
  at `6504a3af`. Read: src/validation.cpp:1119–1123.
  receiveTx refuses holding when the non-final pool has no capacity. 50 MiB, resolved to bytes; the
  option is -maxmempoolnonfinal. -/
  maxMempoolNonFinal : Nat := 52428800

  /-- Kind: policy. Default: `1209600`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/validation.h:91; initialization: src/config.cpp:87
  at `6504a3af`. Read: src/txmempool.cpp:2201–2221.
  advanceTime expires accepted entries and their descendants. 336 hours, resolved to seconds. -/
  mempoolExpiry : Nat := 1209600

  /-- Kind: policy. Default: `2419200`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/validation.h:93; initialization: src/time_locked_mempool.cpp:404
  at `6504a3af`. Read: src/time_locked_mempool.cpp:627–628,655–660.
  advanceTime purges expired non-final entries. 672 hours, resolved to seconds; the option is
  -mempoolexpirynonfinal. -/
  mempoolNonFinalExpiry : Nat := 2419200

  /-- Kind: policy. Default: `1000000000`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/orphan_txns.h:49; initialization: src/config.cpp:88
  at `6504a3af`. Read: src/validation.cpp:1911–1915.
  receiveTx caps the total orphan pool. One decimal GB of aggregate transactions, distinct from the
  inherited per-transaction maxTxSizePolicy. -/
  maxOrphanTxSize : Nat := 1000000000

  /-- Kind: policy. Default: `10`. Presence: optional.
  Units: divisor.
  [SRC] Definition: src/validation.cpp:1914; initialization: src/validation.cpp:1914
  at `6504a3af`. Read: src/orphan_txns.cpp:175–192.
  receiveTx trims with hysteresis equal to maxOrphanTxSize divided by this value. Model parameter for
  a local constant, no CLI; must be positive. -/
  orphanTrimHysteresisDivisor : Nat := 10

  /-- Kind: policy. Default: `500`. Presence: mandatory.
  Units: satoshis per 1000 bytes.
  [SRC] Definition: src/policy/policy.h:64–66; initialization: src/txmempool.h:437–438
  at `6504a3af`. Read: src/validation.cpp:1267–1273.
  receiveTx credits consolidation fees and classifies primary-pool entries. Constructor template
  only; no implicit daemon default. Launch requires -minminingtxfee (src/bitcoind.cpp:158–164;
  src/init.cpp:3115–3121). -/
  blockMinTxFee : Int := 500

  /-- Kind: policy. Default: `0`. Presence: optional.
  Units: satoshis per 1000 bytes.
  [SRC] Definition: src/config.cpp:2350–2351; initialization: src/config.cpp:32;
  src/init.cpp:3093–3099
  at `6504a3af`. Read: src/txmempool.cpp:1883–1888.
  No admission transition reads this static value; the fee-estimate observation takes its maximum
  with the rolling floor. The launch value is zero; -minrelaytxfee is removed.
  DEFAULT_MIN_RELAY_TX_FEE = 250 (src/validation.h:77) is not this initialized value. -/
  minRelayTxFee : Int := 0

  /-- Kind: policy. Default: `0`. Presence: optional.
  Units: satoshis per 1000 bytes.
  [SRC] Definition: src/txmempool.h:439; initialization: src/txmempool.h:439; src/init.cpp:3135–3146
  at `6504a3af`. Read: src/txmempool.cpp:2644–2647.
  receiveTx takes the maximum of this value and the truncated rolling fee. A nonzero override is
  permitted only off mainnet. -/
  minDebugRejectionFee : Int := 0

  /-- Kind: policy. Default: `10000000`. Presence: optional.
  Units: satoshis.
  [SRC] Definition: src/validation.h:79; initialization: src/validation.cpp:108;
  src/rpc/rawtransaction.cpp:1571–1573
  at `6504a3af`. Read: src/validation.cpp:1249–1254.
  receiveTx applies the request fee ceiling. RPC request default; allowhighfees replaces that request
  ceiling with zero, never a consensus cap. -/
  maxTxFee : Nat := 10000000

  /-- Kind: policy. Default: `3`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/txn_validation_config.h:39–40; initialization: src/config.cpp:64
  at `6504a3af`. Read: src/validation.cpp:999–1005,1077.
  receiveTx supplies the standard validation budget; expiration is an explicit observation. Budget
  observations whose outcome depends on the node's validation clock remain non-judging under the
  observation contract in BsvChain.Rejects (#71). -/
  maxStdTxnValidationDuration : Nat := 3

  /-- Kind: policy. Default: `1000`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/txn_validation_config.h:42–43; initialization: src/config.cpp:65
  at `6504a3af`. Read: src/validation.cpp:999–1005,1210–1240.
  receiveTx supplies the non-standard validation budget. One second, resolved to milliseconds. -/
  maxNonStdTxnValidationDuration : Nat := 1000

  /-- Kind: consensus, node-configurable. Default: `9223372036854775807`. Presence: mandatory.
  Units: bytes.
  [SRC] Definition: src/config.cpp:232–251; initialization: src/policy/policy.h:39;
  src/chainparams.cpp:1178; src/config.cpp:211–218
  at `6504a3af`. Read: src/validation.cpp:5795–5814,6058–6064.
  acceptBlock and connectBlock check serialized block size. Library template and zero-resolution
  value only; launch requires -excessiveblocksize (src/bitcoind.cpp:140–157), with zero resolved by
  src/config.cpp:243. -/
  excessiveBlockSize : Nat := 9223372036854775807

  /-- Kind: policy (node setting). Default: `false`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/config.cpp:2051–2067; initialization: src/chainparams.cpp:1186–1187
  at `6504a3af`. Read: src/validation.cpp:3097–3100.
  connectBlock resolves the BIP30 switch. Resolved default: false on all four networks [SRC] src/chainparams.cpp:1186,1300,1447,1555.
  Declared permission: false on mainnet, true on STN, testnet and regtest
  [SRC] src/chainparams.cpp:1187,1301,1448,1556 at `6504a3af`.
  The getter resolves an unset value to the network default [SRC] src/config.cpp:2065–2067.
  #69 records each network's permission (`NetworkData.canDisableBip30Checks`) and reads the
  resolved value in `bip30Enforced`; the setting does not replace the historical exceptions. -/
  disableBip30Checks : Bool := false

  /-- Kind: policy (node setting). Default: `3`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:219; initialization: src/config.cpp:180
  at `6504a3af`. Read: src/validation.cpp:3402–3407,3720–3741.
  connectBlock sets the operator-list companion freeze; activateBestChain observes it. Resolved
  value; option zero maps to 2147483647 at src/config.cpp:2602–2610. The lists themselves remain
  State inputs (#70). -/
  softConsensusFreezeDuration : Nat := 3

  /-- Kind: policy (node setting). Default:
  `0x000000000000000000000000000000000000000000a0f3064330647e2f6c4828`. Presence: optional.
  Units: accumulated work.
  [SRC] Definition: src/consensus/params.h:50; initialization: src/chainparams.cpp:1056–1057;
  src/init.cpp:2364–2375
  at `6504a3af`. Read: src/validation.cpp:3496,6329.
  acceptBlock gates unrequested bodies and connectBlock gates assumevalid. Mainnet template;
  `NodeConfig.withNetwork` (#69) supplies the network defaults (regtest zero). -/
  minimumChainWork : Nat := 0x000000000000000000000000000000000000000000a0f3064330647e2f6c4828

  /-- Kind: policy (node setting). Default:
  `0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2`. Presence: optional.
  Units: block hash, displayed integer order.
  [SRC] Definition: src/consensus/params.h:51; initialization: src/chainparams.cpp:1061–1062;
  src/init.cpp:2355–2357
  at `6504a3af`. Read: src/validation.cpp:3482–3518.
  connectBlock may omit ordinary script checks only under the ancestry, work and depth predicates.
  Zero disables the shortcut; `NodeConfig.withNetwork` (#69) replaces this mainnet template with the
  selected network's default. -/
  assumeValid : BitVec 256 := 0x000000000000000000e45ad2fbcc5ff3e85f0868dd8f00ad4e92dffabe28f8d2

  /-- Kind: policy (node setting). Default: `true`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/validation.h:189; initialization: src/init.cpp:2352–2353
  at `6504a3af`. Read: src/validation.cpp:6179–6184.
  receiveHeader applies the selected network checkpoint table. The per-network tables are
  `NetworkData.checkpoints` (#69). -/
  checkpointsEnabled : Bool := true

  /-- Kind: policy (node setting). Default: `288`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:272; initialization: src/config.cpp:100
  at `6504a3af`. Read: src/validation.cpp:6289–6290,6321.
  acceptBlock limits how far an unrequested body may be ahead. -/
  minBlocksToKeep : Nat := 288

  /-- Kind: policy. Default: `100`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:345–350; initialization: src/validation.h:350
  at `6504a3af`. Read: src/validation.cpp:5671–5682.
  acceptBlock selects the local TTOR order check below the active tip. Model parameter for a local
  policy constant, no CLI. -/
  minTtorValidationDistance : Nat := 100

  /-- Kind: policy (node setting). Default: `false`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/validation.h:190; initialization: src/validation.cpp:7183
  at `6504a3af`. Read: src/rpc/rawtransaction.cpp:194–204.
  No state-validity transition reads this setting; it selects the supplementary transaction
  observation surface. -/
  txIndex : Bool := false

  /-- Kind: policy (node setting). Default: `[]`. Presence: optional.
  Units: block hashes, displayed integer order.
  [SRC] Definition: src/config.h:879; initialization: src/config.h:879; src/init.cpp:3265–3274
  at `6504a3af`. Read: src/config.cpp:992–994; src/validation.cpp:6144–6149.
  receiveHeader refuses an operator-listed block. An empty operator input by default, never a
  consensus blacklist. -/
  invalidBlocks : List (BitVec 256) := []

  /-- Kind: policy. Default: `25`. Presence: optional.
  Units: transactions.
  [SRC] Definition: src/validation.h:88; initialization: src/config.cpp:50
  at `6504a3af`. Read: src/validation.cpp:783–792.
  receiveTx checks the secondary-pool ancestor count. -/
  limitSecondaryMempoolAncestorCount : Nat := 25

  /-- Kind: policy. Default: `0`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/config.cpp:872–879; initialization: src/config.cpp:70
  at `6504a3af`. Read: src/validation.cpp:1168–1175.
  receiveTx bounds the fetched input scripts when request limits apply. Zero means unlimited. -/
  maxCoinsViewCacheSize : Nat := 0

  /-- Kind: policy. Default: `0`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/policy/policy.h:94–95; initialization: src/config.cpp:84
  at `6504a3af`. Read: src/validation.cpp:834–844; src/txmempool.cpp:2704–2800.
  receiveTx and advanceTime use RAM plus disk accounting for eviction. Default disk factor zero times
  maxMempool; this field stores the resolved bytes. -/
  maxMempoolSizeDisk : Nat := 0

  /-- Kind: policy. Default: `10`. Presence: optional.
  Units: percent.
  [SRC] Definition: src/policy/policy.h:96–97; initialization: src/config.cpp:85
  at `6504a3af`. Read: src/validation.cpp:834–844.
  receiveTx and advanceTime cap secondary-pool memory as this percentage of maxMempool. The source
  comment mentions RAM plus disk; the constructor actually multiplies this fraction by limitMemory
  (src/validation.cpp:843). -/
  mempoolMaxPercentCPFP : Nat := 10

  /-- Kind: policy. Default: `7200`. Presence: optional.
  Units: updates per configured period.
  [SRC] Definition: src/validation.h:94–95; initialization: src/time_locked_mempool.cpp:406
  at `6504a3af`. Read: src/validation.cpp:1127–1130.
  receiveTx checks the retained non-final replacement-rate history. -/
  nonFinalMaxReplacementRate : Nat := 7200

  /-- Kind: policy. Default: `60`. Presence: optional.
  Units: minutes.
  [SRC] Definition: src/validation.h:96–97; initialization: src/time_locked_mempool.cpp:408
  at `6504a3af`. Read: src/time_locked_mempool.cpp:53,179–205.
  receiveTx measures the non-final replacement rate over this period. -/
  nonFinalReplacementPeriodMinutes : Nat := 60

  /-- Kind: policy. Default: `600000`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/time_locked_mempool.h:78–79; initialization: src/time_locked_mempool.cpp:402
  at `6504a3af`. Read: src/time_locked_mempool.cpp:611–660.
  advanceTime schedules revalidation and purging of held transactions. The scheduler completion is an
  explicit event, not inferred from now alone. -/
  nonFinalCheckFrequencyMs : Nat := 600000

  /-- Kind: policy. Default: `1200`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/orphan_txns.h:27–28; initialization: src/orphan_txns.h:28;
  src/orphan_txns.cpp:68
  at `6504a3af`. Read: src/orphan_txns.cpp:195–225.
  advanceTime expires orphan entries. Model parameter for a local constant, no CLI. -/
  orphanExpirySeconds : Nat := 1200

  /-- Kind: policy. Default: `300`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/orphan_txns.h:29–30; initialization: src/orphan_txns.h:30;
  src/orphan_txns.cpp:224
  at `6504a3af`. Read: src/orphan_txns.cpp:195–225.
  advanceTime gates the next orphan sweep. Model parameter for a local constant, no CLI. -/
  orphanExpiryCheckIntervalSeconds : Nat := 300

  /-- Kind: policy. Default: `60`. Presence: optional.
  Units: percent.
  [SRC] Definition: src/orphan_txns.h:55–56; initialization: src/config.cpp:89;
  src/txn_validator.cpp:39
  at `6504a3af`. Read: src/orphan_txns.cpp:303–307.
  receiveTx and advanceTime bound orphan retries in a validation batch. -/
  maxPercentageOfOrphansInBatch : Nat := 60

  /-- Kind: policy. Default: `5`. Presence: optional.
  Units: inputs or outputs.
  [SRC] Definition: src/orphan_txns.h:53–54; initialization: src/config.cpp:90;
  src/txn_validator.cpp:40
  at `6504a3af`. Read: src/orphan_txns.cpp:318–339.
  receiveTx and advanceTime bound secondary orphan retries. -/
  maxInputsOutputsPerSecondaryOrphan : Nat := 5

  /-- Kind: policy. Default: `20`. Presence: optional.
  Units: ratio.
  [SRC] Definition: src/policy/policy.h:71–72; initialization: src/config.cpp:45
  at `6504a3af`. Read: src/policy/policy.cpp:24–29,147; src/validation.cpp:1267.
  receiveTx checks consolidation eligibility. -/
  minConsolidationFactor : Nat := 20

  /-- Kind: policy. Default: `150`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/policy/policy.h:73–74; initialization: src/config.cpp:46
  at `6504a3af`. Read: src/policy/policy.cpp:111; src/validation.cpp:1267.
  receiveTx caps each consolidation unlocking script. -/
  maxConsolidationInputScriptSize : Nat := 150

  /-- Kind: policy. Default: `6`. Presence: optional.
  Units: confirmations.
  [SRC] Definition: src/policy/policy.h:75–76; initialization: src/config.cpp:47
  at `6504a3af`. Read: src/policy/policy.cpp:97–107; src/validation.cpp:1267.
  receiveTx checks consolidation input confirmations. -/
  minConfConsolidationInput : Nat := 6

  /-- Kind: policy. Default: `false`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/policy/policy.h:77–78; initialization: src/config.cpp:48
  at `6504a3af`. Read: src/policy/policy.cpp:123–133; src/validation.cpp:1267.
  receiveTx selects whether non-standard inputs qualify for consolidation. -/
  acceptNonStdConsolidationInput : Bool := false

  /-- Kind: policy. Default: `43200`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/txmempool.h:626–627; initialization: src/txmempool.h:485
  at `6504a3af`. Read: src/txmempool.cpp:2624–2647.
  receiveTx and advanceTime decay the retained rolling fee. Optional CLI range 1800 to 43200, checked
  at src/txmempool.cpp:2615–2621. -/
  rollingFeeHalfLifeSeconds : Nat := 43200

  /-- Kind: policy. Default: `1000`. Presence: optional.
  Units: satoshis per 1000 bytes.
  [SRC] Definition: src/policy/policy.h:90–91; initialization: src/policy/policy.h:91
  at `6504a3af`. Read: src/txmempool.cpp:2781–2787.
  receiveTx and advanceTime raise the rolling fee after eviction. Model parameter for a local
  constant, no CLI. -/
  mempoolFullFeeIncrement : Int := 1000

  /-- Kind: policy. Default: `120000`. Presence: optional.
  Units: entries.
  [SRC] Definition: src/txn_recent_rejects.cpp:9–11; initialization: src/txn_recent_rejects.cpp:11
  at `6504a3af`. Read: src/net/net.cpp:3558–3564; src/validation.cpp:1988–1995.
  receiveTx consults and inserts in the reject filter; tip changes reset it. Model parameter for the
  rolling filter, no CLI. -/
  recentRejectCapacity : Nat := 120000

  /-- Kind: policy. Default: `(1, 1000000)`. Presence: optional.
  Units: probability numerator and denominator.
  [SRC] Definition: src/txn_recent_rejects.cpp:9–11; initialization: src/txn_recent_rejects.cpp:11
  at `6504a3af`. Read: src/txn_recent_rejects.cpp:19–21.
  receiveTx uses the reject-filter observation contract in BsvChain.Rejects (#71). The requested
  probability 0.000001 is represented as a ratio; the machine uses an ideal set and explicit
  false-positive observations. Readings outside the wipe-free regime and declared false positives are
  non-judging. No randomness is read here. -/
  recentRejectFalsePositiveRate : Nat × Nat := (1, 1000000)

  /-- Kind: policy. Default: `50`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/txn_validation_config.h:44–46; initialization: src/init.cpp:2880–2885
  at `6504a3af`. Read: src/validation.cpp:1577.
  receiveTx caps carried validation budget along a transaction chain. -/
  maxTxnChainValidationBudget : Nat := 50

  /-- Kind: policy. Default: `true`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/txn_validation_config.h:36–37; initialization: src/init.cpp:2890
  at `6504a3af`. Read: src/validation.cpp:999–1005.
  receiveTx selects the supplied CPU-time or wall-time budget observation. The executable machine
  reads neither clock itself. -/
  validationClockCpu : Bool := true

  /-- Kind: policy (node setting). Default: `1000`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:310–315; initialization: src/config.cpp:185
  at `6504a3af`. Read: src/safe_mode.cpp:81–87.
  activateBestChain updates the client safe-mode observation. No effect on block validity. -/
  safeModeMaxForkDistance : Nat := 1000

  /-- Kind: policy (node setting). Default: `6`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:317–320; initialization: src/config.cpp:186
  at `6504a3af`. Read: src/safe_mode.cpp:72–78.
  activateBestChain updates the client safe-mode observation. No effect on block validity. -/
  safeModeMinForkLength : Nat := 6

  /-- Kind: policy (node setting). Default: `-72`. Presence: optional.
  Units: block-equivalent work difference.
  [SRC] Definition: src/validation.h:322–326; initialization: src/config.cpp:187
  at `6504a3af`. Read: src/safe_mode.cpp:90–99.
  activateBestChain updates the client safe-mode observation. Signed; no effect on block validity. -/
  safeModeMinPowDifference : Int := -72

  /-- Kind: policy (node setting). Default: `false`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/policy/policy.h:98–99; initialization: src/config.cpp:97
  at `6504a3af`. Read: src/validation.cpp:3530–3554.
  connectBlock selects the operator-list depth waiver. Companion setting of the operator-list
  mechanism; the lists are State inputs (#70). -/
  enableAssumeWhitelistedBlockDepth : Bool := false

  /-- Kind: policy (node setting). Default: `6`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/policy/policy.h:100–101; initialization: src/config.cpp:98
  at `6504a3af`. Read: src/validation.cpp:3532–3554.
  connectBlock measures the operator-list depth waiver. Companion setting of the operator-list
  mechanism. -/
  assumeWhitelistedBlockDepth : Nat := 6

  /-- Kind: consensus. Default: `100`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/consensus/consensus.h:71–75; initialization: src/consensus/consensus.h:75
  at `6504a3af`. Read: src/validation.cpp:2617–2625; src/txmempool.cpp:987–1009.
  receiveTx, applyTx and connectBlock check coinbase maturity; activateBestChain rechecks it. Model
  parameter for a consensus constant, no CLI. -/
  coinbaseMaturity : Nat := 100

  /-- Kind: consensus. Default: `1000`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/consensus/consensus.h:76–79; initialization: src/consensus/consensus.h:79
  at `6504a3af`. Read: src/validation.cpp:2628–2636; src/txmempool.cpp:987–1009.
  receiveTx, applyTx and connectBlock check confiscation-output maturity; activateBestChain rechecks
  it. The maturity predicate is separate from operator-list membership; model constant, no CLI. -/
  confiscationMaturity : Nat := 1000

  /-- Kind: consensus. Default: `7200`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/block_index.h:28–31; initialization: src/block_index.h:31
  at `6504a3af`. Read: src/validation.cpp:5956–5959,6187.
  receiveHeader compares the header time to the explicitly supplied adjusted now. Model parameter for
  a consensus constant, no CLI. -/
  maxFutureBlockTimeSeconds : Nat := 7200

  /-- Kind: consensus. Default: `11`. Presence: optional.
  Units: headers.
  [SRC] Definition: src/block_index.h:720; initialization: src/block_index.h:720
  at `6504a3af`. Read: src/block_index.h:722–737; src/validation.cpp:5950–5953,6026–6028,6048.
  receiveHeader, receiveTx and connectBlock derive median time past for their time predicates. Model
  parameter for a consensus constant, no CLI; must be positive. -/
  medianTimeSpan : Nat := 11

  /-- Kind: consensus. Default: `20000`. Presence: optional.
  Units: sigops per rounded-up decimal MB.
  [SRC] Definition: src/consensus/consensus.h:33–37; initialization: src/consensus/consensus.h:37
  at `6504a3af`. Read: src/config.cpp:831–834; src/validation.cpp:3480,5853–5866.
  acceptBlock and connectBlock cap the pre-Genesis block sigop sum. Model parameter for a consensus
  constant, no CLI. -/
  maxBlockSigOpsPerMbBeforeGenesis : Nat := 20000

  /-- Kind: policy. Default: `72`. Presence: optional.
  Units: blocks on each side of activation.
  [SRC] Definition: src/policy/policy.h:121–128; initialization: src/configscriptpolicy.cpp:54
  at `6504a3af`. Read: src/validation.cpp:1040–1052,2730.
  receiveTx selects the Genesis grace re-check. Range 0 to 7200; this changes relay handling, never
  the activation rule. -/
  genesisGracefulPeriod : Nat := 72

  /-- Kind: policy. Default: `72`. Presence: optional.
  Units: blocks on each side of activation.
  [SRC] Definition: src/policy/policy.h:130–133; initialization: src/configscriptpolicy.cpp:55
  at `6504a3af`. Read: src/validation.cpp:1362–1392,2731.
  receiveTx selects the Chronicle grace re-check. Range 0 to 7200; this changes relay handling, never
  the activation rule. -/
  chronicleGracefulPeriod : Nat := 72

  /-- Kind: policy. Default: `true`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/chainparams.h:86; initialization: src/chainparams.cpp:1121
  at `6504a3af`. Read: src/validation.cpp:795–801.
  receiveTx selects the relay flag word using the chain default. Distinct from inherited
  requireStandard, which controls the admission refusal. `NodeConfig.withNetwork` (#69) projects the
  chosen network value; mainnet true, test networks false. -/
  chainRequireStandard : Bool := true

  /-- Kind: policy (node setting). Default: `1209600`. Presence: optional.
  Units: proof-equivalent seconds.
  [SRC] Definition: src/validation.cpp:3511–3514; initialization: src/validation.cpp:3514
  at `6504a3af`. Read: src/validation.cpp:3482–3518.
  connectBlock requires more than this depth before the assumevalid shortcut. Model parameter for a
  local setting constant, no CLI; two weeks. -/
  assumeValidMinWorkTimeSeconds : Nat := 1209600

  /-- Kind: policy. Default: `10`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/txmempool.cpp:2629; initialization: src/txmempool.cpp:2629
  at `6504a3af`. Read: src/txmempool.cpp:2624–2647.
  receiveTx and advanceTime gate rolling-fee decay. Model parameter for a local constant, no CLI; the
  comparison is strict. -/
  rollingFeeUpdateIntervalSeconds : Nat := 10

  /-- Kind: policy. Default: `4`. Presence: optional.
  Units: divisor.
  [SRC] Definition: src/txmempool.cpp:2631–2632; initialization: src/txmempool.cpp:2631–2632
  at `6504a3af`. Read: src/txmempool.cpp:2624–2647.
  receiveTx and advanceTime shorten the fee half-life below this fraction of pool capacity. Model
  parameter for a local constant, no CLI; must be positive. -/
  rollingFeeLowUsageDivisor : Nat := 4

  /-- Kind: policy. Default: `2`. Presence: optional.
  Units: divisor.
  [SRC] Definition: src/txmempool.cpp:2633–2634; initialization: src/txmempool.cpp:2633–2634
  at `6504a3af`. Read: src/txmempool.cpp:2624–2647.
  receiveTx and advanceTime shorten the fee half-life at medium pool usage. Model parameter for a
  local constant, no CLI; must be positive. -/
  rollingFeeMediumUsageDivisor : Nat := 2

  /-- Kind: policy. Default: `10000`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/txn_validator.h:82–85; initialization: src/config.cpp:66
  at `6504a3af`. Read: src/txn_validator.cpp:355–357.
  receiveTx and advanceTime cap an asynchronous validation round. Scheduling and budget expiration
  remain explicit non-judging observations (#71). -/
  maxTxnValidatorAsyncTasksRunDuration : Nat := 10000

  /-- Kind: policy. Default: `10`. Presence: optional.
  Units: milliseconds.
  [SRC] Definition: src/txn_validator.h:80–81; initialization: src/txn_validator.cpp:24–26
  at `6504a3af`. Read: src/txn_validator.cpp:329–355.
  advanceTime schedules the pending validation queue. Scheduling completion remains an explicit event
  (#71). -/
  txnValidationAsyncRunFrequencyMs : Nat := 10

  /-- Kind: policy. Default: `2147483648`. Presence: optional.
  Units: bytes.
  [SRC] Definition: src/txn_validator.h:86–87; initialization: src/txn_validator.cpp:42–46
  at `6504a3af`. Read: src/txn_validator.cpp:716–723.
  receiveTx bounds pending validation queue memory. 2048 MiB, resolved to bytes; separate from
  accepted mempool accounting. -/
  txnValidationQueueMaxMemory : Nat := 2147483648

  /-- Kind: policy. Default: `1000`. Presence: optional.
  Units: transactions per worker.
  [SRC] Definition: src/txn_validation_config.h:32–33; initialization: src/txn_validator.cpp:345–349
  at `6504a3af`. Read: src/txn_validator.cpp:375–422.
  advanceTime bounds the standard work selected for a validation round. Worker counts and completion
  order are explicit scheduling inputs (#71), never inferred host facts. -/
  maxStdTxnsPerThreadRatio : Nat := 1000

  /-- Kind: policy. Default: `1000`. Presence: optional.
  Units: transactions per worker.
  [SRC] Definition: src/txn_validation_config.h:34–35; initialization: src/txn_validator.cpp:350–353
  at `6504a3af`. Read: src/txn_validator.cpp:375–422.
  advanceTime bounds the non-standard work selected for a validation round. Worker counts and
  completion order are explicit scheduling inputs (#71). -/
  maxNonStdTxnsPerThreadRatio : Nat := 1000

  /-- Kind: policy (node setting). Default: `32`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.cpp:4675–4694; initialization: src/validation.cpp:4677
  at `6504a3af`. Read: src/validation.cpp:4675–4694.
  activateBestChain bounds a forward connection batch. Model parameter for a local batching constant,
  no CLI; must be positive. -/
  maxBlockConnectionBatch : Nat := 32

  /-- Kind: policy. Default: `10000`. Presence: optional.
  Units: entries.
  [SRC] Definition: src/time_locked_mempool.h:213–214; initialization: src/time_locked_mempool.h:214
  at `6504a3af`. Read: src/time_locked_mempool.cpp:217–221.
  receiveTx can consult the recently removed non-final filter through its submission path. Model
  parameter for the separate rolling filter. Mempool.nonFinalRecentlyRemoved retains its ideal members
  and insertion count, read by knownElsewhere. Exact readings require this filter's wipe-free regime
  and absence of a declared false positive; other readings are non-judging under the inventory
  observation contract (#71). -/
  nonFinalRecentlyRemovedCapacity : Nat := 10000

  /-- Kind: policy. Default: `(1, 1000000)`. Presence: optional.
  Units: probability numerator and denominator.
  [SRC] Definition: src/time_locked_mempool.h:213–214; initialization: src/time_locked_mempool.h:214
  at `6504a3af`. Read: src/time_locked_mempool.cpp:217–221.
  receiveTx can consult the recently removed non-final filter through its submission path. Model
  parameter for the separate rolling filter. Mempool.nonFinalRecentlyRemoved retains its ideal members
  and insertion count, read by knownElsewhere. Exact readings require this filter's wipe-free regime
  and absence of a declared false positive; other readings are non-judging under the inventory
  observation contract (#71). -/
  nonFinalRecentlyRemovedFalsePositiveRate : Nat × Nat := (1, 1000000)


  /-- Kind: policy (node setting). Default: `PTVTaskScheduleStrategy.topoSort`. Presence: optional.
  Units: scheduler choice.
  [SRC] Definition: src/txn_validation_config.h:47–48; initialization: src/config.cpp:68; src/init.cpp:2903–2909
  at `6504a3af`. Read: src/txn_validator.cpp:595.
  receiveTx selects the PTV task scheduler. The constructor topoSort represents TOPO_SORT; chainDetector represents CHAIN_DETECTOR. -/
  ptvTaskScheduleStrategy : PTVTaskScheduleStrategy := PTVTaskScheduleStrategy.topoSort

  /-- Kind: policy (node setting). Default: `10`. Presence: optional.
  Units: transactions.
  [SRC] Definition: src/validation.h:107–108; initialization: src/config.cpp:102; src/init.cpp:2646
  at `6504a3af`. Read: src/validation.cpp:3566–3572.
  connectBlock groups transactions for parallel validation; the batch size must be positive. -/
  blockValidationTxBatchSize : Nat := 10

  /-- Kind: policy (node setting). Default: `128`. Presence: optional.
  Units: script checks.
  [SRC] Definition: src/validation.h:216–217; initialization: src/config.cpp:60; src/init.cpp:2411
  at `6504a3af`. Read: src/validation.cpp:2964.
  Block validation initializes the maximum script-check batch size. -/
  scriptValidationMaxBatchSize : Nat := 128

  /-- Kind: policy (node setting). Default: `4`. Presence: optional.
  Units: blocks.
  [SRC] Definition: src/validation.h:214–215; initialization: src/config.cpp:57; src/init.cpp:2408
  at `6504a3af`. Read: src/validation.cpp:2961,5013–5015.
  activateBestChain bounds concurrent sibling validations and initializes the script-check pool. -/
  maxParallelBlocks : Nat := 4

  /-- Kind: policy (node setting). Default: `0`. Presence: optional.
  Units: block height.
  [SRC] Definition: src/validation.h:211–212; initialization: src/config.cpp:91; src/init.cpp:2457
  at `6504a3af`. Read: src/validation.cpp:5116–5119.
  activateBestChain requests shutdown at or above the selected height; zero disables this observation. -/
  stopAtHeight : Nat := 0

  /-- Kind: policy (node setting). Default: `false`. Presence: optional.
  Units: switch.
  [SRC] Definition: src/validation.h:221–222; initialization: src/config.cpp:191; src/init.cpp:3167
  at `6504a3af`. Read: src/txmempool.cpp:1123–1128.
  connectBlock observes a potentially selfishly mined block while updating the pool; it does not reject the block. -/
  detectSelfishMining : Bool := false

  /-- Kind: policy (node setting). Default: `60`. Presence: optional.
  Units: seconds.
  [SRC] Definition: src/policy/policy.h:164–166; initialization: src/config.cpp:190; src/init.cpp:3171–3174
  at `6504a3af`. Read: src/txmempool.cpp:1180–1186.
  The selfish-mining observation compares the last retained mempool transaction time with the last block transaction time. -/
  minBlockMempoolTimeDifferenceSelfish : Nat := 60

  /-- Kind: policy (node setting). Default: `10`. Presence: optional.
  Units: percent.
  [SRC] Definition: src/policy/policy.h:168–172; initialization: src/config.cpp:192; src/init.cpp:3181–3184
  at `6504a3af`. Read: src/txmempool.cpp:1239–1242.
  The selfish-mining observation compares the percentage of omitted transactions above the block fee rate with this threshold. -/
  selfishTxPercentThreshold : Nat := 10
  /-- Kind: policy. Default: `1000`. Presence: optional.
  Units: visited transactions.
  [SRC] Definition: src/txmempool.h:423; initialization: src/txmempool.h:423
  at `6504a3af`. Read: src/txmempool.cpp:481–565.
  receiveTx bounds propagation of primary-pool promotion. The loop stops only
  after the count exceeds the bound; one whole CPFP group can cross it.
  Model parameter for a fixed source constant, no CLI. -/
  maxPrimaryPromotionVisits : Nat := 1000

  /-- Kind: consensus. Default: `20000`. Presence: optional.
  Units: sigops per transaction before Genesis.
  [SRC] Definition: src/consensus/consensus.h:46–47; initialization: src/consensus/consensus.h:47
  at `6504a3af`. Read: src/config.cpp:2417–2420; src/validation.cpp:1032–1035,1046.
  Fixed consensus getter, no CLI. The regular gate reads this census field. -/
  maxTxSigOpsCountConsensusBeforeGenesis : Nat := 20000

  /-- Kind: consensus. Default: `1000000`. Presence: optional.
  Units: serialized bytes before Genesis.
  [SRC] Definition: src/consensus/consensus.h:12–15,26–27; initialization: src/consensus/consensus.h:27
  at `6504a3af`. Read: src/configscriptpolicy.cpp:397–405; src/validation.cpp:1033–1035,1043–1046.
  Fixed consensus getter, no CLI. Also selected by the opposite-era grace check. -/
  maxTxSizeConsensusBeforeGenesis : Nat := 1000000

  /-- Kind: consensus. Default: `1000000000`. Presence: optional.
  Units: serialized bytes after Genesis.
  [SRC] Definition: src/consensus/consensus.h:12–17,28–29; initialization: src/consensus/consensus.h:29
  at `6504a3af`. Read: src/configscriptpolicy.cpp:408–412; src/validation.cpp:1033–1035,1043–1046.
  Fixed consensus getter, no CLI. Also selected by the opposite-era grace check. -/
  maxTxSizeConsensusAfterGenesis : Nat := 1000000000

  deriving DecidableEq, Repr

/-- Mainnet library initialization at the pin. Mandatory launch inputs must be
supplied by a scenario or launcher; see the module documentation and §8. -/
def NodeConfig.defaults : NodeConfig :=
  { toNodeConfig := BsvScript.Params.NodeConfig.svMainnetDefault }

/-- The default instance carries the documented library template. -/
instance instInhabitedNodeConfig : Inhabited NodeConfig := ⟨NodeConfig.defaults⟩

end BsvChain
