#!/usr/bin/env bash
# harness/oracle/spec-node.sh: the spec's own SV-node instance for the verifyscript runner (bsv-script-lean #27).
#
# Two homes, one pinned binary (bitcoin-sv v1.2.3 at 6504a3aff, docs/PROVENANCE.md §1a; the build the sibling
# program's oracle runbook produced from the pinned tag, `bitcoind -version` = v1.2.3.0-g6504a3aff-dev, checked
# by `make check-pins` on the Studio):
#   local  the Studio: $SV_BIN (default ~/bsv/targets/sv-v1.2.3/bin/bitcoind), datadir ~/bsv/targets/spec-oracle-data,
#          RPC 127.0.0.1:18563, P2P 18564 (listen=0: nothing binds). For development and the smoke runs. The CONSENSUS
#          instance (bitcoin.conf: every policy cap zeroed): the spec's `spec` column.
#   policy the Studio's SECOND instance (2026-09-24): the same binary on bitcoin-policy.conf (the policy caps at the
#          node's defaults), datadir ~/bsv/targets/spec-oracle-policy-data, RPC 127.0.0.1:18565, P2P 18566: the
#          spec's `spec-mempool` column (run_svnode --rpc-mempool http://127.0.0.1:18565).
#   block  the Studio's THIRD instance (2026-09-26, D97): the same binary on bitcoin-block.conf (the consensus instance's
#          zeroed caps and mainnet heights) with A CHAIN the harness builds, datadir ~/bsv/targets/spec-oracle-block-data,
#          RPC 127.0.0.1:18567, P2P 18568: the block-connect road of the `tx.*` families (run_svnode --mode tx); its base
#          snapshot lives beside it (`block snapshot|restore <name>`: the datadir copied whole while the node is stopped).
#   mini   the always-on host (`ssh mini`): the same bundle at ~/bsv/oracle/bin on the mini (never modified, never
#          restarted by this script: that bundle's LaunchAgent belongs to the sibling program), run as the spec's
#          OWN LaunchAgent com.bsvspec.oracle on its OWN datadir ~/bsv/spec-oracle/data with this repo's
#          bitcoin.conf, RPC 127.0.0.1:18563 / P2P 18564 on the mini; the Studio reaches it through an SSH port
#          forward on 127.0.0.1:18663 and fetches the cookie by scp.
# Commands:  spec-node.sh local start|stop|status|cli <rpc…>|reset
#            spec-node.sh policy start|stop|status|cli <rpc…>|reset
#            spec-node.sh block start|stop|status|cli <rpc…>|reset|snapshot <name>|restore <name>|adopt-into-policy
#            spec-node.sh mini install|start|stop|status|tunnel|cookie|cli <rpc…>|uninstall
# Auth is the node's cookie (<datadir>/regtest/.cookie); no password exists in this repo. Nothing here reaches a
# peer (CLAUDE.md rule 10): the RPC is loopback on either host. The `local` and `mini` instances' chains are empty and
# stay empty; the `block` instance holds the chain the harness bakes (oracle_chain bake) and the road extends, and
# `block adopt-into-policy` copies that chain into the `policy` instance's datadir.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${SV_BIN:=$HOME/bsv/targets/sv-v1.2.3/bin/bitcoind}"
: "${SV_CLI:=$HOME/bsv/targets/sv-v1.2.3/bin/bitcoin-cli}"
: "${SPEC_ORACLE_DATADIR:=$HOME/bsv/targets/spec-oracle-data}"
: "${SPEC_ORACLE_RPC_PORT:=18563}"
: "${SPEC_ORACLE_P2P_PORT:=18564}"
: "${SPEC_ORACLE_MINI_LOCAL_PORT:=18663}"
: "${SPEC_ORACLE_POLICY_DATADIR:=$HOME/bsv/targets/spec-oracle-policy-data}"
: "${SPEC_ORACLE_POLICY_RPC_PORT:=18565}"
: "${SPEC_ORACLE_POLICY_P2P_PORT:=18566}"
: "${SPEC_ORACLE_BLOCK_DATADIR:=$HOME/bsv/targets/spec-oracle-block-data}"
: "${SPEC_ORACLE_BLOCK_RPC_PORT:=18567}"
: "${SPEC_ORACLE_BLOCK_P2P_PORT:=18568}"
: "${SPEC_ORACLE_MINI_COOKIE_DIR:=$HOME/bsv/targets/spec-oracle-mini}"
: "${MINI:=mini}"
MINI_ROOT="bsv/spec-oracle"
MINI_BIN='$HOME/bsv/oracle/bin'
LABEL=com.bsvspec.oracle
say() { echo "spec-node.sh: $*"; }

