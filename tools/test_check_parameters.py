#!/usr/bin/env python3
"""Mutation tests for the census gate; only isolated copies are changed."""
from pathlib import Path
import shutil
import tempfile
import unittest

import check_parameters as census

ROOT = Path(__file__).resolve().parent.parent


class CensusGate(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bsv-census-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for file in ["docs/PARAMETERS.md", "docs/PROVENANCE.md", "lean/lakefile.toml",
                     "lean/BsvScript.lean", "lean/BsvChain.lean"]:
            target = self.root / file
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / file, target)
        for directory in ["lean/BsvScript", "lean/BsvChain"]:
            shutil.copytree(ROOT / directory, self.root / directory)

    def edit(self, path, old, new):
        path = self.root / path
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new, 1))

    def rejects(self, pattern):
        with self.assertRaisesRegex(census.Drift, pattern):
            census.check(self.root)

    def test_agreement(self):
        self.assertIn("check-parameters: GREEN", census.check(self.root))

    def test_document_default(self):
        self.edit("docs/PARAMETERS.md", "| `limitAncestorCount` | policy | `10000`",
                  "| `limitAncestorCount` | policy | `9999`")
        self.rejects("limitAncestorCount: default mismatch")

    def test_document_kind(self):
        self.edit("docs/PARAMETERS.md", "| `limitAncestorCount` | policy |",
                  "| `limitAncestorCount` | consensus |")
        self.rejects("limitAncestorCount: kind mismatch")

    def test_document_presence(self):
        self.edit("docs/PARAMETERS.md", "`10000` · **optional** · transactions",
                  "`10000` · **mandatory** · transactions")
        self.rejects("limitAncestorCount: presence mismatch")

    def test_inherited_mandatory_presence(self):
        self.edit("docs/PARAMETERS.md",
                  "`9223372036854775807` · **mandatory**.",
                  "`9223372036854775807` · **optional**.")
        self.rejects("maxStackMemoryUsageConsensus: presence mismatch")

    def test_inherited_optional_presence(self):
        self.edit("docs/PARAMETERS.md", "`ChainParams.mainnet` · **optional**.",
                  "`ChainParams.mainnet` · **mandatory**.")
        self.rejects("BsvScript.chain: presence mismatch")

    def test_conflicting_presence_words(self):
        self.edit("docs/PARAMETERS.md", "`10000` · **optional** · transactions",
                  "`10000` · **optional** **mandatory** · transactions")
        self.rejects("limitAncestorCount: expected exactly one presence word")

    def test_duplicate_inherited_presence(self):
        self.edit("docs/PARAMETERS.md", "`ChainParams.mainnet` · **optional**.",
                  "`ChainParams.mainnet` · **optional** optional.")
        self.rejects("BsvScript.chain: expected exactly one presence word")

    def test_missing_presence_word(self):
        self.edit("docs/PARAMETERS.md", "`10000` · **optional** · transactions",
                  "`10000` · transactions")
        self.rejects("limitAncestorCount: expected exactly one presence word")

    def test_record_default(self):
        self.edit("lean/BsvChain/Params.lean", "limitAncestorCount : Nat := 10000",
                  "limitAncestorCount : Nat := 9999")
        self.rejects("limitAncestorCount: default mismatch")

    def test_record_doc_default(self):
        self.edit("lean/BsvChain/Params.lean", "Default: `10000`", "Default: `9999`")
        self.rejects("limitAncestorCount: default mismatch")

    def test_field_names_and_order(self):
        self.edit("docs/PARAMETERS.md", "| `maxMempool` |", "| `unlistedField` |")
        self.rejects("field names/order differ")

    def test_missing_field_doc(self):
        self.edit("lean/BsvChain/Params.lean", "  limitAncestorCount : Nat := 10000",
                  "  undocumented : Nat := 1\n  limitAncestorCount : Nat := 10000")
        self.rejects("field names/order differ")

    def test_inherited_default(self):
        self.edit("lean/BsvScript/Params.lean", "maxTxSizePolicy := 10000000",
                  "maxTxSizePolicy := 10000001")
        self.rejects("maxTxSizePolicy: reference default differs")

    def test_second_oracle_default(self):
        self.edit("lean/BsvScript/Params.lean", "maxTxSizePolicy := 10485760",
                  "maxTxSizePolicy := 10485761")
        self.rejects("maxTxSizePolicy: second-oracle default differs")

    def test_reverse_import(self):
        path = self.root / "lean/BsvScript.lean"
        path.write_text("public import BsvScript.Params\n  BsvChain.Params\n" + path.read_text())
        self.rejects("library boundary")

    def test_transitive_reverse_import(self):
        path = self.root / "lean/BsvScript.lean"
        path.write_text("import CensusBridge\n" + path.read_text())
        (self.root / "lean/CensusBridge.lean").write_text("import BsvChain\n")
        self.rejects("library boundary")

    def test_escaped_and_list_reverse_imports(self):
        path = self.root / "lean/BsvScript.lean"
        original = path.read_text()
        for header in [
            "import «BsvChain»",
            "import «BsvChain».Params",
            "import BsvChain.«Params»",
            "import «BsvChain».«Params»",
            "import BsvScript.Params BsvChain.X",
            "import «A B» «BsvChain»",
            "public meta import all «BsvChain»",
            "import /- nested /- import Hidden -/ comment -/ «BsvChain»",
            "import BsvScript.Params\n-- comment\n«BsvChain».X",
            "import A' «BsvChain»",
            "import BsvChain.",
            "import «BsvChain/Params»",
        ]:
            with self.subTest(header=header):
                path.write_text(header + "\n" + original)
                self.rejects("library boundary")

    def test_escaped_transitive_reverse_import(self):
        path = self.root / "lean/BsvScript.lean"
        path.write_text('import «Bridge -- quoted»\n' + path.read_text())
        (self.root / 'lean/Bridge -- quoted.lean').write_text('import «BsvChain».Params\n')
        self.rejects("library boundary")

    def test_escaped_identifier_is_not_import_command(self):
        self.assertEqual(census.imports('def «import» := "import BsvChain"'), [])
        self.assertEqual(census.imports('import «Bridge /- quoted -/»'), [('Bridge /- quoted -/',)])

    def test_dot_inside_escaped_bridge_name(self):
        path = self.root / "lean/BsvScript.lean"
        path.write_text('import «Bridge.WithDot»\n' + path.read_text())
        (self.root / 'lean/Bridge.WithDot.lean').write_text('import «BsvChain»\n')
        self.rejects("library boundary")

    def test_commented_import(self):
        path = self.root / "lean/BsvScript.lean"
        path.write_text('/- import BsvChain /- nested -/ -/\n-- import BsvChain.Params\n' + path.read_text())
        self.assertIn("GREEN", census.check(self.root))

    def test_library_root(self):
        self.edit("lean/lakefile.toml", 'roots = ["BsvChain"]', 'roots = ["WrongRoot"]')
        self.rejects("Lake must declare")

    def test_network_census_value(self):
        self.edit("docs/PARAMETERS.md", "`some 1351` [SRC]", "`some 1352` [SRC]")
        self.rejects("ChainParams.regtest.bip65Height: value mismatch")

    def test_network_source_omission(self):
        self.edit("docs/PARAMETERS.md", "`none` [SRC] `src/chainparams.cpp:1195–1304`",
                  "`some 0` [SRC] `src/chainparams.cpp:1195–1304`")
        self.rejects("ChainParams.stn.bip65Height: value mismatch")

    def test_network_record_value(self):
        self.edit("lean/BsvChain/Params.lean", "bip34Height := 227931", "bip34Height := 227932")
        self.rejects("ChainParams.mainnet.bip34Height: value mismatch")

    def test_network_missing(self):
        self.edit("lean/BsvChain/Params.lean", "def ChainParams.testnet :", "def ChainParams.renamed :")
        self.rejects("ChainParams: network names/order differ")

    def test_network_presence(self):
        self.edit("docs/PARAMETERS.md", "**optional**. [SRC] `src/consensus/params.h:20–21`",
                  "**optional** mandatory. [SRC] `src/consensus/params.h:20–21`")
        self.rejects("ChainParams.bip34Height: expected exactly one presence word")

    def test_network_missing_citation(self):
        self.edit("docs/PARAMETERS.md", "`227931` [SRC] `src/chainparams.cpp:1038`",
                  "`227931` `src/chainparams.cpp:1038`")
        self.rejects("ChainParams.mainnet.bip34Height: initialization citation missing")

    def test_domain_axiom(self):
        path = self.root / "lean/BsvChain/Params.lean"
        path.write_text(path.read_text() + "\naxiom inadmissible : False\n")
        self.rejects("domain axiom")


if __name__ == "__main__":
    unittest.main()
