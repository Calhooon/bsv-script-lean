#!/usr/bin/env bash
# harness/engines/gobdk/build.sh (bsv-script-lean #28, the ruling D14): build the GoBDK shim from the pinned module,
# never from the network, into harness/target/engines/gobdk-runner (GOBDK_OUT overrides).
#
# (1) the clone docs/PROVENANCE.md §1a names (`gobdk.clone`, GOBDK_CLONE overrides) is at `gobdk.commit` with
#     module/gobdk clean; (2) every prebuilt archive under module/gobdk/bdkcgo is the commit's own blob; (3) the
#     clone's module/gobdk hashes to the two sums of this module's go.sum, which are Teranode v0.16.0's
#     (`git show v0.16.0:go.sum`, lines 108–109; v0.15.9's lines 156–157 until #54, 2026-10-06): the directory built is byte for byte the module Teranode links;
#     (4) `go build` through a temporary go.work that replaces the module by the clone, GOPROXY=off GOSUMDB=off
#     (no network); (5) the binary's `--version` names the pin's prefix and the SV-node commit GoBDK embeds, §1a's
#     `gobdk.reference_commit` (not `reference.commit`: the spec's reference moved to v1.2.3, GoBDK links v1.2.2;
#     #151) as far as the linked library's version block carries it: CGO_BSV_GIT_COMMIT_HASH
#     (bdkcgo/version_cgo.h:22) holds the 9-hex prefix `879fc8b42`, not the 40-hex commit (read by linking,
#     2026-09-26, and again at 4eab3acd by #54); `--selftest` checks the cited code table against the linked library.
#     The clone is GOBDK_CLONE when set (the box keeps it under ~/bsv/targets/spec-54/bdk), else `gobdk.clone`. The shim is built and run
#     on the Studio and the box; no leg of the tripwire builds or runs it, and it never enters the tripwire's
#     container (tools/modal_check.py); modal_teranode.py builds it inside the official Teranode x86-64 image on
#     Modal for a row (#32's F1).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
PINS="$ROOT/docs/PROVENANCE.md"
die() { echo "gobdk build: $*" >&2; exit 1; }
pin() { awk -v k="$1" '/^```pins/{on=1;next} /^```/{on=0} on && $1==k {print $3; exit}' "$PINS"; }

COMMIT="$(pin gobdk.commit)"; REF="$(pin gobdk.reference_commit)"; CLONE_PIN="$(pin gobdk.clone)"
[ -n "$COMMIT" ] && [ -n "$REF" ] && [ -n "$CLONE_PIN" ] || die "docs/PROVENANCE.md §1a lacks gobdk.commit, gobdk.clone or gobdk.reference_commit"
CLONE="${GOBDK_CLONE:-${CLONE_PIN/#\~/$HOME}}"
MOD="$CLONE/module/gobdk"
OUT="${GOBDK_OUT:-$ROOT/harness/target/engines/gobdk-runner}"

# (1) the clone at the pin, module/gobdk clean
head="$(git -C "$CLONE" rev-parse HEAD)" || die "no clone at $CLONE"
[ "$head" = "$COMMIT" ] || die "$CLONE is at $head, the pin is $COMMIT (docs/PROVENANCE.md §1a)"
[ -z "$(git -C "$CLONE" status --porcelain --untracked-files=all -- module/gobdk)" ] || die "$MOD differs from the commit (git status)"
echo "gobdk build: (1) $CLONE at $COMMIT, module/gobdk clean"

# (2) the prebuilt archives are the commit's blobs
for a in "$MOD"/bdkcgo/libGoBDK_*.a; do
  rel="module/gobdk/bdkcgo/$(basename "$a")"
  [ "$(git -C "$CLONE" hash-object "$a")" = "$(git -C "$CLONE" rev-parse "$COMMIT:$rel")" ] || die "$rel is not the commit's blob"
done
echo "gobdk build: (2) the $(ls "$MOD"/bdkcgo/libGoBDK_*.a | wc -l | tr -d ' ') prebuilt archives are the commit's blobs"

# (3) the module's h1 sums (the Go module zip's dirhash: SHA-256 over the sorted `<sha256>  <module@version/path>` lines)
VERSION="$(awk '$1=="require" && $2=="github.com/bitcoin-sv/bdk/module/gobdk" {print $3}' "$HERE/go.mod")"
[ -n "$VERSION" ] || die "go.mod has no require line for the module"
python3 - "$CLONE" "$COMMIT" "$VERSION" "$HERE/go.sum" <<'PY' || die "(3) the module sums differ"
import base64, hashlib, subprocess, sys
clone, commit, version, gosum = sys.argv[1:5]
path = "github.com/bitcoin-sv/bdk/module/gobdk"
files = subprocess.run(["git", "-C", clone, "ls-tree", "-r", "--name-only", commit, "module/gobdk/"], capture_output=True, text=True, check=True).stdout.split()
def blob(f):
    return subprocess.run(["git", "-C", clone, "show", f"{commit}:{f}"], capture_output=True, check=True).stdout
def h1(lines):
    return "h1:" + base64.b64encode(hashlib.sha256("".join(f"{h}  {n}\n" for n, h in sorted(lines)).encode()).digest()).decode()
zip_h1 = h1([(f"{path}@{version}/{f[len('module/gobdk/'):]}", hashlib.sha256(blob(f)).hexdigest()) for f in files])
mod_h1 = h1([("go.mod", hashlib.sha256(blob("module/gobdk/go.mod")).hexdigest())])
want = {}
for line in open(gosum):
    m, v, h = line.split()
    want[v] = h
ok = want.get(version) == zip_h1 and want.get(version + "/go.mod") == mod_h1
print(f"gobdk build: (3) module/gobdk at the commit hashes to {zip_h1} and go.mod to {mod_h1}: {'the go.sum sums (Teranode v0.16.0 go.sum:108-109)' if ok else 'NOT the go.sum sums'}")
sys.exit(0 if ok else 1)
PY

# (4) build through a temporary workspace that replaces the module by the clone; no network
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/go.work" <<EOF
go 1.26.0

use $HERE

replace github.com/bitcoin-sv/bdk/module/gobdk $VERSION => $MOD
EOF
mkdir -p "$(dirname "$OUT")"
( cd "$HERE" && GOWORK="$TMP/go.work" GOPROXY=off GOSUMDB=off GOFLAGS=-mod=readonly CGO_ENABLED=1 go build -o "$OUT" . ) || die "(4) go build failed"
echo "gobdk build: (4) built $OUT ($(go version | awk '{print $3, $4}'))"

# (5) the binary names the pins and its table agrees with the linked library
V="$("$OUT" --version)"
case " $V " in *" ${REF:0:9} "*) ;; *) die "(5) the linked library does not name gobdk.reference_commit ${REF:0:9} (of $REF): $V" ;; esac
case " $V " in *" ${COMMIT:0:8} "*) ;; *) die "(5) the banner does not name the pin ${COMMIT:0:8}: $V" ;; esac
"$OUT" --selftest
echo "gobdk build: (5) $V"
