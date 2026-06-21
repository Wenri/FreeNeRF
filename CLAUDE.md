# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout: two independent codebases

This repo contains **two separate NeRF implementations** of the same paper
(FreeNeRF, CVPR'23). They share no code, use different frameworks, configs, and
conda environments. Always know which one you are editing.

| | Root codebase | `DietNeRF-pytorch/` |
|---|---|---|
| Framework | **JAX / Flax** | **PyTorch** |
| Based on | RegNeRF / mip-NeRF | DietNeRF / nerf-pytorch |
| Entry points | `train.py`, `eval.py`, `render.py` | `dietnerf/run_nerf.py` |
| Datasets | DTU, LLFF, Blender | Blender (`nerf_synthetic`) only |
| Config format | gin files in `configs/` | `.txt` arg files in `dietnerf/configs/` |
| Conda env | `freenerf` (py 3.6.15) | `dietnerf` (py 3.9) |

The root `README.md` documents the JAX codebase; `DietNeRF-pytorch/README.md`
documents the PyTorch port. The JAX codebase is the primary/reference one.

## The research contribution (both codebases implement these two regularizers)

FreeNeRF adds exactly two things on top of a plain NeRF. When reasoning about
this repo, these are the core of "what FreeNeRF is":

1. **Frequency regularization** — a mask over the positional-encoding vector that
   starts revealing only low frequencies and linearly admits higher frequencies
   as training proceeds, finishing at step `freq_reg_end`. The mask is multiplied
   into the encoded inputs.
   - JAX: `get_freq_reg_mask()` in `internal/math.py`; the mask is built per-step
     in `train.py` and applied inside `internal/models.py` (`MLP.__call__`,
     applied to both point IPE and viewdir encoding).
   - PyTorch: `get_freq_mask()` in `dietnerf/utils.py`, applied in `run_nerf.py`.

2. **Occlusion regularization** — penalizes density of the first `occ_reg_range`
   samples near the camera (with an optional white/black-background prior for DTU).
   - JAX: `lossfun_occ_reg()` in `internal/math.py`, summed into the loss in `train.py`.
   - PyTorch: `--occ_reg_mult` path in `run_nerf.py`.

All of FreeNeRF's additions to the borrowed RegNeRF code are bracketed by
`## ---- ... ---- ##` comment fences in `train.py` and `internal/math.py` — grep
for those fences to find every FreeNeRF-specific change.

## Common commands

### JAX codebase (root)
```bash
conda activate freenerf
export CUDA_VISIBLE_DEVICES=0,1,2,3        # batch_size must be divisible by #devices

python train.py  --gin_configs configs/{method}/{dataset}{nshots}_{method}.gin
python eval.py   --gin_configs configs/{method}/{dataset}{nshots}_{method}.gin   # PSNR/SSIM/LPIPS on test set
python render.py --gin_configs configs/{method}/{dataset}{nshots}_{method}.gin   # camera-trajectory video

# Override any Config field without editing the gin file:
python train.py --gin_configs configs/freenerf/dtu3_freenerf.gin \
    --gin_bindings "Config.dtu_scan = 'scan30'" \
    --gin_bindings "Config.checkpoint_dir = 'out/freenerf/scan30'"
```
`method` ∈ `{freenerf, regnerf, mipnerf}`; configs exist for `dtu`/`llff` at
3/6/9 shots. End-to-end helper scripts (train then eval, looping scans):
```bash
bash sample_scripts/train_eval_dtu.sh  freenerf 3 30   # method, num_shots, scanID
bash sample_scripts/train_eval_llff.sh freenerf 3 0
bash sample_scripts/render_dtu.sh      freenerf 3 30
```
There is no test suite; "running tests" here means `eval.py` (computes metrics).

### PyTorch codebase (`DietNeRF-pytorch/`)
```bash
conda activate dietnerf
cd DietNeRF-pytorch/dietnerf

# train
CUDA_VISIBLE_DEVICES=0 python run_nerf.py \
    --config configs/freenerf_8v/freenerf_8v_50k_base05.txt \
    --datadir data/nerf_synthetic/chair --expname chair_freenerf_reg0.5
# test (append these two flags)
... --render_only --render_test
```

## Configuration (JAX codebase)

`internal/configs.py` defines a single gin-configurable `Config` dataclass holding
**every** flag (model, data, training, eval). gin files only set the fields that
differ from the dataclass defaults. Key fields worth knowing:

- `data_dir`, `dtu_mask_path`, `dtu_scan` — dataset location/selection (often
  overridden per-run via `--gin_bindings`).
- `checkpoint_dir` — where checkpoints, `config.gin`, and tensorboard logs go.
- `freq_reg` / `freq_reg_end` — enable freq reg and the step it completes
  (configs set `freq_reg_end ≈ 0.9 * max_steps`).
- `occ_reg_loss_mult`, `occ_reg_range`, `occ_wb_prior`, `occ_wb_range` — occlusion reg.
- `dataset_loader` — selects loader in `internal/datasets.py` (`'dtu'|'llff'|'blender'`).
- `use_wandb`, `entity`, `project`, `expname` — Weights & Biases logging
  (set `entity`/`project` to your own account; logging is on by default).

## JAX code map (`internal/`)
- `models.py` — `construct_mipnerf()`, `MipNerfModel`, `MLP`. A single mip-NeRF MLP
  with coarse→fine resampling and integrated positional encoding (IPE). This is
  where `freq_reg_mask` multiplies the encodings.
- `mip.py` — ray→cone casting and IPE.
- `datasets.py` — threaded `Dataset` subclasses `Blender`/`LLFF`/`DTU`; entry is
  `load_dataset(split, dir, config)`. Handles few-shot view subsetting and DTU masks.
- `math.py` — generic NeRF math **plus** the FreeNeRF add-ons (freq mask, occ reg,
  distortion loss) at the bottom of the file.
- `configs.py`, `utils.py` (`TrainState`, IO), `vis.py`, `spacing.py`.

`train.py` runs the multi-GPU loop with `jax.pmap` (axis `'batch'`) and
`flax.optim.Adam`; the total loss = RGB recon + coarse loss + weight decay +
optional depth-TV/geo reg + optional distortion loss + optional occ reg.

## Gotchas

- **The mask lengths `99` and `27` are hardcoded** in `train.py` and `eval.py`
  (`get_freq_reg_mask(99, ...)` / `(27, ...)`). They equal `(2*max_deg_point+1)*3`
  and `(2*deg_view+1)*3` for the defaults `max_deg_point=16`, `deg_view=4` in
  `MLP`. If you change those PE degrees, update these constants everywhere.
- `eval.py`/`render.py` must rebuild the freq mask at the checkpoint's step so the
  visible frequency band matches training; this is already wired when `freq_reg=True`.
- `batch_size` must be divisible by the number of visible GPUs or training raises.
- freenerf/mipnerf configs set `load_random_rays = False` (only RegNeRF needs them).
- Two conda envs / two `requirements.txt`. The root env additionally needs a
  CUDA-matched `jaxlib` installed manually (see `README.md`); `environment.yml`
  captures the full root env.
- `out/`, `data/`, `wandb/` are gitignored runtime/output dirs.
