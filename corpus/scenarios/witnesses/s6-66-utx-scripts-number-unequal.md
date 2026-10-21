# s6-66-utx-scripts-number-unequal

[X] Classification: observation limit (reason detail) as data. The exact prefix, submitted bytes, expected and actual observations are retained below.

```json
{
  "id": "s6-66-utx-scripts-number-unequal",
  "class": "node observation differs from declared projection",
  "classification": "observation limit (reason detail)",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "input_label": "[D]",
  "witness": {
    "family": "utxo",
    "row": "scripts/number-unequal",
    "receipt": "docs/records/20261013-045648-s6-66-utx-regtest-s3.json",
    "fixtures": {
      "conf": "# #66 isolated regtest profile; bitcoin-sv pin\n# 6504a3aff65ba97c0f6c80962b033e35ecbfed4b [SRC].\n# Regtest and txindex: src/chainparams.cpp:1457-1523; src/init.cpp:617-620,3797-3800.\nregtest=1\ntxindex=1\n# Server and loopback binding: src/init.cpp:1342-1378; src/httpserver.cpp:220-245.\nserver=1\nrpcbind=127.0.0.1\nrpcallowip=127.0.0.1\n# Isolation: src/init.cpp:711-735,830-837,3688-3689,4120;\n# regtest has empty seeds: src/chainparams.cpp:1520-1523. No addnode/connect.\nlisten=0\ndnsseed=0\ndiscover=0\nupnp=0\n# Expiry witness: src/validation.cpp:853-856; debug category selection src/init.cpp:2288-2304.\n# Logging: src/init.cpp:2042,2288-2304,3507-3510. Console captured in the owned datadir.\ndebug=mempool\nprinttoconsole=1\nshrinkdebugfile=1\n# Required launch inputs: src/bitcoind.cpp:140-164. Size supplied per run.\nmaxstackmemoryusageconsensus=100000000\nminminingtxfee=0.00000500\n# Cookie authentication: src/httprpc.cpp:341-351. No credentials here.\nrpcport=18571\nport=18572\nexcessiveblocksize=1000001\ngenesisactivationheight=101\nchronicleactivationheight=111\n",
      "evidence": {
        "before": {
          "bestblock": "327a2a56e1bf83234f90f1e32c59b1702c4b3e243c76811998c60e2786f62240",
          "coinbase": false,
          "confirmations": 1099,
          "confiscation": false,
          "scriptPubKey": {
            "asm": "2 OP_EQUAL",
            "hex": "5287",
            "type": "nonstandard"
          },
          "value": 1e-07
        }
      },
      "funding": {
        "hex": "010000000187416f6e1c94be63770af8f30b05b87dfe8c51ba7253fe475f9fe7a562a952b6000000006b48304502210090f31d5fb58150d290b499d756d785dc900497d3eca7713e577850806bc2fd760220744da3a3046a9cd2a715578176e17f530bb8c092d141b0dfa192a32d29408f10412103786333c3f42e3dc609bc9c5179ba8df99d6d01800f9558ea277688a4dced4bceffffffff010a0000000000000002528700000000",
        "txid": "ff2b188584aafebda21efea4aca94c2aa06ebe382c70a6d45b74ed607fe1a4a4"
      },
      "transaction": {
        "hex": "0200000001a4a4e17f60ed745bd4a6702c38be6ea02a4ca9aca4fe1ea2bdfeaa8485182bff000000000153ffffffff010900000000000000015100000000",
        "txid": "ccba9470c8a06f3f22125a3da079d8c9ca831c77ae2d7b0217050e1688d200fa"
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
          "040000004022f686270ec6981981763c243e4b2c70b1592ce3f1904f2383bfe1562a7a3283d2f20bbf3a629e05657a38df63c58066a44c16d9cb4ed4648d46623b66dc7400f15365ffff7f20000000000201000000010000000000000000000000000000000000000000000000000000000000000000ffffffff1a02b00416736372697074732f6e756d6265722d756e657175616cffffffff0100000000000000001976a914f09581d66893f0fddad00184dea48c588317975488ac000000000200000001a4a4e17f60ed745bd4a6702c38be6ea02a4ca9aca4fe1ea2bdfeaa8485182bff000000000153ffffffff010900000000000000015100000000"
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
