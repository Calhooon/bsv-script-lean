[export: 2 lines withheld by tools/export_public.py, the sibling trees' lines; the original is in the private history]
import datetime, hashlib, json, os, pathlib, re, shlex, subprocess, sys, time
[withheld at export: a sibling tree's line]
[withheld at export: a sibling tree's line]
pin='e39ba468c3c9bef42f6041509914767f81f34a79'
receipt=pathlib.Path('/tmp/codex-s1-c56')
receipt.mkdir(exist_ok=False)
report=receipt/'report'
env=os.environ.copy()
env.update(CARGO_BUILD_JOBS='4', CARGO_NET_OFFLINE='true', CARGO_TARGET_DIR=str(source/'harness/target'))
commands=[]
def run(argv,cwd=None,quiet=False,required=True):
    started=datetime.datetime.now(datetime.timezone.utc).isoformat()
    t=time.monotonic()
    p=subprocess.run(argv,cwd=cwd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    row=dict(command=shlex.join(map(str,argv)),cwd=str(cwd or pathlib.Path.cwd()),started=started,wall_seconds=round(time.monotonic()-t,3),exit=p.returncode,stdout=p.stdout,stderr=p.stderr)
    commands.append(row)
    with (receipt/'commands.jsonl').open('a') as f: f.write(json.dumps(row)+'\n')
    print('[X] command:',row['command'],flush=True)
    print('[X] exit:',p.returncode,flush=True)
    if not quiet:
        if p.stdout: print(p.stdout,end='',flush=True)
        if p.stderr: print(p.stderr,end='',flush=True)
    if required and p.returncode: raise SystemExit(p.returncode)
    return p
run(['git','-C',admin,'worktree','add','--detach',str(source),pin])
head=run(['git','-C',str(source),'rev-parse','HEAD']).stdout.strip()
assert head==pin
run(['git','-C',str(source),'status','--short','--branch'])
run(['git','-C',str(source),'diff','--quiet','HEAD','--','corpus'])
run(['date','-u','+%Y-%m-%dT%H:%M:%SZ'])
run(['uname','-s'])
run(['rustup','toolchain','list'])
run(['rustup','run','1.95.0','rustc','--version'])
run(['cargo','--version'],cwd=source/'harness')
run(['cargo','fetch','--offline','--locked'],cwd=source/'harness')
run(['harness/run','--help'],cwd=source)
load=run(['uptime']).stdout
swap=run(['sysctl','vm.swapusage']).stdout
memory=run(['memory_pressure']).stdout
free_match=re.search(r'System-wide memory free percentage:\s*(\d+)%',memory)
load_match=re.search(r'load averages?:\s*([0-9.]+)',load)
assert free_match and load_match
free=int(free_match[1]); one=float(load_match[1])
permitted=free>=50 and one<20
machine=dict(free_percentage=free,one_minute_load=one,swap_raw=swap,gate=permitted)
(receipt/'machine.json').write_text(json.dumps(machine,indent=2)+'\n')
print('[M] build gate:',json.dumps(machine),flush=True)
if not permitted: raise SystemExit('Build gate closed; no waiting')
result=run(['harness/run','--impl','bsv-rs','--corpus','seed','--spec','recorded','--out',str(report)],cwd=source,required=False)
run(['git','-C',str(source),'diff','--quiet','HEAD','--','corpus'])
run(['git','-C',str(source),'status','--short','--branch'])
run(['uptime'])
run(['sysctl','vm.swapusage'])
run(['memory_pressure'])
run(['df','-h','/'])
run(['date','-u','+%Y-%m-%dT%H:%M:%SZ'])
summary=dict(source=head,implementation='bsv-rs',harness_exit=result.returncode,environment={k:env[k] for k in ('CARGO_BUILD_JOBS','CARGO_NET_OFFLINE','CARGO_TARGET_DIR')},report=str(report))
(receipt/'execution.json').write_text(json.dumps(summary,indent=2)+'\n')
if (report/'summary.txt').exists():
    print('[X] report summary follows',flush=True)
    print((report/'summary.txt').read_text(),flush=True)
print('[D] receipt:',receipt,flush=True)
