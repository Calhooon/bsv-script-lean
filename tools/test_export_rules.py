#!/usr/bin/env python3
"""Contract checks for rule withholding; fixtures contain synthetic identifiers."""
import io
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import export_gate as gate
import export_public as export


class RuleExportTests(unittest.TestCase):
    def setUp(self):
        self.table = {'engine': 'sample', 'pin': 'v1', 'classes': {
            'private.class': {'ruling': 'impl-wrong', 'note': 'unicode: é'},
            'kept.class': {'ruling': 'open'}}, 'rows': [
            {'class': 'private.class', 'when': {'a': 1}},
            {'class': 'kept.class', 'when': {'b': 2}},
            {'class': 'private.class', 'when': {'c': 3}}]}
        self.selected = {'private.class': 'example-group'}

    def test_empty_round_trip_and_multiple_rows(self):
        for indent in (1, 2):
            raw = (json.dumps(self.table, indent=indent, ensure_ascii=False) + '\n').encode()
            self.assertEqual(export.withhold_rule_data('table.json', raw, {})[0], raw)
            public, classes, rows = export.withhold_rule_data('table.json', raw, self.selected)
            self.assertEqual((classes, rows), (1, 2))
            actual = json.loads(public)
            self.assertEqual(actual['rows'], [self.table['rows'][1]])
            self.assertEqual(actual['classes'], {'kept.class': self.table['classes']['kept.class']})
            self.assertEqual(raw, (json.dumps(self.table, indent=indent, ensure_ascii=False) + '\n').encode())

    def test_empty_round_trip_every_rules_table(self):
        # teranode-gate.json is #95's gate index, not a classifier table, and the export's rules
        # policy names only go-sdk.json (tools/export_withheld_rules.txt), so it is excluded here
        paths = sorted(p for p in (Path(export.ROOT) / 'harness/rules').glob('*.json')
                       if p.name != 'teranode-gate.json')
        self.assertTrue(paths)
        for path in paths:
            with self.subTest(table=path.name):
                raw = path.read_bytes()
                self.assertEqual(export.withhold_rule_data(str(path), raw, {}), (raw, 0, 0))

    def test_withhold_static_class_keeps_class_from_rows(self):
        path = Path(export.ROOT) / 'harness/rules/bsv-rs.json'
        raw = path.read_bytes()
        table = json.loads(raw)
        derived = [row for row in table['rows'] if 'class_from' in row]
        self.assertTrue(derived)
        public, classes, rows = export.withhold_rule_data(
            str(path), raw, {'engine.word-out-of-scope': 'example-group'})
        self.assertEqual((classes, rows), (1, 4))
        actual = json.loads(public)
        self.assertNotIn('engine.word-out-of-scope', actual['classes'])
        self.assertFalse(any(row.get('class') == 'engine.word-out-of-scope' for row in actual['rows']))
        self.assertEqual([row for row in actual['rows'] if 'class_from' in row], derived)
        for row in derived:
            block = '\n'.join('  ' + line for line in json.dumps(row, indent=1, ensure_ascii=False).splitlines()).encode()
            self.assertIn(block, raw)
            self.assertIn(block, public)

    def test_missing_class_and_unknown_format_stop(self):
        raw = json.dumps(self.table).encode()
        with self.assertRaises(SystemExit):
            export.withhold_rule_data('table.json', raw, {'absent.class': 'example-group'})
        with self.assertRaises(SystemExit):
            export.withhold_rule_data('table.json', b' ' + raw, {})

    def test_witness_count_uses_sources_from_other_groups(self):
        entries = {'corpus/a/a.jsonl': {'source': {'tx': 'older-group'}},
                   'corpus/witnesses/a.jsonl': {'copy-a-source': {'tx': 'example-group'},
                                               'copy-b-source': {'tx': 'example-group'}}}
        self.assertEqual(export.rule_entry_counts(entries, {'table.json': self.selected})['example-group'], (1, 1))

    def test_aliases_preserve_nested_source_names(self):
        entries = {'corpus/a/a.jsonl': {'source': {'tx': 'older-group'}, 'road-source': {'tx': 'older-group'}},
                   'corpus/witnesses/a.jsonl': {'copy-source': {'tx': 'example-group'},
                                               'copy-road-source': {'tx': 'example-group'}}}
        aliases = export.rule_aliases(entries, {'example-group': [re.compile('source')]})
        self.assertTrue(aliases['copy-source'].endswith('-' + aliases['source']))
        self.assertTrue(aliases['copy-road-source'].endswith('-' + aliases['road-source']))
        public = {p: {aliases[i]: fields for i, fields in ids.items()} for p, ids in entries.items()}
        self.assertEqual(export.rule_entry_counts(public, {'table.json': self.selected}),
                         export.rule_entry_counts(entries, {'table.json': self.selected}))

    def test_wrapped_history_span_uses_records_markers(self):
        path = 'docs/records/example.md'
        plan = {'spans': {path: {'group': 'example-group', 'lines': [[2, 3]]}},
                'pointers': {'example-group': [re.compile(r'private[.]class')]},
                'classes': {'private.class': {'group': 'example-group'}}, 'history': {}}
        public, count = export.withhold_rule_history(path, b'keep\nprivate.class\nwrapped\nkeep again\n',
                                                    plan['pointers']['example-group'], plan)
        self.assertEqual(count, 2)
        self.assertEqual(public.count(export.MARKER.encode()), 2)
        self.assertIn(b'keep again\n', public)
        self.assertNotIn(b'wrapped', public)

    def test_gate_rejects_class_in_another_table_and_report_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, target = Path(tmp) / 'private', Path(tmp) / 'export'
            rel = 'harness/rules/sample.json'
            for base in (root, target):
                (base / rel).parent.mkdir(parents=True)
            table = {**self.table, 'rows': self.table['rows'] + [{'class_from': {'sample.rule': 'kept.class'}}]}
            raw = (json.dumps(table, indent=1, ensure_ascii=False) + '\n').encode()
            (root / rel).write_bytes(raw)
            public = export.withhold_rule_data(rel, raw, self.selected)[0]
            (target / rel).write_bytes(public)
            mp = target / 'corpus/witnesses/sample/manifest.json'
            mp.parent.mkdir(parents=True)
            mp.write_text(json.dumps({'sample': {'rules': [{'rule': 'kept.class', 'ruling': 'open'}]}}))
            report = target / 'docs/CONFORMANCE-example.md'
            report.parent.mkdir()
            report.write_text(f'Exported `{rel}`: [M] 1 class definitions, [M] 2 classifier rows;\n'
                              '### sample (1 class rows)\n| sample | 0 | 0 | 1 | 0 |\n')
            with patch.object(gate, 'ROOT', str(root)), patch.object(gate, 'load_withheld_rules', return_value={rel: self.selected}):
                self.assertEqual(gate.check_withheld_rules(str(target)), ([], [('example-group', 1, 2)]))
                # #107: a CONFORMANCE page with no classifier sections is not the generated report
                (target / 'docs/CONFORMANCE-OTHER.md').write_text('## 1. The rows\n| row | verdict |\n')
                self.assertEqual(gate.check_withheld_rules(str(target)), ([], [('example-group', 1, 2)]))
                # a page that names the rule file quotes its counts, heading or not, and is judged
                (target / 'docs/CONFORMANCE-OTHER.md').write_text(f'The rows of `{rel}`: [M] 9 classifier rows.\n')
                self.assertEqual([r[1:3] for r in gate.check_withheld_rules(str(target))[0]],
                                 [('report-count-mismatch', 'docs/CONFORMANCE-OTHER.md')])
                (target / 'docs/CONFORMANCE-OTHER.md').unlink()
                report.rename(target / 'docs/CONFORMANCE-moved.md')
                (target / 'docs/CONFORMANCE-moved.md').write_text('### sample (1 class rows)\n')
                self.assertIn('report-count-mismatch', [r[1] for r in gate.check_withheld_rules(str(target))[0]])
                (target / 'docs/CONFORMANCE-moved.md').unlink()
                self.assertIn('missing-report', [r[1] for r in gate.check_withheld_rules(str(target))[0]])
                report.write_text(f'Exported `{rel}`: [M] 1 class definitions, [M] 2 classifier rows;\n'
                                  '### sample (1 class rows)\n| sample | 0 | 0 | 1 | 0 |\n')
                (target / 'harness/rules/other.json').write_text('{"note":"private.class"}')
                self.assertIn('present-class', [r[1] for r in gate.check_withheld_rules(str(target))[0]])
                (target / 'harness/rules/other.json').unlink()
                report.write_text(report.read_text().replace('(1 class rows)', '(2 class rows)'))
                self.assertIn('report-count-mismatch', [r[1] for r in gate.check_withheld_rules(str(target))[0]])

    def test_entry_id_keys_take_the_public_alias(self):
        # #107: a per-entry map (the clean-room outputs' shape) keys rows by entry ID; a withheld entry's
        # key becomes the alias its exported corpus row carries, every other key and value is kept.
        plan = {'classes': {'private.class': {}}, 'pointers': {'example-group': [re.compile(r'\bsample-0007\b')]},
                'aliases': {'sample-0007': 'withheld-abc'}, 'references': {}}
        value = {'outcomes': {'block': {'sample-0001': 'aa', 'sample-0007': 'ga'}}, 'counts': {'agree': 2}}
        public, fields, records = export.withhold_rule_references(value, plan)
        self.assertEqual(public, {'outcomes': {'block': {'sample-0001': 'aa', 'withheld-abc': 'ga'}}, 'counts': {'agree': 2}})
        self.assertEqual((fields, records), (1, 0))
        raw = (json.dumps(value, separators=(',', ':'))).encode()
        out = export.withhold_rule_artifact('harness/cleanroom/out/sample.json', raw, plan)
        self.assertNotIn(b'sample-0007', out)
        self.assertEqual(json.loads(out), public)
        self.assertEqual(plan['references']['harness/cleanroom/out/sample.json'], (1, 0))
        with self.assertRaises(SystemExit):
            export.withhold_rule_references({'sample-0007': 1, 'withheld-abc': 2}, plan)

    def test_manifest_names_each_reference_transform(self):
        plan = {'classes': {'private.class': {}}, 'pointers': {'example-group': [re.compile('private[.]class')]},
                'tables': {}, 'history': {}, 'reports': {}, 'references': {}}
        samples = {'harness/rules/sample.json': {'note': 'private.class', 'other': 'private.class'},
                   'corpus/witnesses/sample/manifest.json': [{'class': 'private.class'}]}
        for path, value in samples.items():
            _, fields, records = export.withhold_rule_references(value, plan)
            plan['references'][path] = fields, records
        stream = io.StringIO()
        export.write_rule_manifest(stream, plan)
        lines = stream.getvalue().splitlines()
        self.assertIn('withheld-rule-references 2 fields 1 records in 2 files', lines)
        self.assertIn('withheld-rule-reference 2 fields 0 records harness/rules/sample.json', lines)
        self.assertIn('withheld-rule-reference 0 fields 1 records corpus/witnesses/sample/manifest.json', lines)

    def test_gate_recounts_history_and_report_removals(self):
        with tempfile.TemporaryDirectory() as tmp:
            target, tools = Path(tmp) / 'export', Path(tmp) / 'tools'
            history = 'docs/records/example.md'
            report = 'docs/CONFORMANCE-example.md'
            originals = {history: b'keep\nprivate.class\nwrapped\nkeep again\n',
                         report: b'| private.class | selected |\n| kept.class | retained |\n'}
            for path in originals:
                (target / path).parent.mkdir(parents=True, exist_ok=True)
                (target / path).write_text('exported copy\n')
            tools.mkdir()
            (tools / 'export_withheld_history.json').write_text(json.dumps(
                {history: {'group': 'example-group', 'lines': [[2, 3]]}}))
            (tools / 'export_rewrite.txt').write_text('')
            manifest = ('source-commit ' + 'a' * 40 + '\n'
                        'withheld-history-group example-group 2 lines in 1 files\n'
                        f'withheld-report-rows 1 {report}\n')
            (target / gate.MANIFEST).write_text(manifest)
            with (patch.object(gate, 'TOOLS', str(tools)),
                  patch.object(gate, 'load_withheld_rules', return_value={'table.json': self.selected}),
                  patch.object(gate, 'rule_pointer_groups', return_value={'example-group': [re.compile('private[.]class')]}),
                  patch.object(gate, 'git', side_effect=lambda cmd, obj: originals[obj.split(':', 1)[1]])):
                rows, summaries = gate.check_rule_removal_counts(str(target))
                self.assertEqual(rows, [])
                self.assertEqual(summaries, ['(withheld history) 2 lines in 1 files, group example-group',
                                            f'(withheld report rows) 1 {report}'])
                (target / gate.MANIFEST).write_text(manifest.replace('2 lines', '1 lines'))
                self.assertIn('history-count-mismatch', [r[1] for r in gate.check_rule_removal_counts(str(target))[0]])
                (target / gate.MANIFEST).write_text(manifest.replace('withheld-report-rows 1', 'withheld-report-rows 0'))
                self.assertIn('report-removal-count-mismatch', [r[1] for r in gate.check_rule_removal_counts(str(target))[0]])


if __name__ == '__main__':
    unittest.main()
