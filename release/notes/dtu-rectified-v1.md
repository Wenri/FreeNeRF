# DTU MVS — Rectified images (mirror)

A convenience mirror of the DTU multi-view-stereo *Rectified* images used by
FreeNeRF (`data/Rectified/`, 124 scans). Whole scans are bundled into the fewest
tar archives that each stay under GitHub's 2 GiB asset limit; **no file is
byte-split** and every `.tar` extracts on its own. See `*.manifest.txt` for which
scans live in which archive, so individual scans can be fetched without
downloading everything.

## Attribution & license
This is **third-party data** from the DTU Multi-View Stereo dataset (Aanæs et
al., Technical University of Denmark), redistributed here only for convenience /
reproducibility. All rights and the original license remain with the dataset
authors. Prefer the official source and cite the DTU MVS dataset:
- DTU MVS: https://roboimagedata.compute.dtu.dk/
- Data preparation follows RegNeRF: https://github.com/google-research/google-research/tree/master/regnerf

## Download & restore (into ./data)
```
release/fetch.sh dtu-rectified-v1 data
```
