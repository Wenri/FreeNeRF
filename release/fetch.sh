#!/usr/bin/env bash
# Restore a release published by publish.sh: download every .tar + .sha256,
# verify checksums, then extract. Each .tar is a complete, independent archive
# (no byte-splitting), so extraction is just plain `tar -xf` per file.
#
# Usage: release/fetch.sh <tag> [dest_dir=.]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
[ $# -ge 1 ] || { echo "usage: $0 <tag> [dest_dir]" >&2; exit 2; }
TAG="$1"; DEST="$(cd "${2:-.}" && pwd)"
# Target the fork explicitly via the `origin` URL (gh defaults a fork to its parent).
REPO="${REPO:-$(git -C "$ROOT" remote get-url origin | sed -E 's#(git@|https://)github\.com[:/]##; s#\.git$##')}"
TMP="$ROOT/release_build/dl/$TAG"; mkdir -p "$TMP"

echo ">> downloading $TAG assets from $REPO ..."
gh release download "$TAG" --repo "$REPO" --dir "$TMP" --clobber

echo ">> verifying checksums ..."
( cd "$TMP" && for s in *.tar.sha256; do sha256sum -c "$s"; done )

echo ">> extracting into $DEST ..."
for t in "$TMP"/*.tar; do
  echo "   $(basename "$t")"
  tar -xf "$t" -C "$DEST"
done
echo ">> done: $TAG restored under $DEST"
