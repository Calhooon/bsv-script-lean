#!/usr/bin/env python3
"""[D] 2026-10-13: #66 loopback instrument, using the reference at PIN.
[SRC] test/functional/test_framework/mininode.py:48,2118-2690 at PIN.
No framework code or wire framing is implemented or copied here.
"""
import argparse
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import host_vars  # noqa: E402

PIN = '6504a3aff65ba97c0f6c80962b033e35ecbfed4b'
parser = argparse.ArgumentParser()
parser.add_argument('--framework', default=os.environ.get('BSV_PEER_FRAMEWORK'))
parser.add_argument('--receipt', required=True)
args = parser.parse_args()
if args.framework is None:
    # the reference clone's (docs/PROVENANCE.md 1a `$BSV_SPEC_REFERENCE_CLONE`, #177); unresolved, one line and exit 2
    ref = host_vars.value('BSV_SPEC_REFERENCE_CLONE')
    if ref is None:
        print(host_vars.refusal('peer', 'BSV_SPEC_REFERENCE_CLONE'), file=sys.stderr)
        sys.exit(2)
    args.framework = os.path.join(ref, 'test/functional')
framework = Path(args.framework).expanduser().resolve()
clone = Path(subprocess.check_output(
    ['git', '-C', str(framework.parent.parent), 'rev-parse', '--show-toplevel'],
    text=True).strip()).resolve()
sha = subprocess.check_output(['git', '-C', str(clone), 'rev-parse', 'HEAD'], text=True).strip()
if sha != PIN:
    raise SystemExit('peer: reference HEAD differs from pin')
canonical = clone / 'test/functional'
if framework != canonical.resolve():
    raise SystemExit('peer: framework root is not canonical')
framework_tree = canonical / 'test_framework'
status = subprocess.check_output(
    ['git', '-C', str(clone), 'status', '--porcelain', '--untracked-files=all',
     '--', 'test/functional/test_framework'], text=True)
if status:
    raise SystemExit('peer: framework source is dirty or untracked')
subprocess.run(['git', '-C', str(clone), 'diff', '--quiet', PIN, '--',
                'test/functional/test_framework'], check=True)
sys.dont_write_bytecode = True
sys.path.insert(0, str(framework))
from test_framework import mininode as m
from test_framework.transport import Connection, NetworkThread

# [X] 2026-10-13: certify actual imports before opening a receipt or transport.
for name, module in tuple(sys.modules.items()):
    if name == 'test_framework' or name.startswith('test_framework.'):
        origin = getattr(module, '__file__', None)
        if origin is None:
            raise SystemExit('peer: imported framework module has no source origin')
        path = Path(origin).resolve()
        if not path.is_relative_to(framework_tree.resolve()) or path.suffix != '.py':
            raise SystemExit('peer: imported framework module is outside pinned source')
        pinned = subprocess.check_output(['git', '-C', str(clone), 'show',
                                          f'{PIN}:{path.relative_to(clone).as_posix()}'])
        if path.read_bytes() != pinned:
            raise SystemExit('peer: imported framework source differs from pin')

lock = threading.RLock()
events = []
receipt = open(args.receipt, 'x', encoding='utf-8')

def log(direction, **fields):
    with lock:
        event = dict(utc=subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"], text=True).strip(),
                     label='[X]', date='2026-10-13', source_pin=sha,
                     index=len(events), direction=direction, **json.loads(json.dumps(fields)))
        events.append(event)
        receipt.write(json.dumps(event, sort_keys=True) + '\n')
        receipt.flush()
        return event

log('instrument', protocol_version=m.MY_VERSION, framework=str(framework))

# [D] 2026-10-13 (#72): the version message advertises the scenario's mock
# time, never the host clock. The node records nTime - GetTime() as this
# peer's offset sample ([SRC] src/net/net_processing.cpp:1896-1898 at PIN), so
# an advertised time equal to the node's mock time makes that sample zero.
# mininode.py:1183 fills nTime from time.time(); the subclass overwrites the
# field before P2PHandler's constructor sends it (mininode.py:2542-2554,2631).
advertised = None
# [D] 2026-10-15 (#66 cut 2): a connect step may name the user agent the version
# message carries. Teranode's legacy bridge rejects and bans a peer whose agent
# lacks `Bitcoin SV` or `BSV` ([SRC] services/legacy/peer_server.go:762-764,802-814
# at Teranode 4edb60a40c6628ff0ef60231c2628efd7103fde5); the framework's own agent
# (mininode.py:49) carries neither. Unset, the framework's agent is sent unchanged.
agent = None

