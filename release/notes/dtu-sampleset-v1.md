# DTU MVS — SampleSet / evaluation data (mirror)

Mirror of `data/SampleSet/` (DTU MVS SampleSet: cleaned models, point clouds,
surfaces, calibration, observation masks, and the Matlab evaluation code). The
on-disk top folder is `MVSData` (renamed from the archive's original `MVS Data`,
no space, to keep tooling/paths simple). Whole subdirectories are bundled into
the fewest tar archives under GitHub's 2 GiB asset limit; **no file is
byte-split** and every `.tar` extracts on its own.

## Attribution & license
**Third-party data** from the DTU Multi-View Stereo dataset (Aanæs et al.,
Technical University of Denmark), redistributed for convenience / reproducibility
only. All rights and the original license remain with the dataset authors.
- DTU MVS: https://roboimagedata.compute.dtu.dk/
- Data preparation follows RegNeRF: https://github.com/google-research/google-research/tree/master/regnerf

## Download & restore (into ./data)
```
release/fetch.sh dtu-sampleset-v1 data
```