local_cli() { "$SV_CLI" -regtest -conf="$CONF" -datadir="$SPEC_ORACLE_DATADIR" -rpcport="$SPEC_ORACLE_RPC_PORT" "$@"; }
mini_cli() { ssh -o BatchMode=yes "$MINI" "$MINI_BIN/bitcoin-cli -regtest -conf=\$HOME/$MINI_ROOT/bitcoin.conf -datadir=\$HOME/$MINI_ROOT/data -rpcport=$SPEC_ORACLE_RPC_PORT $*"; }

plist() {
  local mini_home="${1:?remote home directory required}"
  cat <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$mini_home/bsv/oracle/bin/bitcoind</string>
    <string>-regtest</string>
    <string>-conf=$mini_home/$MINI_ROOT/bitcoin.conf</string>
    <string>-datadir=$mini_home/$MINI_ROOT/data</string>
    <string>-rpcport=$SPEC_ORACLE_RPC_PORT</string>
    <string>-port=$SPEC_ORACLE_P2P_PORT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$mini_home/$MINI_ROOT/log/bitcoind.out</string>
  <key>StandardErrorPath</key><string>$mini_home/$MINI_ROOT/log/bitcoind.err</string>
</dict></plist>
PL
}

mode="${1:-}"; cmd="${2:-}"; shift 2 || true
inst="$mode"
# the pinned build is a prerequisite, not part of this repo: say what is needed and stop (exit 2)
need_node() {
  [ -x "$SV_BIN" ] && [ -x "$SV_CLI" ] && return 0
  say "SETUP STOP: this needs the pinned bitcoin-sv build (tag v1.2.3, commit 6504a3aff, docs/PROVENANCE.md §1a), which is not in this repository:"
  say "  bitcoind    \$SV_BIN = $SV_BIN ($([ -x "$SV_BIN" ] && echo present || echo absent))"
  say "  bitcoin-cli \$SV_CLI = $SV_CLI ($([ -x "$SV_CLI" ] && echo present || echo absent))"
  say "build it from the public tag and set SV_BIN and SV_CLI (or install it at the default path): harness/README.md, \"Prerequisites\", sv-node"
  exit 2
}
CONF="$HERE/bitcoin.conf"
if [ "$mode" = policy ]; then
  # the policy instance: the same code path as `local` on its own conf, datadir and ports
  CONF="$HERE/bitcoin-policy.conf"; SPEC_ORACLE_DATADIR="$SPEC_ORACLE_POLICY_DATADIR"
  SPEC_ORACLE_RPC_PORT="$SPEC_ORACLE_POLICY_RPC_PORT"; SPEC_ORACLE_P2P_PORT="$SPEC_ORACLE_POLICY_P2P_PORT"
  mode=local
