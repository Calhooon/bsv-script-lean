"""A replacement run must preserve receipts and cannot hide missing spends."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import conformance


class InstanceReplacementTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.context = patch.object(conformance, "ROOT", str(self.root))
        self.context.start()
        self.addCleanup(self.context.stop)
        self.old = conformance.INSTANCE_RUNS + "/dated/gen/chunk-00000.manifest.json"
        self.new = "corpus/instances/teranode/gen/chunk-00000.manifest.json"
        self.receipt = {
            "corpus": {"path": "corpus/gen/gen.jsonl", "manifest_count": 2, "run_from": 0, "run_count": 2},
            "counts": {p: {"entries": 2, "agreeing": 2, "disagreeing": 0, "undecided": 0, "unfundable": 0, "no_reference": 0} for p in ("block", "mempool")},
            "instance": {"tag": "v0.16.0", "commit": "fixture", "binary_sha256": "binary", "native_client_sha256": "client", "host": "box", "settings_hash": "settings", "settings": {}},
            "paths": {"block": "validator call", "mempool": "RPC submission"},
            "mapping": {"regtest": {"genesis": 100, "chronicle": 200, "coinbase_maturity": 100}, "basis": "fixture"},
            "initial_tip": {"blocks": 200}, "final_tip": {"blocks": 201},
            "undecided": [], "unfundable": [],
        }
        self.write(self.old, self.receipt)
        self.original = (self.root / self.old).read_bytes()
        self.replacement = copy.deepcopy(self.receipt)
        self.replacement["corpus"].update(manifest_count=3, run_count=3)
        for counts in self.replacement["counts"].values():
            counts.update(entries=3, agreeing=3)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value) + "\n")

    def index(self):
        self.write(self.new, self.replacement)
        self.write(conformance.INSTANCE_REPLACEMENTS, {
            "record": "docs/records/dated-measurement.md",
            "replacements": {self.old: {
                "file": self.new,
                "superseded_sha256": hashlib.sha256(self.original).hexdigest(),
                "sha256": hashlib.sha256((self.root / self.new).read_bytes()).hexdigest(),
            }},
        })

    def test_existing_runs_need_no_index(self):
        refusals = []
        files, record = conformance.instance_manifest_files(refusals)
        self.assertEqual(files, [str(self.root / self.old)])
        self.assertIsNone(record)
        self.assertEqual(refusals, [])

    def test_report_uses_complete_replacement_and_preserves_other_runs(self):
        flow = copy.deepcopy(self.receipt)
        flow["corpus"]["path"] = "corpus/flow/cases.jsonl"
        self.write(conformance.INSTANCE_RUNS + "/dated/flow/chunk-00000.manifest.json", flow)
        self.index()
        refusals = []
        report = "\n".join(conformance.instance_section(refusals))
        self.assertEqual(refusals, [])
        self.assertIn("| `corpus/gen` | 3 |", report)
        self.assertIn("| `block` | 3 | 0 | 0 | 0 |", report)
        self.assertIn("| `corpus/flow` | 2 |", report)
        self.assertIn("dated-measurement.md", report)
        self.assertEqual((self.root / self.old).read_bytes(), self.original)

    def test_changed_replacement_receipt_is_refused(self):
        self.index()
        self.replacement["counts"]["block"]["agreeing"] = 0
        self.write(self.new, self.replacement)
        refusals = []
        self.assertEqual(conformance.instance_section(refusals), [])
        self.assertIn("sha256", " ".join(refusals))

    def test_changed_superseded_receipt_is_refused(self):
        self.index()
        self.receipt["counts"]["block"]["agreeing"] = 0
        self.write(self.old, self.receipt)
        refusals = []
        self.assertEqual(conformance.instance_section(refusals), [])
        self.assertIn("sha256", " ".join(refusals))

    def test_another_corpus_is_refused(self):
        self.replacement["corpus"]["path"] = "corpus/flow/cases.jsonl"
        self.index()
        refusals = []
        self.assertEqual(conformance.instance_section(refusals), [])
        self.assertIn("another corpus", " ".join(refusals))

    def test_a_run_missing_an_entry_is_refused(self):
        self.replacement["corpus"].update(run_from=1, run_count=2)
        self.index()
        refusals = []
        conformance.instance_section(refusals)
        self.assertIn("gap or overlap", " ".join(refusals))


if __name__ == "__main__":
    unittest.main()
