# DTU MVS — submission / calibration / scan114 (mirror)

Mirror of `data/submission_data/` (benchmark images + masks + idrmasks),
`data/Calibration/`, and `data/scan114/`. Bundled into the fewest tar archives
under GitHub's 2 GiB asset limit; **no file is byte-split** and every `.tar`
extracts on its own.

## Attribution & license
**Third-party data** derived from the DTU Multi-View Stereo dataset (Aanæs et
al., Technical University of Denmark), redistributed for convenience /
reproducibility only. All rights and the original license remain with the dataset
authors.
- DTU MVS: https://roboimagedata.compute.dtu.dk/
- Data preparation follows RegNeRF: https://github.com/google-research/google-research/tree/master/regnerf

## Download & restore (into ./data)
```
release/fetch.sh dtu-aux-v1 data
```
