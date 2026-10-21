import argparse,collections,gzip,hashlib,json,pathlib,re,subprocess,tomllib
p=argparse.ArgumentParser()
p.add_argument('--source',required=True,type=pathlib.Path)
p.add_argument('--reports',required=True,type=pathlib.Path)
a=p.parse_args()
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
seed_manifest=json.loads((a.source/'corpus/seed/manifest.json').read_text())
seed_path=a.source/'corpus/seed'/seed_manifest['file']
corpus=[json.loads(line) for line in seed_path.read_text().splitlines() if line.strip()]
report_spec=a.reports/'spec/seed.jsonl'
if report_spec.exists():
    raw_spec=report_spec.read_bytes()
else:
    raw_spec=gzip.decompress(report_spec.with_suffix('.jsonl.gz').read_bytes())
spec=[json.loads(line) for line in raw_spec.splitlines() if line.strip()]
manifest=json.loads((a.reports/'bsv-rs/manifest.json').read_text())['seed']
log=(a.reports/'seed.log').read_text()
summary=(a.reports/'summary.txt').read_text()
corpus_by_id={row['id']:row for row in corpus}
spec_by_id={row['id']:row for row in spec}
columns=('spec','spec-mempool')
counts={col:dict(collections.Counter(row[col]['verdict'] for row in spec)) for col in columns}
stamps=sorted({row['commit'] for row in spec})
configs=sorted({row['config'] for row in spec})
mismatches=[]
missing=[]
for row in spec:
    original=corpus_by_id[row['id']]
    for col in columns:
        key=col+'@'+row['commit']
        if key not in original['expect']:
            missing.append({'id':row['id'],'key':key})
            continue
        recorded=original['expect'][key]
        normalized={k:recorded.get(k) for k in ('verdict','code','input')}
        if row[col]!=normalized:
            mismatches.append({'id':row['id'],'column':col})
raw_witness=(a.reports/'bsv-rs/seed.jsonl').read_bytes()
witness_count=sum(bool(x.strip()) for x in raw_witness.splitlines())
lock=tomllib.loads((a.source/'harness/Cargo.lock').read_text())
crate=next(x for x in lock['package'] if x['name']=='bsv-rs')
header=tomllib.loads((a.source/'harness/Cargo.toml').read_text())
report_agree=re.search(r'agree: spec-mempool (\d+) .*?, spec (\d+) ',log)
status_match=re.search(r'harness/run: (\d+) GREEN, (\d+) RED, (\d+) skipped;',summary)
assert report_agree and status_match
result={
 'source':subprocess.check_output(['git','-C',str(a.source),'rev-parse','HEAD'],text=True).strip(),
 'seed_sha256':digest(seed_path),
 'seed_manifest_sha256':seed_manifest['sha256'],
 'seed_manifest_count':seed_manifest['count'],
 'seed_rows':len(corpus),
 'seed_unique_ids':len(corpus_by_id),
 'spec_rows':len(spec),
 'spec_unique_ids':len(spec_by_id),
 'spec_only_ids':len(spec_by_id.keys()-corpus_by_id.keys()),
 'seed_only_ids':len(corpus_by_id.keys()-spec_by_id.keys()),
 'spec_commit_stamps':stamps,
 'spec_configs':configs,
 'spec_verdict_cells':sum(sum(counts[col].values()) for col in columns),
 'spec_verdict_counts':counts,
 'missing_recorded_keys':len(missing),
 'recorded_export_mismatches':len(mismatches),
 'report_entries':manifest['entries'],
 'report_agree_spec':manifest['agree_block'],
 'report_agree_spec_mempool':manifest['agree_mempool'],
 'log_agree_spec':int(report_agree[2]),
 'log_agree_spec_mempool':int(report_agree[1]),
 'report_undecided':manifest['undecided'],
 'report_aborts_as_witnesses':manifest['aborts_as_witnesses'],
 'report_unknown_messages':manifest['unknown_messages'],
 'report_rule_rows':len(manifest['rules']),
 'witness_rows':witness_count,
 'report_witnesses':manifest['witnesses'],
 'report_green_corpora':int(status_match[1]),
 'report_red_corpora':int(status_match[2]),
 'report_skipped_corpora':int(status_match[3]),
 'reported_implementation_version':manifest['bsv-rs'],
 'cargo_manifest_implementation_pin':header['dependencies']['bsv-rs'],
 'cargo_lock_implementation_version':crate['version'],
 'cargo_lock_implementation_checksum':crate['checksum'],
 'spec_output_sha256':hashlib.sha256(raw_spec).hexdigest(),
 'spec_output_bytes':len(raw_spec),
 'witness_output_sha256':hashlib.sha256(raw_witness).hexdigest(),
 'witness_output_bytes':len(raw_witness),
 'report_spec_identity':manifest['spec'],
 'report_spec_configuration':manifest['spec_config'],
 'report_files_sha256':{str(path.relative_to(a.reports)):digest(path) for path in sorted(a.reports.rglob('*')) if path.is_file()},
 'readme_sha256':digest(a.source/'harness/README.md'),
}
checks={
 'seed_hash_matches_manifest':result['seed_sha256']==seed_manifest['sha256'],
 'seed_count_matches_manifest':len(corpus)==seed_manifest['count'],
 'unique_and_complete_ids':len(corpus)==len(corpus_by_id)==len(spec)==len(spec_by_id) and spec_by_id.keys()==corpus_by_id.keys(),
 'every_recorded_verdict_exported_unchanged':not missing and not mismatches,
 'entry_and_agreement_counts_match':manifest['entries']==len(corpus) and manifest['agree_block']==int(report_agree[2]) and manifest['agree_mempool']==int(report_agree[1]),
 'witness_count_matches_manifest':witness_count==manifest['witnesses'],
 'witness_hash_matches_manifest':result['witness_output_sha256']==manifest['sha256'],
 'implementation_identity_matches_pins':manifest['bsv-rs']==crate['version'] and header['dependencies']['bsv-rs']=='='+crate['version'],
 'spec_identity_matches_exports':stamps==[manifest['spec'].split('@',1)[1]] and configs==[manifest['spec_config']],
 'summary_and_driver_green':bool(re.search(r'^GREEN seed:',summary,re.M)) and bool(re.search(r'^run_diff: GREEN',log,re.M)),
}
result['checks']=checks
result['receipt_verification']='GREEN' if all(checks.values()) else 'RED'
print(json.dumps(result,indent=2,sort_keys=True))
raise SystemExit(0 if all(checks.values()) else 1)