class Handler(m.P2PHandler):
    # [D] 2026-10-15 (#80): the framework's own `msg_dsdetected` (mininode.py:2066-2093
    # at PIN) joins the reader's map, which omits it (mininode.py:2426-2460), so a
    # relayed `dsdetected` is read and logged instead of ending the connection.
    messagemap = {**m.P2PHandler.messagemap, b'dsdetected': m.msg_dsdetected}
    def send_message(self, message, pushbuf=False):
        if isinstance(message, m.msg_version):
            message.nTime = advertised
            if agent is not None:
                message.strSubVer = agent
        return super().send_message(message, pushbuf)
    def got_data(self, data):
        msg, length = super().got_data(data)
        if msg is not None:
            msg.received_bytes = bytes(data[:length]).hex()
        return msg, length
    def _log_message(self, direction, msg):
        raw = msg.received_bytes if direction == 'receive' else msg.serialize().hex()
        fields = dict(command=msg.command.decode('ascii'), hex=raw,
                      encoding='reference-message-frame' if direction == 'receive' else 'reference-message-payload')
        if getattr(msg, 'inv', None) is not None:
            fields['inventory'] = [dict(kind=i.type, hash=f'{i.hash:064x}') for i in msg.inv]
        # [D] 2026-10-15 (#79, lane s7-79): the block a compact-block message names.
        if isinstance(msg, m.msg_cmpctblock):
            header = msg.header_and_shortids.header
            header.rehash()
            fields['hash'] = f'{header.sha256:064x}'
        if isinstance(msg, m.msg_block):
            msg.block.rehash()
            fields['hash'] = f'{msg.block.sha256:064x}'
        if isinstance(msg, m.msg_blocktxn):
            fields['hash'] = f'{msg.block_transactions.blockhash:064x}'
        if isinstance(msg, m.msg_reject):
            fields.update(hash=f'{msg.data:064x}', code=msg.code,
                          reason=msg.reason.decode('utf-8', errors='replace'))
        log(direction, **fields)

class Callback(m.P2PEventHandler):
    def __init__(self):
        super().__init__()
        self.withheld = set()
        self.objects = {}
        self.requests = set()
    def on_getdata(self, conn, message):
        for item in message.inv:
            h = f'{item.hash:064x}'
            self.requests.add(h)
            if h not in self.withheld and h in self.objects:
                conn.send_message(self.objects[h])
    def on_inv(self, conn, message):
        # Observe announcements; requesting node-owned objects is unnecessary.
        pass
    def on_dsdetected(self, conn, message):
        # [D] 2026-10-15 (#80): a relayed `dsdetected` is logged by the handler; nothing answers it.
        pass

callback = Callback()
handler = None
network = None
cursor = 0

def matching(event, kind, wanted):
    if event['direction'] != 'receive':
        return False
    if kind != 'none' and event.get('command') != kind:
        return False
    if kind == 'none' and event.get('command') not in ('inv', 'getdata', 'reject'):
        return False
    return (wanted is None or event.get('hash') == wanted or
            any(item['hash'] == wanted for item in event.get('inventory', [])))

def barrier():
    # [SRC] 2026-10-13: mininode.py:2394-2421 ping ordering, then Rust waits for PTV.
    nonce = callback.ping_counter
    callback.send_message(m.msg_ping(nonce=nonce))
    m.wait_until(lambda: callback.last_message.get("pong") is not None and
                 callback.last_message["pong"].nonce == nonce,
                 timeout=10, lock=m.mininode_lock)
    callback.ping_counter += 1

