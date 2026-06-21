#!/usr/bin/env python3
"""Group a dataset's contents into the fewest tar archives under a byte cap,
WITHOUT ever byte-splitting a file.

Strategy: each item (starting from the given top-level items) is atomic. If an
item is a directory larger than the cap, descend into its children and recurse,
so only whole files/scenes are ever grouped. A single regular file larger than
the cap is fatal (we never byte-split). The atomic items are then packed with
first-fit-decreasing into the fewest bins, each <= cap.

For each bin it writes a NUL-delimited file list (paths relative to --base),
ready for:  tar --null -T group-NNN.lst -C <base> -cf archive.tar

Usage:
  binpack.py --base <parent> --cap-mib 1900 --outdir <dir> <item> [<item>...]
Items are paths relative to --base (e.g. 'Rectified', 'out/myexp', 'wandb').
Prints the number of bins to stdout; a human summary goes to stderr.
"""
import argparse
import os
import sys

EXCLUDE_NAMES = {'.DS_Store', '__pycache__', '.ipynb_checkpoints'}


def dir_size(path):
    """Sum of regular-file sizes under path (symlinks counted as 0)."""
    total = 0
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_NAMES]
        for f in files:
            if f in EXCLUDE_NAMES:
                continue
            fp = os.path.join(root, f)
            if os.path.islink(fp):
                continue
            try:
                total += os.path.getsize(fp)
            except OSError:
                pass
    return total


def collect(base, rel, cap, out):
    """Append (rel, size) atomic items under base/rel, descending dirs > cap."""
    name = os.path.basename(rel)
    if name in EXCLUDE_NAMES:
        return
    full = os.path.join(base, rel)
    if not os.path.exists(full):
        sys.exit(f"FATAL: item does not exist: {full}")
    if os.path.islink(full) or os.path.isfile(full):
        size = 0 if os.path.islink(full) else os.path.getsize(full)
        if size > cap:
            sys.exit(f"FATAL: single file exceeds cap and cannot be split "
                     f"without byte-splitting: {rel} ({size} bytes)")
        out.append((rel, size))
        return
    # directory
    size = dir_size(full)
    if size <= cap:
        out.append((rel, size))
        return
    for child in sorted(os.listdir(full)):
        if child in EXCLUDE_NAMES:
            continue
        collect(base, os.path.join(rel, child), cap, out)


def first_fit_decreasing(items, cap):
    """items: list of (rel, size) -> list of [used, [rel, ...]]."""
    bins = []
    for rel, size in sorted(items, key=lambda x: -x[1]):
        for b in bins:
            if b[0] + size <= cap:
                b[0] += size
                b[1].append(rel)
                break
        else:
            bins.append([size, [rel]])
    return bins


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--base', required=True, help='parent dir the items are relative to')
    ap.add_argument('--cap-mib', type=int, default=2000)  # < 2 GiB (2048) with margin for tar overhead
    ap.add_argument('--outdir', required=True)
    ap.add_argument('items', nargs='+')
    a = ap.parse_args()

    cap = a.cap_mib * 1024 * 1024
    atoms = []
    for item in a.items:
        collect(a.base, item.rstrip('/'), cap, atoms)

    bins = first_fit_decreasing(atoms, cap)

    os.makedirs(a.outdir, exist_ok=True)
    for f in os.listdir(a.outdir):
        if f.startswith('group-') and f.endswith('.lst'):
            os.remove(os.path.join(a.outdir, f))

    gib = float(1 << 30)
    with open(os.path.join(a.outdir, 'manifest.tsv'), 'w') as mf:
        for i, (used, rels) in enumerate(bins):
            with open(os.path.join(a.outdir, f"group-{i:03d}.lst"), 'wb') as fh:
                for r in rels:
                    fh.write(r.encode() + b'\0')
            for r in rels:
                mf.write(f"{i:03d}\t{used}\t{r}\n")

    total = sum(s for _, s in atoms)
    sys.stderr.write(f"[binpack] items={len(atoms)} archives={len(bins)} "
                     f"total={total / gib:.2f}GiB cap={a.cap_mib}MiB\n")
    for i, (used, rels) in enumerate(bins):
        sys.stderr.write(f"  group-{i:03d}: {used / gib:.2f}GiB  {len(rels)} item(s)"
                         f"{'  ' + rels[0] if len(rels) == 1 else ''}\n")
    print(len(bins))


if __name__ == '__main__':
    main()
