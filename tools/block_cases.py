#!/usr/bin/env python3
"""#63 derived boundaries, independent of Lean and of the pending #66 node.

[SRC] bitcoin-sv v1.2.3, 6504a3aff65ba97c0f6c80962b033e35ecbfed4b:
src/validation.cpp:519–639,2252–2262,5634–5655,5736–5901,5933–6104;
src/pow.cpp:22–297; src/arith_uint256.cpp:182–224;
src/consensus/merkle.cpp:210–282. All expectations are [D].
"""
import hashlib
import json
from pathlib import Path
import struct

PIN = "6504a3aff65ba97c0f6c80962b033e35ecbfed4b"
SOURCE = f"[SRC] src/validation.cpp:5736–6104; src/pow.cpp:22–297; src/consensus/merkle.cpp:210–282 at {PIN}"
ROWS = []
BITS = 0x207fffff
TIME = 500000100


def dh(b):
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def compact(n):
    return bytes([n]) if n < 253 else b"\xfd" + struct.pack("<H", n) if n <= 65535 else b"\xfe" + struct.pack("<I", n)


def script_num(n):
    raw = n.to_bytes((n.bit_length()+7)//8, "little")
    return raw + b"\0" if raw and raw[-1] & 128 else raw


def height_push(n):
    return b"\0" if n == 0 else bytes([0x50+n]) if n <= 16 else bytes([len(script_num(n))]) + script_num(n)


def tx(coinbase=False, script=None, output=b"\x51", lock=0, sequence=0xffffffff,
       prev=None, value=1, inputs=True, outputs=True):
    script = (b"\x01\x01" if coinbase else b"") if script is None else script
    prev = (b"\0"*32 if coinbase else b"\x11"*32) if prev is None else prev
    ins = prev + struct.pack("<I", 0xffffffff if coinbase else 0) + compact(len(script)) + script + struct.pack("<I", sequence)
    outs = struct.pack("<Q", value) + compact(len(output)) + output
    return struct.pack("<I", 1) + compact(int(inputs)) + (ins if inputs else b"") + compact(int(outputs)) + (outs if outputs else b"") + struct.pack("<I", lock)


def root(txs):
    leaves = list(map(dh, txs))
    while len(leaves) > 1:
        if len(leaves) % 2: leaves.append(leaves[-1])
        leaves = [dh(leaves[i]+leaves[i+1]) for i in range(0,len(leaves),2)]
    return leaves[0] if leaves else b"\0"*32


def header(txs=(), time=TIME+1, bits=BITS, version=4, merkle=None):
    return struct.pack("<I", version) + b"\0"*32 + (root(txs) if merkle is None else merkle) + struct.pack("<III", time, bits, 0)


def block(txs, **kw):
    return (header(txs, **kw)+compact(len(txs))+b"".join(txs)).hex()


def chain(height=999, times=None, bits=BITS, work=0):
    return dict(height=height, ancestors=[dict(time=t, bits=bits, work=work) for t in (times or [TIME]*11)])


def ok(): return dict(status="ok")


def reject(reason, code=16, corrupt=False):
    return dict(status="rejected", code=code, reason=reason, corruptionPossible=corrupt)


def add(id, kind, expected, derivation, **kw):
    ROWS.append(dict(id=id, kind=kind, label="[D]", node="pending #66", source=SOURCE,
                     derivation=derivation, expected=expected, **kw))


def body(id, txs, expected, **kw):
    add(id,"block",expected,"Ordered CheckBlock gate at the pinned boundary.",
        block=block(txs, **kw.pop("header",{})), height=kw.pop("height",1000),
        options=kw.pop("options",dict(proofOfWork=False)), **kw)


def contextual(id, txs, expected, **kw):
    add(id,"context-block",expected,"Size precedes block-cutoff finality, then BIP34 prefix.",
        block=block(txs, **kw.pop("header",{})), previous=kw.pop("previous",chain()),
        params=kw.pop("params",dict(bip34Height=1000,csvHeight=0)), **kw)


def make_rows():
    cb = tx(True, height_push(1000))
    a,b = tx(prev=b"\x21"*32),tx(prev=b"\x22"*32)
    body("block/valid",[cb,a,b],ok())
    body("block/pow-precedes-root",[cb],reject("high-hash"),header=dict(bits=0,merkle=b"\0"*32),options={})
    body("block/root-mismatch",[cb,a],reject("bad-txnmrklroot",corrupt=True),header=dict(merkle=b"\0"*32))
    body("block/duplicate-suffix",[cb,a,b,b],reject("bad-txns-duplicate",corrupt=True))
    body("block/duplicate-interior",[cb,cb,a,b],reject("bad-txns-duplicate",corrupt=True))
    body("block/root-before-duplicate",[cb,a,b,b],reject("bad-txnmrklroot",corrupt=True),header=dict(merkle=b"\0"*32))
    body("block/empty",[],reject("bad-cb-missing"))
    body("block/missing-coinbase",[a],reject("bad-cb-missing"))
    size = len(bytes.fromhex(block([cb,a])))
    body("block/size-at-setting",[cb,a],ok(),config=dict(excessiveBlockSize=size))
    body("block/size-one-over-setting",[cb,a],reject("bad-blk-length"),config=dict(excessiveBlockSize=size-1))
    body("block/early-count",[cb,a],reject("bad-blk-length"),config=dict(excessiveBlockSize=19))
    body("block/size-before-noncoinbase",[a],reject("bad-blk-length"),config=dict(excessiveBlockSize=10))
    body("block/size-disabled",[cb],ok(),config=dict(excessiveBlockSize=1),options=dict(proofOfWork=False,maxBlockSize=False))
    body("block/merkle-disabled",[cb],ok(),header=dict(merkle=b"\0"*32),options=dict(proofOfWork=False,merkleRoot=False))
    for n in [1,2,100,101]:
        body(f"block/coinbase-script-{n}",[tx(True,b"\x01"*n)],ok() if 2<=n<=100 else reject("bad-cb-length"))
    body("block/extra-coinbase",[cb,tx(True,b"\x01\x02")],reject("bad-tx-coinbase"))
    for name,bad,reason in [("vin-empty",tx(inputs=False),"bad-txns-vin-empty"),
        ("vout-empty",tx(outputs=False),"bad-txns-vout-empty"),
        ("negative",tx(value=2**63),"bad-txns-vout-negative"),
        ("over-money",tx(value=2100000000000001),"bad-txns-vout-toolarge")]:
        body("block/"+name,[cb,bad],reject(reason))
    p2sh=b"\xa9\x14"+b"\x22"*20+b"\x87"
    body("block/p2sh-before-genesis",[cb,tx(output=p2sh)],ok(),height=9999)
    body("block/p2sh-at-genesis",[cb,tx(output=p2sh)],reject("bad-txns-vout-p2sh"),height=10000)
    sigcb=tx(True,output=b"\xac"*2)
    body("block/sigops-at-cap",[sigcb],ok(),config=dict(maxBlockSigOpsPerMbBeforeGenesis=2))
    body("block/sigops-above-cap",[sigcb],reject("bad-blk-sigops"),config=dict(maxBlockSigOpsPerMbBeforeGenesis=1))
    body("block/sigops-before-next-structure",[sigcb,tx(inputs=False)],reject("bad-blk-sigops"),config=dict(maxBlockSigOpsPerMbBeforeGenesis=1))
    body("block/regular-before-own-sigops",[cb,tx(inputs=False,output=b"\xac"*2)],reject("bad-txns-vin-empty"),config=dict(maxBlockSigOpsPerMbBeforeGenesis=1))
    body("block/sigops-off-at-genesis",[sigcb],ok(),height=10000,config=dict(maxBlockSigOpsPerMbBeforeGenesis=1))
    contextual("context/size-at-setting",[cb],ok(),config=dict(excessiveBlockSize=len(bytes.fromhex(block([cb])))))
    contextual("context/size-one-over",[cb],reject("bad-blk-length"),config=dict(excessiveBlockSize=len(bytes.fromhex(block([cb])))-1))
    nonfinal=tx(lock=TIME,sequence=0)
    contextual("context/nonfinal-at-median",[cb,nonfinal],reject("bad-txns-nonfinal"))
    contextual("context/final-below-median",[cb,tx(lock=TIME-1,sequence=0)],ok())
    contextual("context/pre-csv-own-time",[cb,nonfinal],ok(),params=dict(bip34Height=1000,csvHeight=1001))
    contextual("context/finality-before-height",[tx(True),nonfinal],reject("bad-txns-nonfinal"))
    contextual("context/bip34-one-below",[tx(True)],ok(),previous=chain(998))
    contextual("context/bip34-at-wrong",[tx(True)],reject("bad-cb-height"))
    contextual("context/bip34-at-correct",[cb],ok())
    # [SRC] src/config.cpp:232–245: a launchable nonzero setting exceeds 1 MB.
    # These literal blocks exercise that setting as well as the smaller model probes.
    script = height_push(10000)
    overhead = len(bytes.fromhex(block([tx(True,script,output=b"\0"*65536)]))) - 65536
    for extra in [0,1]:
        large = tx(True,script,output=b"\0"*(1000001+extra-overhead))
        assert len(bytes.fromhex(block([large]))) == 1000001+extra
        expected = ok() if extra==0 else reject("bad-blk-length")
        body(f"block/launchable-size-plus-{extra}",[large],expected,height=10000,config=dict(excessiveBlockSize=1000001))
        contextual(f"context/launchable-size-plus-{extra}",[large],expected,previous=chain(9999),config=dict(excessiveBlockSize=1000001))
    for h in [1,16,17,127,128]:
        contextual(f"context/height-push-{h}",[tx(True,height_push(h)+b"\x00")],ok(),previous=chain(h-1,times=[TIME]*min(11,h)),params=dict(bip34Height=0,csvHeight=0))
    for name,t,expected in [("time-at-median",TIME,reject("time-too-old")),("time-above-median",TIME+1,ok()),
        ("time-at-two-hours",TIME+7200,ok()),("time-over-two-hours",TIME+7201,reject("time-too-new"))]:
        add("header/"+name,"context-header",expected,"Strict lower and inclusive upper timestamp bounds.",header=header(time=t).hex(),previous=chain(),now=TIME)
    add("header/difficulty-before-time","context-header",reject("bad-diffbits"),"Difficulty is checked before time.",header=header(time=TIME,bits=BITS-1).hex(),previous=chain(),now=TIME)
    for name,v,params in [("bip34",1,dict(bip34Height=1000)),("bip66",2,dict(bip66Height=1000)),("bip65",3,dict(bip65Height=1000))]:
        add("header/version-"+name,"context-header",reject(f"bad-version(0x{v:08x})",17),"Height floor, not a live version-majority vote.",header=header(version=v).hex(),previous=chain(),now=TIME,params=params)
    add("header/negative-now","context-header",reject("time-too-new"),"Adjusted time is signed.",header=header().hex(),previous=chain(),now=-1)
    add("header/missing-ancestry","context-header",dict(status="unresolved"),"Partial MTP is not substituted for missing ancestry.",header=header().hex(),previous=chain(times=[TIME]),now=TIME)
    for name,bits,hash_value,result in [("zero",0,0,False),("negative",0x1d80ffff,0,False),
        ("overflow",0x23000001,0,False),("above-limit",0x1e00ffff,0,False),
        ("equal-target",0x03000001,1,True),("over-target",0x03000001,2,False)]:
        add("pow/"+name,"pow",result,"Target flags/range, then hash <= target.",network="mainnet",bits=bits,hash=hash_value)
    for bits,target,neg,over in [(0x01800001,0,False,False),(0x04923456,0x12345600,True,False),
        (0x220000ff,255*256**31,False,False),(0x22000100,0,False,True),(0x2100ffff,65535*256**30,False,False)]:
        add(f"compact/{bits:08x}","compact",dict(target=target,negative=neg,overflow=over),"SetCompact flags inspect the shifted mantissa and original exponent.",bits=bits)
    for h,value in [(0,5000000000),(209999,5000000000),(210000,2500000000),(33*210000,0),(64*210000,0)]:
        add(f"subsidy/{h}","subsidy",value,"Integer halving at the pinned mainnet interval.",network="mainnet",height=h)
    for n in [0,1]:
        add(f"reward/limit-plus-{n}","coinbase-amount",ok() if n==0 else reject("bad-cb-amount"),
            "[SRC] src/validation.cpp:3655–3666: reward is subsidy plus accepted fees; one satoshi over fails.",
            tx=tx(True,value=5000000007+n).hex(),height=0,fees=7)
    child=tx(prev=dh(a))
    for name,txs,height,tip,expected in [("ordered",[cb,a,child],100,200,ok()),("reversed",[cb,child,a],100,200,reject("bad-blk-ttor",0)),
        ("distance-one-below",[cb,child,a],101,200,ok()),("ahead-of-tip",[cb,child,a],201,200,ok()),("no-tip",[cb,child,a],100,None,ok())]:
        add("ttor/"+name,"ttor",expected,"Local policy only, with signed distance and explicit active tip.",block=block(txs),height=height,tip=tip)
    def next_case(name,previous,expected,**kw):
        add("next/"+name,"nextwork",expected,"Pinned difficulty branch boundary; missing asserted ancestry is unresolved.",header=header(time=kw.pop("time",TIME)).hex(),previous=previous,**kw)
    next_case("genesis",None,0x1d00ffff,network="mainnet")
    next_case("no-retarget-before-daa",chain(0,bits=0x1c123456),0x1c123456)
    next_case("testnet-delay-at",chain(100,bits=0x1c123456),0x1c123456,network="testnet",time=TIME+1200)
    next_case("testnet-delay-over",chain(100,bits=0x1c123456),0x1d00ffff,network="testnet",time=TIME+1201)
    scan=chain(100,times=[TIME]*3,bits=0x1d00ffff);scan["ancestors"][-1]["bits"]=0x1c123456
    next_case("testnet-backscan",scan,0x1c123456,network="testnet")
    for elapsed,bits in [(43199,0x1c100000),(43200,0x1c140000)]:
        next_case(f"eda-{elapsed}",chain(100,times=[elapsed]*6+[0]*11,bits=0x1c100000),bits,network="mainnet")
    next_case("eda-cap",chain(100,times=[43200]*6+[0]*11,bits=0x1d00eeee),0x1d00ffff,network="mainnet")
    next_case("eda-missing",chain(100,times=[TIME],bits=0x1c100000),None,network="mainnet")
    for elapsed,bits in [(1,0x1b400000),(1209600,0x1c010000),(99999999,0x1c040000)]:
        times=[elapsed]*2015+[0]
        next_case(f"periodic-{elapsed}",chain(2015,times=times,bits=0x1c010000),bits,network="mainnet")
    next_case("daa-delay",chain(2016),0x1d00ffff,network="testnet",params=dict(daaHeight=2016),time=TIME+1201)
    next_case("daa-missing",chain(2016),None,network="mainnet",params=dict(daaHeight=2016))


if __name__ == "__main__":
    make_rows()
    for row in ROWS:
        if 0 < row.get("config",{}).get("excessiveBlockSize",1000001) <= 1000000:
            row["derivation"] += " Model-field perturbation: the launch setter refuses this size ([SRC] src/config.cpp:232–245); the launchable-size rows use an admissible setting."
    path=Path("corpus/chain/block/block.jsonl");path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text("".join(json.dumps(r,separators=(",",":"))+"\n" for r in ROWS))
    print(f"block_cases: {len(ROWS)} derived rows; node pending #66")
