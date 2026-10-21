# s6-66-utx-scripts-false

[X] Classification: observation limit (reason detail) as data. The exact prefix, submitted bytes, expected and actual observations are retained below.

```json
{
  "id": "s6-66-utx-scripts-false",
  "class": "node observation differs from declared projection",
  "classification": "observation limit (reason detail)",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "input_label": "[D]",
  "witness": {
    "family": "utxo",
    "row": "scripts/false",
    "receipt": "docs/records/20261013-045648-s6-66-utx-regtest-s3.json",
    "fixtures": {
      "conf": "# #66 isolated regtest profile; bitcoin-sv pin\n# 6504a3aff65ba97c0f6c80962b033e35ecbfed4b [SRC].\n# Regtest and txindex: src/chainparams.cpp:1457-1523; src/init.cpp:617-620,3797-3800.\nregtest=1\ntxindex=1\n# Server and loopback binding: src/init.cpp:1342-1378; src/httpserver.cpp:220-245.\nserver=1\nrpcbind=127.0.0.1\nrpcallowip=127.0.0.1\n# Isolation: src/init.cpp:711-735,830-837,3688-3689,4120;\n# regtest has empty seeds: src/chainparams.cpp:1520-1523. No addnode/connect.\nlisten=0\ndnsseed=0\ndiscover=0\nupnp=0\n# Expiry witness: src/validation.cpp:853-856; debug category selection src/init.cpp:2288-2304.\n# Logging: src/init.cpp:2042,2288-2304,3507-3510. Console captured in the owned datadir.\ndebug=mempool\nprinttoconsole=1\nshrinkdebugfile=1\n# Required launch inputs: src/bitcoind.cpp:140-164. Size supplied per run.\nmaxstackmemoryusageconsensus=100000000\nminminingtxfee=0.00000500\n# Cookie authentication: src/httprpc.cpp:341-351. No credentials here.\nrpcport=18571\nport=18572\nexcessiveblocksize=1000001\ngenesisactivationheight=101\nchronicleactivationheight=111\n",
      "evidence": {
        "before": {
          "bestblock": "34899e79c6929bfdb504cc533d4e3ec116607fdb6a28979a7eb650eb2ceb7ec4",
          "coinbase": false,
          "confirmations": 1099,
          "confiscation": false,
          "scriptPubKey": {
            "asm": "0",
            "hex": "00",
            "type": "nonstandard"
          },
          "value": 1e-07
        }
      },
      "funding": {
        "hex": "010000000187416f6e1c94be63770af8f30b05b87dfe8c51ba7253fe475f9fe7a562a952b6000000006a47304402201139b9a0c371bf2fd691dc1189bd4df2e8bc3ca83fd462df2b85bb3ec9a56b6d022016a688cb444228fcbe5b442340055a05cacf39679e7e95e5ac022d1b0ac1aa3b412103786333c3f42e3dc609bc9c5179ba8df99d6d01800f9558ea277688a4dced4bceffffffff010a00000000000000010000000000",
        "txid": "cacd7b87e63fa0220226e88dbba54897014a1187fd4eb042a7a10efd490bb343"
      },
      "transaction": {
        "hex": "020000000143b30b49fd0ea1a742b04efd87114a019748a5bb8de8260222a03fe6877bcdca0000000000ffffffff010900000000000000015100000000",
        "txid": "874197e1b84144bab10a6579ccd572ae0491f43785e5c3b8a9d893691403d5dc"
      }
    }
  },
  "initial_chain": {
    "recipe": "Fund the exact input amount and locking script on the live chain, remap transaction prevouts, and submit at height 1200. Genesis/Chronicle 101/111 preserve the selected script boundary; OP_TRUE value and structural rows do not depend on the original coin era. Fee-stage rows materialize valueIn/valueOut as funded amounts rather than using their inert transaction placeholder. Compare exact block reason or acceptance, fee, output metadata and invalidateblock restoration. [SRC] src/validation.cpp:542-558,625-637,2552-2665,3421-3444 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
    "complete_rpc_history": "docs/records/20261013-045648-s6-66-utx-regtest-s3.json"
  },
  "steps": [
    {
      "id": "submit",
      "action": {
        "type": "submitblock",
        "params": [
          "04000000c47eeb2ceb50b67e9a97286adb7f6016c13e4e3d53cc04b5fd9b92c6799e8934f22d38d5efac7576b2c502620d78d2c282d1663ef0122b18dd8907885483198a00f15365ffff7f20000000000201000000010000000000000000000000000000000000000000000000000000000000000000ffffffff1102b0040d736372697074732f66616c7365ffffffff0100000000000000001976a914f09581d66893f0fddad00184dea48c588317975488ac00000000020000000143b30b49fd0ea1a742b04efd87114a019748a5bb8de8260222a03fe6877bcdca0000000000ffffffff010900000000000000015100000000"
        ]
      },
      "kind": "recorded UTXO boundary",
      "rules": [
        "[SRC] src/rpc/mining.cpp:916-952 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "expected_observations": {
        "reason": "blk-bad-inputs (Script evaluated without error but finished with a false/empty top stack element)",
        "status": "rejected"
      },
      "actual_observations": {
        "reason": "blk-bad-inputs",
        "status": "rejected"
      },
      "label": "[D]",
      "node": "measured agree: rejected blk-bad-inputs (detail not surfaced by submitblock: src/validation.cpp:3690-3715) [X] docs/records/20261013-061601-s6-66-agg-regtest-s3.md"
    }
  ],
  "replay": {
    "record": "docs/records/20261013-045648-s6-66-utx-regtest-s3.md",
    "handler": "[SRC] src/rpc/mining.cpp:916-952 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
  },
  "adjudication": {
    "label": "[X]",
    "ruling": "R6",
    "record": "docs/records/20261013-061601-s6-66-agg-regtest-s3.md",
    "comparison": "status and reason code agree; parenthetical script detail is unobservable via submitblock"
  }
}
```