fi
if [ "$mode" = block ]; then
  # the block instance (D97): the same code path on its own conf, datadir and ports, plus the snapshot commands
  CONF="$HERE/bitcoin-block.conf"; SPEC_ORACLE_DATADIR="$SPEC_ORACLE_BLOCK_DATADIR"
  SPEC_ORACLE_RPC_PORT="$SPEC_ORACLE_BLOCK_RPC_PORT"; SPEC_ORACLE_P2P_PORT="$SPEC_ORACLE_BLOCK_P2P_PORT"
  case "$cmd" in
    adopt-into-policy)
      # the policy instance takes THIS instance's chain (D97: the mempool road judges the same UTXO set and tip as the
      # block road): both instances stopped, the datadir copied whole, both started (their cookies change: reconnect)
      "$HERE/spec-node.sh" policy stop >/dev/null 2>&1 || true; local_cli stop >/dev/null 2>&1 || true
      for _ in $(seq 1 60); do local_cli getblockcount >/dev/null 2>&1 || "$HERE/spec-node.sh" policy cli getblockcount >/dev/null 2>&1 || break; sleep 1; done
      sleep 2
      rm -rf "$SPEC_ORACLE_POLICY_DATADIR"; cp -R "$SPEC_ORACLE_DATADIR" "$SPEC_ORACLE_POLICY_DATADIR"
      rm -f "$SPEC_ORACLE_POLICY_DATADIR/regtest/.cookie" "$SPEC_ORACLE_POLICY_DATADIR/regtest/.lock" "$SPEC_ORACLE_POLICY_DATADIR/bitcoind.out" "$SPEC_ORACLE_POLICY_DATADIR/bitcoind.err" "$SPEC_ORACLE_POLICY_DATADIR/regtest/bitcoind.log"
      "$HERE/spec-node.sh" block start; "$HERE/spec-node.sh" policy start
      say "the policy instance adopted the block instance's chain ($(du -sh "$SPEC_ORACLE_POLICY_DATADIR" | cut -f1))"
      exit 0 ;;
    snapshot|restore)
      name="${1:?snapshot|restore <name>}"; snap="$(dirname "$SPEC_ORACLE_DATADIR")/spec-oracle-block-$name"
      if local_cli getblockcount >/dev/null 2>&1; then say "stop the block instance first (spec-node.sh block stop)"; exit 1; fi
      if [ "$cmd" = snapshot ]; then
        rm -rf "$snap"; cp -R "$SPEC_ORACLE_DATADIR" "$snap"; rm -f "$snap/regtest/.cookie" "$snap/regtest/.lock" "$snap/bitcoind.out" "$snap/bitcoind.err" "$snap/regtest/bitcoind.log"
        say "snapshot $snap ($(du -sh "$snap" | cut -f1)); its tip: restore it, start, then spec-node.sh block cli getbestblockhash (no log is kept, continue 25)"
      else
        [ -d "$snap" ] || { say "no snapshot at $snap"; exit 1; }
        rm -rf "$SPEC_ORACLE_DATADIR"; cp -R "$snap" "$SPEC_ORACLE_DATADIR"; say "restored $snap into $SPEC_ORACLE_DATADIR"
      fi
      exit 0 ;;
  esac
  mode=local
