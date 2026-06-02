# Hieratic Sign Complexity Analysis

MATLAB code and data for the study of iconicity, information content, and
complexity change across the history of Egyptian hieratic script.

This repository accompanies the paper:

> Casey, C. (in preparation). "What Did Egyptian Scribes Call the Signs of Their Script?"

Repository: https://github.com/writingthroughtime/hieratic-complexity-and-sign-names

---

## Overview

The study tests whether the rate at which individual hieratic signs simplify
over time is predicted by their information content (i.e., how rare the sign
is in the corpus). Complexity is measured as **skeleton pixel count**—the
number of pixels in the morphological skeleton of each sign image, which
approximates the length of the pen path required to draw the sign.

Sign images come from the
[AKU-PAL database](https://www.hieratologie.de/aku-pal/) of hieratic
attestations. Corpus frequency data come from the
[Thesaurus Linguae Aegyptiae (TLA)](https://thesaurus-linguae-aegyptiae.de/).

---

## Requirements

- **MATLAB R2021b** or later (earlier versions may work but are untested)
- **Image Processing Toolbox** (for `bwmorph`, `bwperim`, `im2double`)
- **Statistics and Machine Learning Toolbox** (for `fitlm`, `fitlme`, `corr`)
- **Signal Processing Toolbox** (for Gaussian smoothing in `smooth_shape_components`)

---

## Running the Pipeline

Run the scripts in order from the root directory:

### Step 1 — Build the sign list

```matlab
run('data_prep_01_populate_sign_list.m')
```

Reads `sign_list.csv`, loads TIFF images from `aku-pal/tiffs/ht/`,
computes complexity metrics (skeleton pixel count, perimetric complexity,
algorithmic complexity), and saves `sign_list.mat`.

### Step 2 — Load corpus frequency data

```matlab
run('data_prep_02_load_corpus_data.m')
```

Reads `corpus/corpus_frequency_mdc.json` and saves `corpus_data.mat`.

### Step 3 — Merge sign list and corpus data

```matlab
run('data_prep_03_integrate_sign_list_and_corpus_data.m')
```

Joins corpus frequency and epoch-level frequency onto the sign list and saves
`sign_list_plus_corpus_data.mat`.

### Step 4 — Generate figures and statistics

```matlab
run('change_in_complexity_tests.m')
```

Produces the main paper figures. Set `saveFigures = true` to export SVGs to
`./figures/`. The script reports correlation coefficients and p-values to the
console.

---

## Data

The `aku-pal/` directory contains data scraped from the AKU-PAL database:

| Path | Description |
|------|-------------|
| `aku-pal/tiffs/ht/` | TIFF images of individual hieratic sign instances |
| `aku-pal/svgs/ht/` | SVG outlines of each sign |
| `aku-pal/eps/ht/` | EPS files used for algorithmic complexity measurement |
| `aku-pal/records.jsonl` | Full structured scrape records (one JSON object per line) |
| `aku-pal/sign_core.csv` | Core sign metadata |
| `aku-pal/sign-grapheme-mdc.csv` | Sign–grapheme–MdC mapping |

**SVG files (`aku-pal/svgs/ht/`) are included in the repository.** Please do
not re-scrape AKU-PAL to regenerate them — the database should not be hammered
with bulk requests. If you need to regenerate the TIFFs or EPS files from the
included SVGs, use `aku-pal/svg_to_tiff.py` (no network access required).

TIFF and EPS directories are excluded from version control due to size. They
can be fully regenerated from the SVGs using the Python script above.

The TLA corpus data (`corpus/corpus_frequency_mdc.json`) and hieratic sign
list (`sign_list.csv`, `dates.csv`) are included in the repository.

---

## File Reference

| File | Purpose |
|------|---------|
| `data_prep_01_populate_sign_list.m` | Build sign list with images and complexity metrics |
| `data_prep_02_load_corpus_data.m` | Parse TLA corpus JSON into a MATLAB table |
| `data_prep_03_integrate_sign_list_and_corpus_data.m` | Merge sign list with corpus frequencies |
| `change_in_complexity_tests.m` | Main analysis: figures and correlations |
| `unify_text_scale.m` | Rescale SVGs to a common interlinear-distance scale |
| `perimetric_complexity.m` | Compute raster perimetric complexity from alpha channel |
| `perimetric_complexity_from_shapes.m` | Compute perimetric complexity from polygon outlines |
| `smooth_shape_components.m` | Resample and Gaussian-smooth polygon outlines |
| `mean_distance_from_centroid.m` | Mean point-to-centroid distance (used for scale estimation) |
| `median_distance_from_centroid.m` | Median point-to-centroid distance |
| `shapescatter.m` | Draw sign silhouettes at data-point positions in a scatter plot |
| `localNormalizeLabels.m` | Helper: normalize label arrays for `shapescatter` |
| `plot_sign_complexity.m` | Plot complexity over time for one sign with regression |
| `violin.m` | Violin plot grouped by a discrete x variable, with optional data labels and best-fit line |
| `kdeplot.m` | Kernel density estimate with optional histogram overlay |

---

## Citation

If you use this code or data, please cite the paper above and the following
data sources.

**AKU-PAL sign images:**

> Widmaier, K. & Verhoeven, U. AKU-PAL: Automatische Klassifikation und
> Umschrift — Paläographischer Atlas des Altägyptischen. Mainz: Johannes
> Gutenberg-Universität. https://www.hieratologie.de/aku-pal/

**TLA corpus frequency data:**

> Glyphs in the Thesaurus Linguae Aegyptiae: Transcriptions from Hieratic
> Texts, Corpus issue 20 (2025), compiled by Daniel A. Werning, 26 Apr 2026,
> based on data from the Thesaurus Linguae Aegyptiae, ed. by Tonio Sebastian
> Richter & Daniel A. Werning on behalf of the
> Berlin-Brandenburgische Akademie der Wissenschaften and Hans-Werner
> Fischer-Elfert & Peter Dils on behalf of the Sächsische Akademie der
> Wissenschaften zu Leipzig.
>
> Corresponding data: Thesaurus Linguae Aegyptiae: Datasets.
> https://github.com/thesaurus-linguae-aegyptiae/thesaurus-linguae-aegyptiae-datasets

---

## License

Code: MIT License. See `LICENSE` for details.  
AKU-PAL data: subject to the terms of the AKU-PAL database. Consult
https://www.hieratologie.de/aku-pal/ for usage rights.  
TLA corpus data: subject to the terms of the Thesaurus Linguae Aegyptiae.
Consult https://thesaurus-linguae-aegyptiae.de/ for usage rights.
