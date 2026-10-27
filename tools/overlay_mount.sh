#!/usr/bin/env bash
# Mount the private overlay over a checkout of the public edition (THE FLIP RULE, HANDOFF.md §0: "the withheld
# paths a private overlay the harness mounts"). The overlay is a directory tools/export_overlay.py wrote (or a
# checkout of the overlay repository): the withheld whole files and the private originals of the transformed paths,
# plus OVERLAY-MANIFEST.txt. Mounting copies every overlay path over the checkout; a path the public checkout does
# not track is listed in the checkout's .git/info/exclude, a path it tracks (a transformed page whose private
# original the overlay restores) is marked skip-worktree in its index. Either way `git status` stays clean and a
# pathspec `git add` of a mounted path adds nothing to the public repository.
#
# --verify afterwards hashes EVERY tracked path of the overlay's source commit in the mounted checkout against the
# manifest and prints `overlay mount: VERIFIED <n> paths = the tree of <source-commit>` or one RED line per
# mismatch; the private repository is not needed. Without --verify the mount prints the counts only.
# --unmount reverses a mount: the tracked paths come back from the index, the untracked ones are removed, the
# exclude lines dropped.
#
# The checkout's HEAD must be the manifest's public-commit when the manifest names one; --any-public waives it
# (a later public commit under the same overlay: the verify then reports the paths that moved).
#
# Usage: tools/overlay_mount.sh <overlay-dir> <checkout> [--verify] [--any-public] [--unmount]
# Exit 0 mounted (and verified when asked); 1 a verify mismatch; 2 a refusal.
set -uo pipefail
OVERLAY="${1:-}"; CHECKOUT="${2:-}"; shift 2 2>/dev/null
VERIFY=0; ANY=0; UNMOUNT=0
for a in "$@"; do case "$a" in --verify) VERIFY=1;; --any-public) ANY=1;; --unmount) UNMOUNT=1;; *) echo "overlay_mount: unknown option $a" >&2; exit 2;; esac; done
MAN="$OVERLAY/OVERLAY-MANIFEST.txt"
[ -n "$OVERLAY" ] && [ -n "$CHECKOUT" ] || { echo "usage: tools/overlay_mount.sh <overlay-dir> <checkout> [--verify] [--any-public] [--unmount]" >&2; exit 2; }
[ -f "$MAN" ] || { echo "overlay_mount: $OVERLAY carries no OVERLAY-MANIFEST.txt" >&2; exit 2; }
git -C "$CHECKOUT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "overlay_mount: $CHECKOUT is not a git checkout" >&2; exit 2; }
SOURCE=$(awk '$1=="source-commit"{print $2; exit}' "$MAN")
PUBLIC=$(awk '$1=="public-commit"{print $2; exit}' "$MAN")
HEAD=$(git -C "$CHECKOUT" rev-parse HEAD)
if [ "$UNMOUNT" = 0 ] && [ "$PUBLIC" != "unnamed" ] && [ "$ANY" = 0 ] && [ "$HEAD" != "$PUBLIC" ]; then
  echo "overlay_mount: the checkout is at ${HEAD:0:12}, the overlay pairs with the public edition ${PUBLIC:0:12} (--any-public waives)" >&2; exit 2
fi
EXCLUDE=$(git -C "$CHECKOUT" rev-parse --path-format=absolute --git-path info/exclude)
mkdir -p "$(dirname "$EXCLUDE")"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
git -C "$CHECKOUT" ls-files > "$TMP/tracked"
# a manifest row: 64 hex, two spaces, the path, two spaces, overlay|public; every other line is a header
row() { case "$1" in [0-9a-f]*) [ "${1:64:2}" = '  ' ] && [ "${#1}" -gt 66 ];; *) false;; esac; }
: > "$TMP/skip"; : > "$TMP/untracked"
n=0
while IFS= read -r line; do
  row "$line" || continue
  where="${line##*  }"; rest="${line%  *}"; path="${rest:66}"
  [ "$where" = overlay ] || continue
  src="$OVERLAY/$path"; dst="$CHECKOUT/$path"
  if grep -qxF -- "$path" "$TMP/tracked"; then printf '%s\n' "$path" >> "$TMP/skip"; else printf '%s\n' "$path" >> "$TMP/untracked"; fi
  if [ "$UNMOUNT" = 1 ]; then
    if grep -qxF -- "$path" "$TMP/tracked"; then :; else rm -f "$dst"; fi
    n=$((n+1)); continue
  fi
  [ -e "$src" ] || [ -L "$src" ] || { echo "overlay_mount: RED the manifest names $path and the overlay lacks it" >&2; exit 2; }
  mkdir -p "$(dirname "$dst")"
  rm -f "$dst"
  if [ -L "$src" ]; then ln -s "$(readlink "$src")" "$dst"; else cp -p "$src" "$dst"; fi
  n=$((n+1))
done < "$MAN"
if [ "$UNMOUNT" = 1 ]; then
  if [ -s "$TMP/skip" ]; then
    git -C "$CHECKOUT" update-index --no-skip-worktree --stdin < "$TMP/skip"
    git -C "$CHECKOUT" checkout -- $(cat "$TMP/skip")
  fi
  if [ -f "$EXCLUDE" ] && [ -s "$TMP/untracked" ]; then
    grep -vxF -f <(sed 's|^|/|' "$TMP/untracked") "$EXCLUDE" > "$TMP/exclude" || true
    cat "$TMP/exclude" > "$EXCLUDE"
  fi
  echo "overlay unmount: $n paths of $OVERLAY taken off $CHECKOUT ($(wc -l < "$TMP/skip" | tr -d ' ') tracked restored from the index, $(wc -l < "$TMP/untracked" | tr -d ' ') untracked removed)"
  exit 0
fi
if [ -s "$TMP/skip" ]; then git -C "$CHECKOUT" update-index --skip-worktree --stdin < "$TMP/skip"; fi
while IFS= read -r path; do
  grep -qxF -- "/$path" "$EXCLUDE" 2>/dev/null || printf '/%s\n' "$path" >> "$EXCLUDE"
done < "$TMP/untracked"
echo "overlay mount: $n paths of $OVERLAY over $CHECKOUT (HEAD ${HEAD:0:12}; source ${SOURCE:0:12}): $(wc -l < "$TMP/untracked" | tr -d ' ') untracked paths listed in info/exclude, $(wc -l < "$TMP/skip" | tr -d ' ') tracked paths marked skip-worktree"
[ "$VERIFY" = 1 ] || exit 0
bad=0; total=0
while IFS= read -r line; do
  row "$line" || continue
  want="${line:0:64}"; rest="${line%  *}"; path="${rest:66}"
  total=$((total+1))
  f="$CHECKOUT/$path"
  if [ -L "$f" ]; then got=$(printf 'symlink %s' "$(readlink "$f")" | shasum -a 256 | cut -c1-64)
  elif [ -f "$f" ]; then got=$(shasum -a 256 "$f" | cut -c1-64)
  else echo "overlay mount: RED $path absent from the mounted checkout"; bad=$((bad+1)); continue; fi
  [ "$got" = "$want" ] || { echo "overlay mount: RED $path differs from the tree of ${SOURCE:0:12}"; bad=$((bad+1)); }
done < "$MAN"
if [ "$bad" = 0 ]; then echo "overlay mount: VERIFIED $total paths = the tree of $SOURCE"; exit 0; fi
echo "overlay mount: RED $bad of $total paths differ from the tree of $SOURCE"; exit 1