fi
case "$mode" in
  local)
    case "$cmd" in
      start)
        need_node
        if local_cli getblockcount >/dev/null 2>&1; then say "already running on 127.0.0.1:$SPEC_ORACLE_RPC_PORT"; exit 0; fi
        mkdir -p "$SPEC_ORACLE_DATADIR"
        # -daemon is refused by this build on macOS; the process is backgrounded here. Its console is DISCARDED since
        # 2026-09-28 (continue 25): the confs set printtoconsole=1, so the log that would fill <datadir>/regtest/bitcoind.log
        # goes to stdout, and stdout goes to /dev/null; stderr (a start that fails says why there) stays in bitcoind.err
        nohup "$SV_BIN" -regtest -conf="$CONF" -datadir="$SPEC_ORACLE_DATADIR" -rpcport="$SPEC_ORACLE_RPC_PORT" -port="$SPEC_ORACLE_P2P_PORT" > /dev/null 2> "$SPEC_ORACLE_DATADIR/bitcoind.err" &
        for _ in $(seq 1 60); do local_cli getblockcount >/dev/null 2>&1 && break; sleep 1; done
        local_cli getblockcount >/dev/null 2>&1 || { say "the node did not answer within 60 s; its stderr is $SPEC_ORACLE_DATADIR/bitcoind.err"; exit 1; }
        say "running: height $(local_cli getblockcount) · rpc 127.0.0.1:$SPEC_ORACLE_RPC_PORT · $(local_cli getnetworkinfo | grep -o '"subversion": "[^"]*"')"
        ;;
      stop) need_node; local_cli stop ;;
      status)
        need_node
        local_cli getblockcount >/dev/null 2>&1 || { say "SETUP STOP: no node answers on 127.0.0.1:$SPEC_ORACLE_RPC_PORT (datadir $SPEC_ORACLE_DATADIR); start it with: harness/oracle/spec-node.sh $inst start"; exit 2; }
        local_cli getblockcount; local_cli getnetworkinfo | grep -E '"version"|"subversion"'; local_cli getsettings | grep -E 'maxscriptsizepolicy|maxopsperscriptpolicy|maxscriptnumlengthpolicy|maxstackmemoryusagepolicy|maxstdtxvalidationduration' ;;
      cli) need_node; local_cli "$@" ;;
      reset) local_cli stop >/dev/null 2>&1 || true; sleep 2; rm -rf "$SPEC_ORACLE_DATADIR"; say "wiped $SPEC_ORACLE_DATADIR" ;;
      *) say "local|policy start|stop|status|cli|reset"; exit 2 ;;
    esac ;;
  mini)
    case "$cmd" in
      install)
        ssh -o BatchMode=yes "$MINI" "test -x $MINI_BIN/bitcoind" || { say "the pinned bundle is not on the mini at $MINI_BIN"; exit 1; }
        uid=$(ssh -o BatchMode=yes "$MINI" id -u)
        mini_home=$(ssh -o BatchMode=yes "$MINI" 'printf "%s" "$HOME"')
        ssh -o BatchMode=yes "$MINI" "mkdir -p ~/$MINI_ROOT/data ~/$MINI_ROOT/log ~/Library/LaunchAgents"
        scp -q "$HERE/bitcoin.conf" "$MINI:~/$MINI_ROOT/bitcoin.conf"
        plist "$mini_home" | ssh -o BatchMode=yes "$MINI" "cat > ~/Library/LaunchAgents/$LABEL.plist"
        ssh -o BatchMode=yes "$MINI" "launchctl bootout gui/$uid/$LABEL 2>/dev/null || true; launchctl bootstrap gui/$uid ~/Library/LaunchAgents/$LABEL.plist"
        for _ in $(seq 1 60); do mini_cli getblockcount >/dev/null 2>&1 && break; sleep 1; done
        say "installed on $MINI: height $(mini_cli getblockcount) · rpc 127.0.0.1:$SPEC_ORACLE_RPC_PORT there · agent $LABEL"
        ;;
      start) ssh -o BatchMode=yes "$MINI" "launchctl kickstart gui/\$(id -u)/$LABEL" ;;
      stop) mini_cli stop ;;
      status)
        ssh -o BatchMode=yes "$MINI" "launchctl print gui/\$(id -u)/$LABEL 2>/dev/null | grep -E 'state =|pid =' | tr -s ' ' | tr '\n' ' '; echo; uptime"
        echo "height $(mini_cli getblockcount)"; mini_cli getnetworkinfo | grep -E '"version"|"subversion"'
        ;;
      tunnel)
        if lsof -nP -iTCP:"$SPEC_ORACLE_MINI_LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then say "tunnel already up on 127.0.0.1:$SPEC_ORACLE_MINI_LOCAL_PORT"; exit 0; fi
        nohup ssh -o BatchMode=yes -N -L "127.0.0.1:$SPEC_ORACLE_MINI_LOCAL_PORT:127.0.0.1:$SPEC_ORACLE_RPC_PORT" "$MINI" >/dev/null 2>&1 &
        for _ in $(seq 1 20); do lsof -nP -iTCP:"$SPEC_ORACLE_MINI_LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break; sleep 0.5; done
        say "tunnel 127.0.0.1:$SPEC_ORACLE_MINI_LOCAL_PORT → $MINI:$SPEC_ORACLE_RPC_PORT"
        ;;
      cookie)
        mkdir -p "$SPEC_ORACLE_MINI_COOKIE_DIR/regtest"
        scp -q "$MINI:~/$MINI_ROOT/data/regtest/.cookie" "$SPEC_ORACLE_MINI_COOKIE_DIR/regtest/.cookie"
        say "cookie fetched to $SPEC_ORACLE_MINI_COOKIE_DIR/regtest/.cookie (it changes on every node start)"
        ;;
      cli) mini_cli "$@" ;;
      uninstall)
        ssh -o BatchMode=yes "$MINI" "launchctl bootout gui/\$(id -u)/$LABEL 2>/dev/null || true; rm -f ~/Library/LaunchAgents/$LABEL.plist; rm -rf ~/$MINI_ROOT"
        say "removed $LABEL and ~/$MINI_ROOT on $MINI"
        ;;
      *) say "mini install|start|stop|status|tunnel|cookie|cli|uninstall"; exit 2 ;;
    esac ;;
  *) say "usage: spec-node.sh local|policy|block|mini <command>"; exit 2 ;;
esac
