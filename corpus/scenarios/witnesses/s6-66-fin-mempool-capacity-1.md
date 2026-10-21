# s6-66-fin-mempool-capacity-1

[X] Row "mempool/capacity-1". Classification is scope limit as data. The live prefix, submitted bytes and exact RPC envelope are retained in the lane receipt.

```json
{
  "class": "stage projection and live RPC observation differ",
  "classification": "scope limit",
  "id": "s6-66-fin-mempool-capacity-1",
  "initial_chain": {
    "complete_rpc_history": "docs/records/20261013-045710-s6-66-fin-regtest-s3.json",
    "recipe": "Funded distinct OP_TRUE inputs retain version and all sequence words. Heights and height locks shift equally to live candidate 201 for tip/admission or 601 for absolute predicates. Block rows map their CSV activation to native height 576, preserving the exact offset: candidate 575 before CSV, 576 at CSV, and 581 at Genesis; time locks and cutoffs shift equally by 1200000000, retaining timestamp type and signed-positive range. Irrelevant alternate cutoff is replaced by a reachable value. The parent median is witnessed at the translated cutoff; own block time is used before CSV. Genesis/Chronicle relative candidate branches and the exact capacity in bytes are retained. For the explicit tip flag-3 row Genesis is placed at the candidate so the predecessor caller supplies word 3 while candidate-era holding stays active. Tip rejection compares status/reason because admission remaps its internal code. [SRC] src/validation.cpp:227-247,1093-1124,5977-6074; src/chainparams.cpp:1470; src/time_locked_mempool.cpp:400; src/util.cpp:311-380 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b.",
    "row": "mempool/capacity-1"
  },
  "input_label": "[D]",
  "replay": {
    "record": "docs/records/20261013-045710-s6-66-fin-regtest-s3.md",
    "rpc_handler": "[SRC] src/rpc/rawtransaction.cpp:1530-1672 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
  },
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "steps": [
    {
      "action": {
        "params": [
          "0200000001a189b35084531a7deb71cce5d801d057907d03116d26e779b8dc0e2525c0eab50000000000000000000128230000000000000151c9000000"
        ],
        "type": "sendrawtransaction"
      },
      "actual_observations": {
        "code": 259,
        "namespace": "node",
        "reason": "non-final-pool-full",
        "status": "rejected"
      },
      "expected_observations": {
        "status": "heldNonFinal"
      },
      "id": "submit",
      "kind": "recorded node observation",
      "label": "[D]",
      "node": "measured agree: rejected 259 non-final-pool-full (scope: full admission; the isolated stage says heldNonFinal) [X] docs/records/20261013-061601-s6-66-agg-regtest-s3.md",
      "rules": [
        "[SRC] src/rpc/rawtransaction.cpp:1530-1672 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ]
    }
  ],
  "witness": {
    "family": "finality",
    "fixtures": {
      "conf": "# #66 isolated regtest profile; bitcoin-sv pin\n# 6504a3aff65ba97c0f6c80962b033e35ecbfed4b [SRC].\n# Regtest and txindex: src/chainparams.cpp:1457-1523; src/init.cpp:617-620,3797-3800.\nregtest=1\ntxindex=1\n# Server and loopback binding: src/init.cpp:1342-1378; src/httpserver.cpp:220-245.\nserver=1\nrpcbind=127.0.0.1\nrpcallowip=127.0.0.1\n# Isolation: src/init.cpp:711-735,830-837,3688-3689,4120;\n# regtest has empty seeds: src/chainparams.cpp:1520-1523. No addnode/connect.\nlisten=0\ndnsseed=0\ndiscover=0\nupnp=0\n# Expiry witness: src/validation.cpp:853-856; debug category selection src/init.cpp:2288-2304.\n# Logging: src/init.cpp:2042,2288-2304,3507-3510. Console captured in the owned datadir.\ndebug=mempool\nprinttoconsole=1\nshrinkdebugfile=1\n# Required launch inputs: src/bitcoind.cpp:140-164. Size supplied per run.\nmaxstackmemoryusageconsensus=100000000\nminminingtxfee=0.00000500\n# Cookie authentication: src/httprpc.cpp:341-351. No credentials here.\nrpcport=18571\nport=18572\nexcessiveblocksize=1000001\ngenesisactivationheight=200\nchronicleactivationheight=210\nmaxmempoolnonfinal=1B\n",
      "funding": [
        {
          "hex": "010000000187416f6e1c94be63770af8f30b05b87dfe8c51ba7253fe475f9fe7a562a952b6000000006b483045022100e9366c7733fb8cbcb9aee665906189e4b6532f9d38de7257fa1ea8d49b80a95302202eaf346d3a0a012025150419a3db407be1a156202ab4d9ed6cfa26808f94dc53412103786333c3f42e3dc609bc9c5179ba8df99d6d01800f9558ea277688a4dced4bceffffffff011027000000000000015100000000",
          "txid": "b5eac025250edcb879e7266d11037d9057d001d8e5cc71eb7d1a538450b389a1"
        }
      ],
      "height_delta": 190,
      "live_lock": 201,
      "time_offset": 1200000000,
      "tip": {
        "bits": "207fffff",
        "chainwork": "0000000000000000000000000000000000000000000000000000000000000192",
        "confirmations": 1,
        "difficulty": 4.6565423739069247e-10,
        "hash": "39e2761b8333fc59a73c65033b55576b7fa3c40c71344f843d87f27c06e233c8",
        "height": 200,
        "mediantime": 1700000000,
        "merkleroot": "a070ad9e7f15e858270010c0a61050f3833b6720e8e3c2db267cf4ab670437a5",
        "nonce": 2,
        "num_tx": 1,
        "previousblockhash": "0a982e222b7297bc72f68c53b92105e9beade2ab3d633bee27c02c5bcc837176",
        "size": 171,
        "status": {
          "data": true,
          "disk meta": true,
          "double spend": false,
          "failed": false,
          "parent failed": false,
          "soft consensus frozen": false,
          "soft reject": false,
          "undo": true,
          "validity": "scripts"
        },
        "time": 1700000005,
        "tx": [
          "a070ad9e7f15e858270010c0a61050f3833b6720e8e3c2db267cf4ab670437a5"
        ],
        "version": 536870912,
        "versionHex": "20000000"
      },
      "transaction": {
        "hex": "0200000001a189b35084531a7deb71cce5d801d057907d03116d26e779b8dc0e2525c0eab50000000000000000000128230000000000000151c9000000",
        "txid": "fbd29e48292c6adf1cd837d8692333e9a6a46f863a95ae83f89418170807131b"
      }
    },
    "receipt": "docs/records/20261013-045710-s6-66-fin-regtest-s3.json",
    "row": "mempool/capacity-1"
  },
  "adjudication": {
    "label": "[X]",
    "ruling": "R7",
    "record": "docs/records/20261013-061601-s6-66-agg-regtest-s3.md",
    "machine": {
      "status": "rejected",
      "code": 259,
      "reason": "non-final-pool-full",
      "stage": "commit"
    },
    "comparison": "full admission agrees; isolated finality stage remains heldNonFinal"
  }
}
```
