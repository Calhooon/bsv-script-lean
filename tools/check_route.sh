#!/usr/bin/env bash
# tools/check_route.sh (bsv-script-lean, S3 the harness, 2026-09-24):
# `make check` routes itself under D17b's regime as D156 amended it (D17b, the owner, 2026-09-24 02:11 UTC,
# the owner's hosts page: a tripwire runs locally when the 1-minute load is under 20, with the sampler in the record;
# D156, 2026-09-28: above it ON THE BOX, and on Modal only when MAKE_CHECK=modal; byte-identical verdict lines on every
# home, the walls and the interpreter differing by host).
#   MAKE_CHECK=local   the twenty-nine legs on this machine (`make check-local` = tools/check.sh all; the record
#                      docs/records/<stamp>-make-check.txt, the load sampled every 10 s)
#   MAKE_CHECK=modal   the same legs in a container on Modal (tools/modal_check.py, profile <modal-name>; the cost discipline
#                      in that file; the record docs/records/<stamp>-make-check-modal.txt written by the same writer)
#   MAKE_CHECK=box     the same legs ON THE BOX (tools/check_box.sh, from the Studio over ssh; the record
#                      docs/records/<stamp>-make-check-box.txt, brought home); D156's default for a leg of record
#   unset              local when the 1-minute load is under 20 (or on the box itself), else THE BOX (D156, the owner,
#                      2026-09-28 18:5x UTC: "Modal only when we have to, when it's blocking"; RULES-TREE (27))
# MODAL ONLY WHEN IT BLOCKS (D156): MAKE_CHECK=modal launches only with MODAL_WHY set, the block's reason ("the box cannot hold
# it: <peak>" or "the box's queue: <wait>"), and then only past D155's gate below.
# The node oracle's runner (run_svnode) is not a leg of `make check` and the built node never enters the container: the
# pins leg SKIPS the clones and the binary BY NAME there (tools/check_pins.py), never a pass.
# THE DAILY MODAL CAP (D155, the owner, 2026-09-28 16:4x UTC; RULES-TREE (26)): before the Modal route launches anything,
# the plan's tools/modal_day.py reads today's meter [M]. OPEN (under $80 of the day's $100) launches; NEAR THE CAP ($80 to
# $100) launches only a run the caller's block already prices, asserted by MODAL_PRICED='<where the block prices it>'; CLOSED
# (at $100) launches no new app without the owner's word; a meter that does not answer, or no tool, launches nothing. The
# gate stands here, before `modal run`, because the app and its images are made before any entrypoint code runs.
# CHECK_ROUTE_DRY=1 prints the route and the gate's verdict and launches nothing (the gate's own test).
# Every script it starts runs under `/usr/bin/env -u BASH_ENV /bin/bash --noprofile --norc` (RULES-TREE (28); the shells by absolute
# path, continue 33: a bare `env` or `bash` is whatever the caller's PATH puts first).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOAD="$(uptime | sed -E 's/.*load averages?: *([0-9.]+).*/\1/')"
MODE="${MAKE_CHECK:-auto}"
if [ "$MODE" = auto ]; then
  if [ "${LOAD%.*}" -lt 20 ] || [ "$(hostname -s)" = box ]; then MODE=local; else MODE=box; fi
