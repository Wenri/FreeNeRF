#!/usr/bin/env bash
# Package items into the fewest tar archives that each stay under GitHub's
# 2 GiB release-asset limit -- WITHOUT byte-splitting any file -- then checksum
# and upload them as a GitHub Release on the `origin` repo.
#
# Usage:  release/publish.sh <tag> <title> <base_dir> <item> [<item>...]
#         <item> paths are relative to <base_dir>.
# Env:    SKIP_EXISTING=1  skip groups whose .tar asset already exists (resume)
#         CAP_MIB=1900     per-archive size cap, in MiB
set -euo pipefail

CAP_MIB="${CAP_MIB:-2000}"   # per-archive cap in MiB; < 2 GiB (2048) GitHub asset limit
SKIP_EXISTING="${SKIP_EXISTING:-0}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

[ $# -ge 4 ] || { echo "usage: $0 <tag> <title> <base_dir> <item>..." >&2; exit 2; }
TAG="$1"; TITLE="$2"; BASE="$(cd "$3" && pwd)"; shift 3
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
WORK="$ROOT/release_build/$TAG"
mkdir -p "$WORK/lists"

echo ">> [$TAG] planning groups (cap ${CAP_MIB}MiB) ..."
NBINS="$(python3 "$HERE/binpack.py" --base "$BASE" --cap-mib "$CAP_MIB" \
          --outdir "$WORK/lists" "$@")"
echo ">> [$TAG] $NBINS archive(s) -> repo $REPO"

if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  notes="$HERE/notes/$TAG.md"; [ -f "$notes" ] || notes=/dev/null
  gh release create "$TAG" --repo "$REPO" --title "$TITLE" --notes-file "$notes"
fi

existing=""
if [ "$SKIP_EXISTING" = 1 ]; then
  existing="$(gh release view "$TAG" --repo "$REPO" --json assets -q '.assets[].name' || true)"
fi

manifest="$WORK/$TAG.manifest.txt"; : > "$manifest"
for lst in "$WORK"/lists/group-*.lst; do
  idx="$(basename "$lst" .lst | sed 's/group-//')"
  asset="${TAG}-${idx}.tar"
  { echo "== $asset =="; tr '\0' '\n' < "$lst"; echo; } >> "$manifest"

  if [ "$SKIP_EXISTING" = 1 ] \
       && grep -qx "$asset" <<<"$existing" \
       && grep -qx "${asset}.sha256" <<<"$existing"; then
    echo ">> [$idx] $asset already uploaded, skipping"
    continue
  fi

  n="$(tr -cd '\0' < "$lst" | wc -c)"
  echo ">> [$idx] tar $n item(s) -> $asset"
  tar --null -T "$lst" -C "$BASE" \
      --exclude='.DS_Store' --exclude='__pycache__' --exclude='.ipynb_checkpoints' \
      -cf "$WORK/$asset"
  ( cd "$WORK" && sha256sum "$asset" > "${asset}.sha256" )
  echo ">> [$idx] upload $(du -h "$WORK/$asset" | cut -f1) ..."
  gh release upload "$TAG" "$WORK/$asset" "$WORK/${asset}.sha256" --repo "$REPO" --clobber
  rm -f "$WORK/$asset"            # cap scratch usage; checksum stays for resume
done

gh release upload "$TAG" "$manifest" --repo "$REPO" --clobber
echo ">> [$TAG] done: $NBINS archive(s) on $REPO"
