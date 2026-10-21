#!/usr/bin/env python3
"""tools/test_teranode_gate.py (bsv-script-lean #95; S3, lane gate-95, 2026-10-17): the gate writer's tests.

  python3 tools/test_teranode_gate.py      (or python3 -m unittest tools.test_teranode_gate)

The delta on two synthetic records (a moved class, a new divergence, a resolved one, a moved obligation kind, a moved
pin); a script-column witness keyed stably when its run directory is renamed; the class vocabulary exactly the
obligation list's six kinds; the words the wording rule refuses never emitted; a value's text never printed; the
chunks cover every corpus row once; the dry run on the records on disk writes a page whose counts are its sources' own.

The leg: tools/check.sh's pins leg runs this file (lane fix-gate-95, 2026-10-17; no new leg, the count stays
twenty-nine). The other tools/test_*.py files are run by no leg (docs/LINT.md section 3's dated gaps).
"""
import copy
import json
import os
import re
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import teranode_gate as g  # noqa: E402


def record(divs, kinds=None, tag="v0.16.0", counts=None):
    return {
        "pins": {"reference": {"name": "bitcoin-sv", "tag": "v1.2.3", "commit": "6504a3af" + "0" * 32},
                 "teranode": {"name": "Teranode", "tag": tag, "commit": ("4edb60a4" if tag == "v0.16.0" else "99999999") + "0" * 32}},
        "obligations": {"rows": {r: {"kind": k, "label": "consensus", "rerun": True}
                                 for r, k in (kinds or {"median-time-past": "report", "reorg": "theorem"}).items()}},
        "divergences": [{"key": k, "class": c, "detail": d, "row": r} for k, c, d, r in divs],
        "scenario": {"counts": counts or {"block": {"rows": 95, "agree": 31, "diverge": 1}}},
        "previous": "docs/records/20261017-230000-s8-95-gate-report-s3.json",
    }


class Delta(unittest.TestCase):
    def test_baseline(self):
        self.assertEqual(g.delta(None, record([])), ["no previous gate record under docs/records: this record is the baseline"])

    def test_nothing_moved(self):
        a = record([("scenario:x", "open", "scenario.c", "reorg")])
        self.assertEqual(g.delta(a, copy.deepcopy(a)), ["nothing moved since 20261017-230000-s8-95-gate-report-s3.json"])

    def test_two_records(self):
        prev = record([("scenario:x", "open", "unexplained", "reorg"),
                       ("scenario:gone", "open", "scenario.c", "median-time-past"),
                       ("list:d", "design", "policy, #155", "invalidation")])
        cur = record([("scenario:x", "open", "scenario.invalidateblock.unmined-not-revalidated", "reorg"),
                      ("list:d", "chain-split", "consensus, #155", "invalidation"),
                      ("scenario:new", "open", "unexplained", "median-time-past")],
                     kinds={"median-time-past": "open", "reorg": "theorem"}, tag="v0.17.0",
                     counts={"block": {"rows": 95, "agree": 32, "diverge": 0}})
        lines = g.delta(prev, cur)
        self.assertIn("pin moved: Teranode v0.16.0 (4edb60a4) -> v0.17.0 (99999999)", lines)
        self.assertIn("obligation row moved kind: median-time-past: report -> open", lines)
        self.assertIn("moved class detail: scenario:x: unexplained -> scenario.invalidateblock.unmined-not-revalidated", lines)
        self.assertIn("moved class: list:d: design -> chain-split", lines)
        self.assertTrue(any(x.startswith("new divergence: scenario:new (open;") for x in lines), lines)
        self.assertTrue(any(x.startswith("resolved: scenario:gone (was open;") for x in lines), lines)
        self.assertIn("scenario family block: agree 31 -> 32, diverge 1 -> 0", lines)


