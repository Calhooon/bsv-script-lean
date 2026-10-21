# Fee-ceiling observation limit: absurd-fee-equality

[X] The selected pinned build accepted the real fee-paying frame while the requested ceiling was in its conf. The live wallet probe and the pinned initialization guard show why the numeric boundary was not reached. This corrects the earlier comparator classification; it is not a validation divergence. The full prefix and exact RPCs are in the lane receipt.

```json
{
  "id": "s6-66-mem-absurd-fee-equality",
  "class": "observation limit (unavailable fee-ceiling selector)",
  "classification": "observation-limit",
  "source_pin": "6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
  "input_label": "[D]",
  "witness": {
    "family": "mempool",
    "row": "absurd-fee-equality",
    "receipt": "docs/records/20261013-045854-s6-66-mem-regtest-s3.json",
    "fixtures": {
      "conf": "# #66 isolated regtest profile; bitcoin-sv pin\n# 6504a3aff65ba97c0f6c80962b033e35ecbfed4b [SRC].\n# Regtest and txindex: src/chainparams.cpp:1457-1523; src/init.cpp:617-620,3797-3800.\nregtest=1\ntxindex=1\n# Server and loopback binding: src/init.cpp:1342-1378; src/httpserver.cpp:220-245.\nserver=1\nrpcbind=127.0.0.1\nrpcallowip=127.0.0.1\n# Isolation: src/init.cpp:711-735,830-837,3688-3689,4120;\n# regtest has empty seeds: src/chainparams.cpp:1520-1523. No addnode/connect.\nlisten=0\ndnsseed=0\ndiscover=0\nupnp=0\n# Expiry witness: src/validation.cpp:853-856; debug category selection src/init.cpp:2288-2304.\n# Logging: src/init.cpp:2042,2288-2304,3507-3510. Console captured in the owned datadir.\ndebug=mempool\nprinttoconsole=1\nshrinkdebugfile=1\n# Required launch inputs: src/bitcoind.cpp:140-164. Size supplied per run.\nmaxstackmemoryusageconsensus=100000000\nminminingtxfee=0.00000500\n# Cookie authentication: src/httprpc.cpp:341-351. No credentials here.\nrpcport=18571\nport=18572\nexcessiveblocksize=1000001\ngenesisactivationheight=1\nchronicleactivationheight=1000000\nacceptnonstdtxn=0\nacceptnonstdoutputs=1\nmaxtxfee=0.00000100\n",
      "funding": {
        "hex": "010000000187416f6e1c94be63770af8f30b05b87dfe8c51ba7253fe475f9fe7a562a952b6000000006b483045022100888047c76cd79781705699d9bd66068a59088003c97585170b1d0cdd8a6d40130220029a33770202fcf5dd571cf5e04ed532c504fb421ac869a072c9055249f0e9da412103786333c3f42e3dc609bc9c5179ba8df99d6d01800f9558ea277688a4dced4bceffffffff01e803000000000000015100000000",
        "txid": "a6b26d73a1a3c7adbf4ce9aa64de7632a6de581654564a998ce6de809461aea4"
      },
      "transaction": {
        "hex": "0200000001a4ae619480dee68c994a56541658dea63276de64aae94cbfadc7a3a1736db2a60000000000ffffffff018403000000000000015100000000",
        "txid": "bff0a9acc4c6fbe6b1eaa67ac5363f31aa80ad94ea185b0f34d532032077fd26"
      }
    }
  },
  "initial_chain": {
    "recipe": "Mine and fund a real 1000-satoshi OP_TRUE output at height 101; reach tip 200 with Genesis 1. The exact conf requests the corpus fee ceiling. No peer is used.",
    "complete_rpc_history": "docs/records/20261013-045854-s6-66-mem-regtest-s3.json",
    "run_id": "s6-66-mem-fee-20261013-052857"
  },
  "steps": [
    {
      "id": "submit",
      "action": {
        "type": "sendrawtransaction",
        "params": [
          "0200000001a4ae619480dee68c994a56541658dea63276de64aae94cbfadc7a3a1736db2a60000000000ffffffff018403000000000000015100000000"
        ]
      },
      "kind": "recorded configured-limit probe",
      "rules": [
        "[SRC] src/rpc/rawtransaction.cpp:1530-1672 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
        "[SRC] src/init.cpp:3190-3192; src/wallet/wallet.cpp:4406-4425 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
      ],
      "label": "[D]",
      "expected_observations": {
        "status": "accepted",
        "stage": "commit",
        "trace": [
          "regular",
          "standard",
          "finality",
          "alreadyKnown",
          "conflict",
          "inputs",
          "sequence",
          "inputStandard",
          "sigops",
          "fee",
          "ancestors",
          "scripts",
          "detector",
          "commit"
        ]
      },
      "actual_observations": {
        "accepted": [
          "bff0a9acc4c6fbe6b1eaa67ac5363f31aa80ad94ea185b0f34d532032077fd26"
        ],
        "held": [],
        "orphans": {
          "size": 0
        },
        "submission": {
          "result": "bff0a9acc4c6fbe6b1eaa67ac5363f31aa80ad94ea185b0f34d532032077fd26"
        },
        "wallet_probe": {
          "error": {
            "code": -32601,
            "message": "Method not found"
          }
        }
      },
      "status_basis": "The returned txid and settled accepted membership are measured. The configured numeric limit was not active, so they do not judge the corpus boundary. The wallet probe returns -32601 Method not found.",
      "node": "unrealizable: the selected pinned build lacks the wallet RPC registration and ignores the requested maxtxfee ceiling; loading that selector is guarded by ENABLE_WALLET (src/init.cpp:3190-3192; src/wallet/wallet.cpp:4406-4425), while RPC consumes the unchanged global maxTxFee (src/rpc/rawtransaction.cpp:1571-1574). The configured-limit boundary was not reached [X] docs/records/20261013-045854-s6-66-mem-regtest-s3.md"
    }
  ],
  "replay": {
    "record": "docs/records/20261013-045854-s6-66-mem-regtest-s3.md",
    "rpc_handler": "[SRC] src/rpc/rawtransaction.cpp:1530-1672 at 6504a3aff65ba97c0f6c80962b033e35ecbfed4b",
    "classification_reason": "the selected pinned build lacks the wallet RPC registration and ignores the requested maxtxfee ceiling; loading that selector is guarded by ENABLE_WALLET (src/init.cpp:3190-3192; src/wallet/wallet.cpp:4406-4425), while RPC consumes the unchanged global maxTxFee (src/rpc/rawtransaction.cpp:1571-1574). The configured-limit boundary was not reached"
  }
}
```
