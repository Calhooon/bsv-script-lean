"""[X] 2026-10-17 S3 (#148's second lens, item A): the column's manifest merge on a pin move keeps a generator-owned
tally as committed and takes the runner's `verdicts` and `provenance` everywhere else."""
import json
import os
import subprocess
import tempfile
import unittest

from tools import column


def committed_manifest(verdicts, provenance):
    return {"file": "c.jsonl", "sha256": "aa" * 32, "count": 16, "verdicts": verdicts, "provenance": provenance,
            "implementations": [{"name": "bsv-rs", "version": "0.5.0"}, {"name": "go-sdk", "version": "1.2.0"}]}


def runner_stamp(base):
    now = json.loads(json.dumps(base))
    now.update({"sha256": "bb" * 32, "count": 17, "verdicts": {"valid": 10, "invalid": 7},
                "provenance": base["provenance"].replace("0.5.0", "0.7.0")})
    now["implementations"] = [{"name": "bsv-rs", "version": "0.7.0"}, {"name": "go-sdk", "version": "9.9.9"}]
    return now


class RestoreOtherRowsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.saved_root = column.ROOT
        column.ROOT = self.root
        subprocess.run(["git", "init", "-q", self.root], check=True)
        self.base = {}
        for corpus, verdicts in (("xsig-144", {"valid": 7, "invalid": 9}), ("gen", {"valid": 12, "invalid": 4})):
            os.makedirs(os.path.join(self.root, "corpus", corpus))
            self.base[corpus] = committed_manifest(verdicts, "cases with bsv-rs 0.5.0's verdicts")
            self.write(corpus, self.base[corpus])
        subprocess.run(["git", "-C", self.root, "add", "corpus"], check=True)
        subprocess.run(["git", "-C", self.root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base"],
                       check=True)

    def tearDown(self):
        column.ROOT = self.saved_root
        self.tmp.cleanup()

    def path(self, corpus):
        return os.path.join(self.root, "corpus", corpus, "manifest.json")

    def write(self, corpus, man):
        with open(self.path(corpus), "w", encoding="utf-8") as f:
            f.write(json.dumps(man, indent=2) + "\n")

    def merged(self, corpus):
        self.write(corpus, runner_stamp(self.base[corpus]))
        column.restore_other_rows(self.path(corpus), ["bsv-rs"])
        return json.load(open(self.path(corpus)))

    def test_generator_owned_tally_kept_as_committed(self):
        m = self.merged("xsig-144")
        self.assertEqual(m["verdicts"], {"valid": 7, "invalid": 9})
        self.assertEqual(m["provenance"], "cases with bsv-rs 0.5.0's verdicts")
        self.assertEqual((m["sha256"], m["count"]), ("bb" * 32, 17))
        self.assertEqual([r["version"] for r in m["implementations"]], ["0.7.0", "1.2.0"])

    def test_runner_owned_tally_taken_from_the_run(self):
        m = self.merged("gen")
        self.assertEqual(m["verdicts"], {"valid": 10, "invalid": 7})
        self.assertEqual(m["provenance"], "cases with bsv-rs 0.7.0's verdicts")
        self.assertEqual((m["sha256"], m["count"]), ("bb" * 32, 17))
        self.assertEqual([r["version"] for r in m["implementations"]], ["0.7.0", "1.2.0"])


if __name__ == "__main__":
    unittest.main()