fi
case "$MODE" in
  local) echo "check: LOCAL (1-minute load $LOAD on $(hostname -s); tools/check.sh all with the sampler)"
    [ -n "${CHECK_ROUTE_DRY:-}" ] && { echo "check_route: DRY, nothing run"; exit 0; }
    exec /usr/bin/env -u BASH_ENV /bin/bash --noprofile --norc "$ROOT/tools/check.sh" all ;;
  box) [ -n "${CHECK_ROUTE_DRY:-}" ] && { echo "check: BOX (1-minute load $LOAD); check_route: DRY, nothing run"; exit 0; }
    exec /usr/bin/env -u BASH_ENV /bin/bash --noprofile --norc "$ROOT/tools/check_box.sh" ;;
  modal) echo "check: MODAL (1-minute load $LOAD; tools/modal_check.py, cpu 16 / 32 GiB, retries 0, ≤ \$1.35 a check)"
    [ -n "${MODAL_WHY:-}" ] || { echo "check_route: MODAL ONLY WHEN IT BLOCKS (D156): set MODAL_WHY='the box cannot hold it: <peak>' or 'the box's queue: <wait>', or run MAKE_CHECK=box"; exit 3; }
    echo "check_route: why Modal (D156): $MODAL_WHY"
    # the meter's path: MODAL_DAY_TOOL, else the one the owner's host file names (withheld from the public edition, #46)
    [ -n "${MODAL_DAY_TOOL:-}" ] || { [ -f "$ROOT/tools/host_private.sh" ] && . "$ROOT/tools/host_private.sh"; MODAL_DAY_TOOL="${MODAL_DAY_PY:-tools/host_private.sh names no MODAL_DAY_PY}"; }
    DAY="$MODAL_DAY_TOOL"
    [ -f "$DAY" ] || { echo "check_route: $DAY is absent: no Modal launch without the day's meter (D155)"; exit 3; }
    RC=0; LINE="$(MODAL_PROFILE=<modal-name> python3 "$DAY" 2>&1)" || RC=$?
    echo "$LINE"
    case "$RC" in
      0) if printf '%s' "$LINE" | grep -q "NEAR THE CAP"; then
           [ -n "${MODAL_PRICED:-}" ] || { echo "check_route: NEAR THE CAP (D155): launch only what your block prices; rerun with MODAL_PRICED='<where your block prices this run>', or run make check-local under a load of 20"; exit 3; }
           echo "check_route: NEAR THE CAP; priced by the caller's block: $MODAL_PRICED"
         fi ;;
      1) echo "check_route: the Modal day is CLOSED (D155): no new app without the owner's word (ask the owner's plan with the figures)"; exit 3 ;;
      *) echo "check_route: the meter did not answer (modal_day.py rc $RC): no Modal launch (D155)"; exit 3 ;;
    esac
    [ -n "${CHECK_ROUTE_DRY:-}" ] && { echo "check_route: DRY, the gate passed, nothing launched"; exit 0; }
    # THE BUILDER'S DEATH (#56, 2026-10-06 10:55 UTC): the image build's step can die on Modal's builder with no exception
    # from the bake; the client then prints `ImageBuildError('Image build for im-… failed.\nView the build logs: …')` (a bake
    # that raises prints `failed with the exception:` instead, and stands). On that exact shape the run is launched ONCE
    # more after the day's meter is read again, both apps in the output; a second failure stands as the verdict. The
    # function's own retries stay 0 (tools/modal_check.py).
    OUT="$(mktemp)"; attempt=1
    while :; do
      RC=0; /usr/bin/env MODAL_PROFILE=<modal-name> modal run "$ROOT/tools/modal_check.py::check" 2>&1 | tee "$OUT" || RC=$?
      if [ "$RC" -ne 0 ] && [ "$attempt" -eq 1 ] && grep -q "ImageBuildError" "$OUT" && grep -q "View the build logs" "$OUT" \
         && ! grep -q "failed with the exception" "$OUT"; then
        echo "check_route: the image build's step died on Modal's builder with no exception from the bake (#56): one re-launch after the meter"
        RC2=0; LINE="$(MODAL_PROFILE=<modal-name> python3 "$DAY" 2>&1)" || RC2=$?
        echo "$LINE"
        if [ "$RC2" -ne 0 ]; then echo "check_route: the meter did not answer OPEN (rc $RC2): no re-launch (D155)"; rm -f "$OUT"; exit 3; fi
        if printf '%s' "$LINE" | grep -q "NEAR THE CAP" && [ -z "${MODAL_PRICED:-}" ]; then
          echo "check_route: NEAR THE CAP (D155): no re-launch without MODAL_PRICED"; rm -f "$OUT"; exit 3
        fi
        attempt=2; continue
      fi
      rm -f "$OUT"; exit "$RC"
    done ;;
  *) echo "check_route: MAKE_CHECK must be local, box, modal or unset"; exit 2 ;;
esac