def step(request):
    global handler, network, advertised, agent
    op = request['op']
    if op == 'connect':
        if handler is not None or request.get('host', '127.0.0.1') != '127.0.0.1':
            raise ValueError('connect requires one loopback connection')
        port = int(request['port'])
        if not 18571 <= port <= 18590:
            raise ValueError('port outside reserved scenario range')
        clock = request.get('time')
        if type(clock) is not int or clock <= 0:
            raise ValueError('connect requires the scenario mock time')
        advertised = clock
        if request.get('user_agent') is not None:
            agent = str(request['user_agent']).encode('ascii')
        connection = Connection('127.0.0.1', port, callback)
        handler = Handler(connection, None, net='regtest')
        callback.add_connection(handler)
        network = NetworkThread()
        network.start()
        callback.wait_for_verack(timeout=10)
        return dict(connected=True, protocol_version=m.MY_VERSION, advertised_time=advertised)
    if handler is None:
        raise ValueError('connect required')
    if op in ('send_tx', 'send_block'):
        obj = m.CTransaction() if op == 'send_tx' else m.CBlock()
        obj.deserialize(io.BytesIO(bytes.fromhex(request['hex'])))
        obj.rehash()
        message = m.msg_tx(obj) if op == 'send_tx' else m.msg_block(obj)
        callback.objects[obj.hash] = message
        callback.send_message(message)
        barrier()
        return dict(hash=obj.hash)
    if op == 'send_headers':
        msg = m.msg_headers()
        for raw in request['hex']:
            header = m.CBlockHeader()
            header.deserialize(io.BytesIO(bytes.fromhex(raw)))
            msg.headers.append(header)
        callback.send_message(msg)
        barrier()
        return dict(headers=len(msg.headers))
    if op == 'send_dsdetected':
        raw = bytes.fromhex(request['hex'])
        message = m.msg_dsdetected()
        message.deserialize(io.BytesIO(raw))
        callback.send_message(message)
        barrier()
        return dict(sent=message.serialize().hex(), same_bytes=message.serialize() == raw)
    if op == 'send_inv':
        kind = {'tx': m.CInv.TX, 'block': m.CInv.BLOCK}[request['kind']]
        callback.send_message(m.msg_inv([m.CInv(kind, int(request['hash'], 16))]))
        barrier()
        return dict(announced=request['hash'])
    # [D] 2026-10-15 (#79, lane s7-79): ask for a block as a compact block
    # (getdata MSG_CMPCT_BLOCK) or whole, and for some of its transactions
    # (getblocktxn, absolute indices, differentially encoded by the framework).
    # [SRC] mininode.py:384-398,1117-1150,1899-1930 at PIN.
    if op == 'getdata':
        kind = {'cmpct': m.CInv.COMPACT_BLOCK, 'block': m.CInv.BLOCK}[request['kind']]
        callback.send_message(m.msg_getdata([m.CInv(kind, int(request['hash'], 16))]))
        barrier()
        return dict(requested=request['hash'], kind=request['kind'])
    if op == 'getblocktxn':
        msg = m.msg_getblocktxn()
        msg.block_txn_request = m.BlockTransactionsRequest(int(request['hash'], 16))
        msg.block_txn_request.from_absolute([int(i) for i in request['indices']])
        callback.send_message(msg)
        barrier()
        return dict(requested=request['hash'], indices=request['indices'])
    if op in ('withhold', 'release'):
        h = request['hash']
        if op == 'withhold':
            callback.withheld.add(h)
        else:
            callback.withheld.discard(h)
            if h in callback.requests and h in callback.objects:
                callback.send_message(callback.objects[h])
        return dict(hash=h, withheld=h in callback.withheld)
    if op == 'expect':
        kind = request['kind']
        if kind not in ('getdata', 'inv', 'reject', 'dsdetected', 'none', 'cmpctblock', 'blocktxn', 'block'):
            raise ValueError('unknown expectation')
        since = int(request.get('since', 0))
        deadline = time.monotonic() + min(20, max(0, float(request['timeout'])))
        while True:
            with lock:
                # [D] 2026-10-15 (#80): an empty hash matches any (the dsdetected expectation names none)
                found = [e for e in events[since:] if matching(e, kind, request.get('hash') or None)]
            if found or time.monotonic() >= deadline:
                return dict(matched=(not found if kind == 'none' else bool(found)), observations=found)
            if not callback.connected:
                raise RuntimeError('peer disconnected during expectation')
            time.sleep(0.02)
    if op == 'close':
        handler.close()
        network.join(timeout=5)
        if network.is_alive():
            raise RuntimeError('network thread did not stop')
        return dict(closed=True)
    raise ValueError('unknown step')

try:
    for raw in sys.stdin:
        request = json.loads(raw)
        log('step-in', step=request)
        try:
            result = step(request)
            response = dict(ok=True, result=result)
        except Exception as error:
            response = dict(ok=False, error=str(error))
        log('step-out', response=response)
        with lock:
            response.update(source_pin=sha, events=events[cursor:], next_index=len(events))
            cursor = len(events)
        print(json.dumps(response), flush=True)
        if request['op'] == 'close' or not response['ok']:
            break
finally:
    if handler is not None:
        handler.close()
    if network is not None:
        network.join(timeout=5)
    receipt.close()
