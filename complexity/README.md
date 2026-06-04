# complexity/

Validation experiment comparing three visual complexity metrics against human
handwriting behaviour across the Latin cursive alphabet.

The main question: does **skeleton pixel count** — the metric used in the
parent study to measure hieratic sign complexity — predict how difficult a
letter is to write, and does it do so as well as the two standard alternatives
(perimetric complexity and algorithmic complexity)?

---

## How to run

### Prerequisites

**Python** — rasterise the letter SVGs and vectorise to EPS (one-time):

```bash
pip install -r requirements.txt
python3 svg_to_tiff.py ./svgs ./tiffs --scale 4 --dpi 600
python3 compress_tiffs.py   # requires potrace on PATH
```

`svg_to_tiff.py` rasterises each SVG to a TIFF. `compress_tiffs.py` then
traces those TIFFs with [potrace](http://potrace.sourceforge.net/) to produce
vector EPS files in `eps/`. The EPS file sizes are the algorithmic complexity
proxy: potrace encodes each letterform as Bézier curves, so simpler shapes
produce sparser path descriptions and smaller files — a description-length
measure of visual complexity, equivalent to the EPS proxy used in the main
hieratic analysis (`data_prep_01_populate_sign_list.m`).

Install potrace via Homebrew: `brew install potrace`.

**MATLAB** — generate the behavioural dataset (one-time, requires network):

```matlab
run('step_1_save_all_data.m')   % fetches session data → allData_step_1.mat
run('step_2_generate_kinematics.m')  % computes kinematics → allData_step_2.mat
```

Once you have `tiffs/` and `allData_step_2.mat`, everything else is handled by
the main script.

### Run the analysis

```matlab
run('complexity_metric_tests.m')
```

Set `saveFigures = true` at the top to export results to `figures/`.

---

## What it does

**Step 1 — complexity metrics** (one value per letter, computed from TIFFs):

| Metric | Definition |
|--------|------------|
| Skeleton pixel count | `nnz(bwmorph(bw, 'skel', Inf))` — morphological skeleton length |
| Perimetric complexity | P² / (4πA) — boundary-to-area ratio |
| Algorithmic complexity | EPS file size in bytes — LZ-based description-length proxy |

**Step 2 — behavioural metrics** (many values per letter, from human drawing
experiments): drawing time, path length, peak/mean speed, peak/mean
acceleration, peak/mean jerk, normalized RMS derivatives, and turning metrics.

**Step 3 — correlation analysis**: r and p values for every complexity ×
behavioural metric pair, printed to the console as a table and shown as a
colour-coded heatmap (Figure 1).

**Step 4 — violin plots**: one figure per (complexity × behavioural) pair,
showing the distribution of behavioural values at each complexity level,
grouped by letter, with a regression line and r/p annotation.

---

## Files

| File | Purpose |
|------|---------|
| `complexity_metric_tests.m` | **Main script — run this** |
| `svg_to_tiff.py` | Rasterise SVGs → TIFFs (run once from command line) |
| `compress_tiffs.py` | Vectorise TIFFs → EPS via potrace (run once; produces algorithmic complexity input) |
| `requirements.txt` | Python dependencies for svg_to_tiff.py and compress_tiffs.py |
| `step_1_save_all_data.m` | Fetch session data from API → allData_step_1.mat |
| `step_2_generate_kinematics.m` | Compute kinematic metrics → allData_step_2.mat |
| `session_data.m` | Fetch and annotate one session; contains all script lookup tables |
| `fetch_json.m` | HTTP GET → parsed JSON |
| `parse_listSessions_json.m` | Parse session-listing API response |
| `parse_xyt_session_json.m` | Parse per-session drawing data |
| `svgs/` | SVG templates for Latin cursive a–z |
| `tiffs/` | Rasterised TIFFs (generated; not committed) |
| `eps/` | EPS exports for algorithmic complexity (generated; not committed) |
| `figures/` | Output figures (generated; not committed) |

---

## Outputs

- **Console**: correlation table with significance stars
- **Figure 1** (`figures/r_heatmap.svg`): blue–white–red heatmap of all r values
- **Figures 2+** (`figures/<metric>_vs_<behavioural>.svg`): violin plot per
  complexity × behavioural pair
