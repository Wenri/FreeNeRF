# FreeNeRF pre-trained models & rendered outputs

Trained Flax checkpoints and rendered test views for FreeNeRF on DTU (3-view
setting), plus a small experimental run and W&B logs. This mirrors the local
`out/` and `wandb/` directories.

**Contents** (extract into the repo root):
- `out/dtu3-end-0.9/<scan>/checkpoint_43945` — Flax checkpoint per DTU scan
- `out/dtu3-end-0.9/<scan>/test_preds/` — rendered test images
- `out/dtu3-end-0.9/<scan>/config.gin` — exact training config
- `out/myexp/`, `wandb/` — misc run artifacts / logs

## Download & restore
```
release/fetch.sh pretrained-models-v1 .
```
Manual: download every `*.tar`, run `sha256sum -c *.tar.sha256`, then
`tar -xf <file>.tar -C .`. Each `.tar` is a complete, independently-extractable
archive — no byte-splitting, no reassembly step.