class ScriptKey(unittest.TestCase):
    """The same script witness under a renamed run directory: matched, nothing moved."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="gate95-key-")
        self.addCleanup(shutil.rmtree, self.dir)

    def run_at(self, name):
        run = os.path.join(self.dir, name, "seed")
        os.makedirs(run)
        m = os.path.join(run, "chunk-00000.manifest.json")
        corpus = "corpus/seed/manifest.json"
        with open(m, "w", encoding="utf-8") as f:
            json.dump({"corpus": {"name": "seed", "path": corpus, "sha256": g.sha256(corpus)},
                       "counts": {"block": {"entries": 2, "disagreeing": 1}, "mempool": {"entries": 2, "disagreeing": 0}},
                       "artifacts_sha256": {"witnesses.jsonl": "0" * 64}}, f)
        return g.read_script({"seed": (run, [m])}, {})[2]

    def test_renamed_run_directory(self):
        a = self.run_at("20261017-000000-gate")
        b = self.run_at("20261118-000000-gate")
        self.assertEqual([d["key"] for d in a], ["script:seed:chunk-00000.manifest.json"])
        prev = record([(d["key"], d["class"], d["detail"], d["row"]) for d in a])
        cur = record([(d["key"], d["class"], d["detail"], d["row"]) for d in b])
        self.assertEqual(g.delta(prev, cur), ["nothing moved since 20261017-230000-s8-95-gate-report-s3.json"])


class Values(unittest.TestCase):
    def test_codes_only(self):
        v = {"status": "rejected", "reason": "time-too-old", "height": 101, "held": True,
             "message": "the node said something long, with spaces", "pool": ["T", "a b"]}
        self.assertEqual(g.codes_only(v), {"status": "rejected", "reason": "time-too-old", "height": 101, "held": True,
                                           "message": "(text: the step log)", "pool": ["T", "(text: the step log)"]})


class Chunks(unittest.TestCase):
    def test_every_row_once(self):
        whole, wall, cs = g.chunks()
        ids = [i for f in g.SCENARIO_FAMILIES for i in g.corpus_ids()[f]]
        got = [i for _, part in cs for i in part]
        self.assertEqual(sorted(got), sorted(ids))
        self.assertEqual(len(got), len(set(got)))
        self.assertEqual(len(cs), -(-int(wall["value"]) // g.CHUNK_SECONDS))


class Vocabulary(unittest.TestCase):
    def test_kinds_are_the_lists(self):
        obl = g.load(g.OBLIGATIONS)
        self.assertEqual(sorted(g.KINDS), sorted(obl["kinds"]))

    def test_refused_words(self):
        # the refused words spelled in two pieces, so this file carries none of them whole
        for text in ["a conforman" + "t node", "a Bu" + "g in", "the firs" + "t gate", "a nove" + "l check",
                     "x " + chr(0x2014) + " y", "bu" + "gs"]:
            with self.assertRaises(g.Stop, msg=text):
                g.refuse_words(text)
        g.refuse_words("the best chain, a design row, consensus, policy")


class DryRun(unittest.TestCase):
    """The writer on the records on disk, into a scratch directory: nothing under docs/records is written."""

    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.mkdtemp(prefix="gate95-test-")
        cls.addClassCleanup(shutil.rmtree, cls.dir)
        # the scenario column named, so a newer column on disk leaves these tests' expectations where they are
        rc = g.main(["--dry-run", "--out-dir", cls.dir, "--stamp", "20990101-000000", "--previous", "none",
                     "--scenario", "docs/records/20261016-001926-s6-66-cut2-second-oracle-s3.json"])
        assert rc == 0, rc
        with open(os.path.join(cls.dir, "20990101-000000-s8-95-gate-report-s3.md"), encoding="utf-8") as f:
            cls.md = f.read()
        with open(os.path.join(cls.dir, "20990101-000000-s8-95-gate-report-s3.json"), encoding="utf-8") as f:
            cls.data = json.load(f)

    def test_head_says_dry_run(self):
        self.assertIn("**dry run from the records of ", self.md)
        self.assertIn("this page claims no live run", self.md)

    def test_every_class_in_vocabulary(self):
        self.assertTrue(self.data["divergences"])
        for d in self.data["divergences"]:
            self.assertIn(d["class"], g.KINDS, d["key"])
        section = self.md.split("## Every divergence, a witness row", 1)[1].split("\n## ", 1)[0]
        cells = re.findall(r"\| \*\*([a-z-]+)\*\* \|", section)
        self.assertEqual(len(cells), len(self.data["divergences"]))
        self.assertTrue(set(cells) <= set(g.KINDS), cells)

    def test_no_refused_word(self):
        self.assertIsNone(g.REFUSED.search(self.md))
        for w in ["conforman" + "t", "bu" + "g", "firs" + "t"]:
            self.assertNotRegex(self.md.lower(), r"\b" + w + r"\b")

    def test_counts_are_the_sources(self):
        obl = g.load(g.OBLIGATIONS)
        self.assertEqual(self.data["obligations"]["counts"], {k: obl["counts"][k] for k in g.KINDS})
        for path in self.data["scenario"]["records"]:
            own = g.load(path)["counts"]
            for fam, c in self.data["scenario"]["counts"].items():
                for k in ["rows"] + g.VERDICTS:
                    self.assertEqual(c.get(k, 0), own[fam].get(k, 0), (fam, k))
        self.assertEqual(sum(c["rows"] for c in self.data["scenario"]["counts"].values()),
                         sum(len(v) for v in g.corpus_ids().values()))
        self.assertEqual(len([d for d in self.data["divergences"] if d["source"] == "the obligation list"]),
                         len(obl["divergences"]))

    def test_delta_against_itself(self):
        cur = copy.deepcopy(self.data)
        cur["previous"] = "x/20990101-000000-s8-95-gate-report-s3.json"
        self.assertEqual(g.delta(self.data, cur), ["nothing moved since 20990101-000000-s8-95-gate-report-s3.json"])

    def test_rerun_rows_not_measured_named(self):
        head = "Rows marked `rerun` with no judged scenario row and no leg (not re-measured by this gate): "
        line = next(x for x in self.md.splitlines() if x.startswith(head))
        self.assertEqual(sorted(re.findall(r"`([a-z-]+)`", line[len(head):])), ["checkpoints", "coinbase-height", "difficulty"])

    def test_partials_named(self):
        self.assertIn("Newer partial column records not read: `docs/records/20261016-173953-s6-66-cut2-second-oracle-s3.json` "
                      "(2 rows: ", self.md)

    def test_no_message_text(self):
        for d in self.data["divergences"]:
            if d["source"] == "scenario column":
                self.assertNotRegex(d["teranode"] + d["reference"], r"[a-z]+ [a-z]+ [a-z]+\"")


class Previous(unittest.TestCase):
    def test_live_prefers_live(self):
        d = tempfile.mkdtemp(prefix="gate95-prev-")
        self.addCleanup(shutil.rmtree, d)
        for stamp, mode in (("20261001-000000", "live"), ("20261002-000000", "dry-run")):
            with open(os.path.join(d, stamp + g.GATE_SUFFIX + ".json"), "w", encoding="utf-8") as f:
                json.dump({"mode": mode}, f)
        old = g.RECORDS
        g.RECORDS = d
        try:
            p, mode, note = g.previous_record("20261003-000000", None, live=True)
            self.assertEqual((os.path.basename(p), mode, note), ("20261001-000000" + g.GATE_SUFFIX + ".json", "live", ""))
            p, mode, _ = g.previous_record("20261003-000000", None, live=False)
            self.assertEqual(mode, "dry-run")
            os.remove(os.path.join(d, "20261001-000000" + g.GATE_SUFFIX + ".json"))
            p, mode, note = g.previous_record("20261003-000000", None, live=True)
            self.assertEqual(mode, "dry-run")
            self.assertIn("no live gate record", note)
        finally:
            g.RECORDS = old


if __name__ == "__main__":
    unittest.main(verbosity=1)
