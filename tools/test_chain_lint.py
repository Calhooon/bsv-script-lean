"""[M] 2026-10-13: disposable fixtures for the #77 lint (the parameter half's added 2026-10-14, lane fix-77).
Runs as `python3 -m unittest tools.test_chain_lint` or `python3 tools/test_chain_lint.py`."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools import chain_lint  # noqa: E402
from tools.chain_lint import check, hits  # noqa: E402


class ChainLintTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'lean/BsvChain').mkdir(parents=True)
        (self.root / 'lean/BsvChain.lean').write_text('import BsvChain.Clean\n')

    def fixture(self, name, text):
        (self.root / f'lean/BsvChain/{name}.lean').write_text(text)
        return check(self.root)[1]

    def test_clean(self):
        self.assertEqual(self.fixture('Clean', 'def answer : Nat := 42\n'), [])

    def test_comments_only(self):
        self.assertEqual(self.fixture('Comments',
            '-- IO\n/- IO /- @[extern "x"] -/ getCurrentTime -/\n'
            '/-- GetAdjustedTime() IO -/\ndef answer := 42\n'), [])

    def test_real_io(self):
        self.assertEqual(self.fixture('Effect', 'def action : IO Nat := pure 42\n'),
                         ['lean/BsvChain/Effect.lean:1: forbidden IO'])

    def test_extern(self):
        self.assertEqual(self.fixture('Extern', '@[extern "clock"]\ndef clock : Nat := 0\n'),
                         ['lean/BsvChain/Extern.lean:1: forbidden @[extern'])

    def test_free_now(self):
        self.assertEqual(self.fixture('Free', 'def clock : Nat :=\n  now + 1\n'),
                         ['lean/BsvChain/Free.lean:1: free now in def clock'])

    def test_bound_now(self):
        self.assertEqual(self.fixture('Bound', 'def clock (now : Nat) : Nat := now + 1\n'), [])

    def test_structure_input(self):
        self.assertEqual(hits('def clock (ctx : Context) := ctx.now\n'), [])
        self.assertEqual(hits('def clock := global.now\n'), [(1, 'free now in def clock')])

    def test_identifiers_and_strings(self):
        self.assertEqual(hits('def IOLonger := "IO /- now --"\ndef nowLater := 0\n'), [])
        self.assertEqual(hits("def IO' := 0\ndef unsafeLater := 0\n"), [])
        self.assertEqual(hits('def f : «IO» Nat := pure 0\n'), [(1, 'forbidden IO')])
        self.assertEqual(hits('def «IO.longer» := 0\n'), [])

    def test_all_forbidden_tokens(self):
        for name in ('IO', 'BaseIO', 'EIO', 'unsafe', 'opaque', 'Std.Time',
                     'IO.monoMsNow', 'IO.monoNanosNow', 'IO.getRandomBytes',
                     'IO.getEnv', 'getCurrentTime', '@[implemented_by'):
            with self.subTest(name=name):
                self.assertTrue(hits(name))

    def test_equations_and_own_signature(self):
        self.assertEqual(hits('def f (now : Nat) : Nat → Nat\n  | n => now + n\n'), [])
        self.assertEqual(hits('variable (now : Nat)\ndef f : Nat := now\n'),
                         [(2, 'free now in def f')])
        self.assertEqual(hits('def f (now : Nat) := now\ndef g := now\n'),
                         [(2, 'free now in def g')])
        self.assertEqual(hits('def f := { now := 42 }\n'), [])

    def test_attribute_and_escaped_now(self):
        self.assertEqual(hits('@[inline] def f := «now»\n'),
                         [(1, 'free now in def f')])
        self.assertEqual(hits('def f («now» : Nat) := «now»\n'), [])

    def test_signature_default_is_not_body(self):
        self.assertEqual(hits('def f (now : Nat := 0) := now\n'), [])
        self.assertEqual(hits('def f (value : Nat := 0) := now\n'),
                         [(1, 'free now in def f')])

    def test_scope_and_cli_exit(self):
        (self.root / 'lean/Test').mkdir()
        (self.root / 'lean/Test/Outside.lean').write_text('IO')
        self.fixture('Clean', 'def f := 0\n')
        script = Path(__file__).with_name('chain_lint.py')
        result = subprocess.run([sys.executable, str(script), '--root', str(self.root)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('(2 files, 0 clock', result.stdout)
        self.fixture('Bad', 'IO\n')
        result = subprocess.run([sys.executable, str(script), '--root', str(self.root)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('lean/BsvChain/Bad.lean:1: forbidden IO', result.stdout)

    def test_parameter_half(self):
        planted = {
            'def p : ChainParams := ChainParams.mainnet\n':
                ':1: fixed ChainParams.mainnet in def p',
            'def f (c : NodeConfig := NodeConfig.defaults) := 0\n':
                ':1: fixed NodeConfig.defaults in def f',
            'def f := g .regtest\n': ':1: fixed .regtest in def f',
            'structure S where\n  c : NodeConfig := NodeConfig.defaults\n':
                ':2: fixed NodeConfig.defaults in structure S',
            'instance : Inhabited ChainParams := ⟨ChainParams.testnet⟩\n':
                ':1: fixed ChainParams.testnet in instance ?',
            'abbrev p := BsvChain.ChainParams.stn\n':
                ':1: fixed BsvChain.ChainParams.stn in abbrev p',
        }
        for text, kind in planted.items():
            with self.subTest(text=text):
                self.assertEqual(self.fixture('Planted', text), ['lean/BsvChain/Planted.lean' + kind])
        for text in ('-- ChainParams.mainnet\n/-- the `.regtest` network -/\ndef a := 0\n',
                     'theorem t : f ChainParams.mainnet = 0 := rfl\n',
                     'def f (params : ChainParams) := params.mainnet\n',
                     'def NetworkData.mainnet : Nat := 0\n'):
            with self.subTest(text=text):
                self.assertEqual(self.fixture('Planted', text), [])
        (self.root / 'lean/BsvChain/Planted.lean').unlink()
        self.assertEqual(self.fixture('Params', 'def p : ChainParams := ChainParams.mainnet\n'), [])

    def test_parameter_allowlist(self):
        key = ('lean/BsvChain/Planted.lean', 'fixed ChainParams.mainnet in def p')
        with mock.patch.dict(chain_lint.ALLOWLIST, {key: 'a planted fixture'}):
            self.assertEqual(self.fixture('Planted', 'def p : ChainParams := ChainParams.mainnet\n'), [])
        with mock.patch.dict(chain_lint.ALLOWLIST, {key: ' '}):
            with self.assertRaises(ValueError):
                self.fixture('Planted', 'def p : ChainParams := ChainParams.mainnet\n')
        self.assertEqual(self.fixture('Planted', 'def p : ChainParams := ChainParams.mainnet\n'),
                         ['lean/BsvChain/Planted.lean:1: fixed ChainParams.mainnet in def p'])


if __name__ == '__main__':
    unittest.main()
