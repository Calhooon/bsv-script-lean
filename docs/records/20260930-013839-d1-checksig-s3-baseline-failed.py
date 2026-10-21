#!/usr/bin/env python3
"""Read-only CHECKSIG measurements against the spec's private regtest RPC.

Inputs are synthetic spending fixtures. This script makes no chain-state change
and reports only verdicts, words and source identities. The legacy signature is
used because the pinned VerifyScript forces STRICTENC when FORKID is enabled.
"""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

PAYLOAD = {'source_entry': 'crypto-00008', 'source_file_sha256': '62c1c3ac4ecd4269a074d2f5166599296d30d4f3a6f334c47c5fce114e3f06c5', 'original_vector_sha256': 'bc9f8cda4203710c1ab97ad129eecdd36459c30efec33d925e2848cd7eb50be9', 'same_signature': False, 'word': 3932160, 'txo': {'lock': '21035935f55855afd8c999bdb5a8d08ae8e73b7618e200d4ef7687cd55d3c2e4c9d7ac', 'value': 1000, 'height': 967896}, 'cases': [{'name': 'baseline', 'tx': '0200000001baeba0148843c1b1b7c803d629df3c65b8752c048305599a54e93574af35a60000000000484730440220038bff76a822ee09543ef627fb590a78e293699e00221c558f578d1c2ad3f96d02201bc6488182ca0ff7de0fac5c87f43eabefae5568d128567dc78a0958d534d86f01ffffffff010100000000000000015100000000', 'signature_bytes': 71, 'expected': 'ok'}, {'name': 'sequence-length-88', 'tx': '0200000001baeba0148843c1b1b7c803d629df3c65b8752c048305599a54e93574af35a60000000000514c4f308801010101010101010220038bff76a822ee09543ef627fb590a78e293699e00221c558f578d1c2ad3f96d02201bc6488182ca0ff7de0fac5c87f43eabefae5568d128567dc78a0958d534d86f01ffffffff010100000000000000015100000000', 'signature_bytes': 79, 'expected': 'ok'}, {'name': 'sequence-length-87', 'tx': '0200000001baeba0148843c1b1b7c803d629df3c65b8752c048305599a54e93574af35a60000000000504c4e3087010101010101010220038bff76a822ee09543ef627fb590a78e293699e00221c558f578d1c2ad3f96d02201bc6488182ca0ff7de0fac5c87f43eabefae5568d128567dc78a0958d534d86f01ffffffff010100000000000000015100000000', 'signature_bytes': 78, 'expected': 'ok'}, {'name': 'length-of-length-over-remaining', 'tx': '0200000001baeba0148843c1b1b7c803d629df3c65b8752c048305599a54e93574af35a60000000000484730ff0220038bff76a822ee09543ef627fb590a78e293699e00221c558f578d1c2ad3f96d02201bc6488182ca0ff7de0fac5c87f43eabefae5568d128567dc78a0958d534d86f01ffffffff010100000000000000015100000000', 'signature_bytes': 71, 'expected': 'error'}]}


def rpc(method, *params):
    command = [str(Path.home() / "bsv/oracle/bin/bitcoin-cli"), "-regtest",
               "-conf=" + str(Path.home() / "bsv/spec-oracle/bitcoin.conf"),
               "-datadir=" + str(Path.home() / "bsv/spec-oracle/data"),
               "-rpcport=18563", "-stdin", method]
    body = "".join(json.dumps(value, separators=(",", ":")) + "\n" for value in params)
    started = time.monotonic()
    result = subprocess.run(command, input=body, text=True, capture_output=True, timeout=75)
    if result.returncode:
        raise RuntimeError("private node RPC failed: " + method + "; exit " + str(result.returncode))
    return json.loads(result.stdout), time.monotonic() - started


def run():
    chain, _ = rpc("getblockchaininfo")
    network, _ = rpc("getnetworkinfo")
    assert chain["chain"] == "regtest", "spec instance is not regtest"
    assert network["connections"] == 0, "spec instance has a peer"
    version = subprocess.run([str(Path.home() / "bsv/oracle/bin/bitcoind"), "-version"],
                             text=True, capture_output=True, timeout=10)
    assert version.returncode == 0 and "v1.2.2.0-g879fc8b42" in version.stdout
    result = {"timestamp [M]": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "model [LIT]": "Codex GPT-6.1-Sol", "reference_pin [SRC]": "879fc8b42",
              "binary_version [X]": version.stdout.splitlines()[0],
              "chain [X]": chain["chain"], "peers [X]": network["connections"],
              "source_entry [LIT]": PAYLOAD["source_entry"],
              "source_file_sha256 [D]": PAYLOAD["source_file_sha256"],
              "original_vector_sha256 [D]": PAYLOAD["original_vector_sha256"],
              "same_signature_as_digest_only_vector [D]": PAYLOAD["same_signature"],
              "requested_word [LIT]": PAYLOAD["word"],
              "encoding_flags_mask [LIT]": 14, "cases [X]": []}
    for item in PAYLOAD["cases"]:
        query = [{"tx": item["tx"], "n": 0, "flags": PAYLOAD["word"],
                  "reportflags": True, "txo": PAYLOAD["txo"]}]
        reply, wall = rpc("verifyscript", query, False, 60000)
        assert isinstance(reply, list) and len(reply) == 1
        measured = reply[0]
        assert measured["flags"] & 14 == 0, "node reports an unwanted encoding flag"
        result["cases [X]"].append({"case [LIT]": item["name"],
                                    "signature_bytes [D]": item["signature_bytes"],
                                    "expected [LIT]": item["expected"],
                                    "result [X]": measured["result"],
                                    "description [X]": measured.get("description", ""),
                                    "applied_word [X]": measured["flags"],
                                    "wall_seconds [M]": round(wall, 6)})
    result["expected_results_agree [D]"] = all(
        case["result [X]"] == case["expected [LIT]"] for case in result["cases [X]"])
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    run()
