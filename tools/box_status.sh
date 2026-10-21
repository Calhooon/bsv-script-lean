#!/usr/bin/env bash
# tools/box_status.sh (bsv-script-lean #116, S3, lane gate-116, 2026-10-18): THE BOX'S HALF OF THE HOSTED GATE.
# The hosted gate (.github/workflows/gate.yml) runs every leg a public runner can run and skips by name what needs the
# box (tools/withheld_legs.txt). This script posts the box's verdict on those rows as the commit status
# `box/withheld-legs`, the required status the branch protection names beside the hosted jobs:
#   1. the record: a tripwire record written on the box by tools/check.sh (`make check-local` on the box, or
#      tools/check_box.sh's record brought home as <stamp>-make-check-box.txt); the newest of either when none is named;
#   2. the commit: the record's `commit:` line, resolved to its full sha in this checkout (the status goes on that sha,
#      never on another tree's);
#   3. the judgement: tools/withheld_legs.py --judge: `success` when the record is GREEN on host box and every withheld
#      row the tripwire covers has its verdict lines (none skipped on the box), else `failure`; the description names the
#      verdict and the record's file name, so a stranger's red names the file to ask for;
#   4. the post: `gh api repos/<owner>/<repo>/statuses/<sha>` under the token gh holds (repo:status), never written to a
#      file; the owner and repository from --repo, else BOX_STATUS_REPO, else this checkout's `origin` (the flip day's
#      public names once origin points there);
#   5. its own record: docs/records/<stamp>-box-status-s3.md: the tripwire record, the commit, every row's line from the
#      judge (the withheld legs it ran, the ones on demand), and the API's reply (id, state, context, created_at).
# Usage: tools/box_status.sh [--repo OWNER/REPO] [--record docs/records/<stamp>-make-check[-box].txt] [--dry-run]
#   --dry-run judges and prints the request; posts nothing and writes no record.
# Exit: 0 posted (whatever the state), 1 the judge said RED (posted as failure), 2 a setup stop (nothing posted).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${BOX_STATUS_REPO:-}"; REC=; DRY=
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --record) REC="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "box_status: unknown argument $1"; exit 2 ;;
  esac
done
CONTEXT="box/withheld-legs"
if [ -z "$REPO" ]; then
  url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  REPO="$(printf '%s' "$url" | sed -nE 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+)$#\2#p' | sed 's/\.git$//')"
  [ -n "$REPO" ] || { echo "box_status: no --repo and origin ($url) names no GitHub repository"; exit 2; }
fi
if [ -z "$REC" ]; then
  # the newest tripwire record whose host line is the box (a local run on the box or check_box.sh's copy)
  REC="$(grep -l '^host: box;' "$ROOT"/docs/records/*-make-check.txt "$ROOT"/docs/records/*-make-check-box.txt 2>/dev/null | sort | tail -1 || true)"
  [ -n "$REC" ] || { echo "box_status: no tripwire record of the box under docs/records/"; exit 2; }
fi
[ -f "$REC" ] || { echo "box_status: $REC is absent"; exit 2; }
NAME="$(basename "$REC")"
SHORT="$(sed -n 's/^commit: \([0-9a-f]*\).*/\1/p' "$REC" | head -1)"
[ -n "$SHORT" ] || { echo "box_status: $NAME names no commit"; exit 2; }
SHA="$(git -C "$ROOT" rev-parse --verify --quiet "$SHORT^{commit}")" || { echo "box_status: the record's commit $SHORT is not in this checkout (fetch it)"; exit 2; }
JUDGE="$(python3 "$ROOT/tools/withheld_legs.py" --judge "$REC")" && JRC=0 || JRC=$?
echo "$JUDGE"
if [ "$JRC" = 0 ]; then STATE=success; WORD=GREEN; else STATE=failure; WORD=RED; fi
RAN="$(printf '%s\n' "$JUDGE" | grep -c ': ran$' || true)"
DEMAND="$(printf '%s\n' "$JUDGE" | grep -c ': on-demand' || true)"
DESC="$WORD: $NAME; $RAN withheld legs read on the box, $DEMAND on demand"
DESC="${DESC:0:140}"
echo "box_status: $STATE on $REPO@${SHA:0:12} as $CONTEXT: $DESC"
if [ -n "$DRY" ]; then echo "box_status: DRY, nothing posted"; exit 0; fi
REPLY="$(gh api -X POST "repos/$REPO/statuses/$SHA" -f state="$STATE" -f context="$CONTEXT" -f description="$DESC" \
  --jq '"id \(.id), state \(.state), context \(.context), created_at \(.created_at), creator \(.creator.login)"')" \
  || { echo "box_status: the API refused the post (gh api above)"; exit 2; }
echo "box_status: the API's reply: $REPLY"
STAMP="$(date -u +%Y%m%d-%H%M%S)"; OUT="$ROOT/docs/records/$STAMP-box-status-s3.md"
{
  echo "# The box's status on $REPO@${SHA:0:12} (tools/box_status.sh, #116)"
  echo
  echo "[M] $(date -u '+%Y-%m-%d %H:%M:%S') UTC on $(hostname -s). The tripwire record \`docs/records/$NAME\` names commit \`$SHORT\` = \`$SHA\`."
  echo "The status \`$CONTEXT\` posted as \`$STATE\` with the description \`$DESC\`."
  echo
  echo "The withheld legs (tools/withheld_legs.py --judge, tools/withheld_legs.txt):"
  echo
  echo '```'
  printf '%s\n' "$JUDGE"
  echo '```'
  echo
  echo "The API's reply (POST repos/$REPO/statuses/<sha>): $REPLY"
} > "$OUT"
echo "box_status: the record ${OUT#$ROOT/}"
exit "$JRC"
