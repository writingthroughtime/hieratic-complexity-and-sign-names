# Interactive figures

This folder is the static website that accompanies the paper. It reproduces the two key
figure types as interactive plots drawn with the real hieratic glyphs, and GitHub Pages
serves it from here:

**https://writingthroughtime.github.io/hieratic-complexity-and-sign-names/**

There's no build step and nothing is computed in the browser. The page is one HTML file
plus pre-generated JSON.

## What's here

- **Overview** — *Information Content vs. Change in Complexity* (Figure 3 in the paper).
  Every sign is drawn with its earliest-attested glyph. Hover a sign to highlight it,
  click it to drill in.
- **Trajectory** — *complexity over time* for a single sign (Figures 4–9), one glyph per
  attestation with the fitted regression line. Click any glyph to enlarge it and open its
  AKU-PAL record.

```
docs/
  index.html            the whole app (vanilla JS + inline SVG)
  data/
    scatter.json        52 signs: information content, complexity slope, representative glyph
    signs/<MdC>.json     per-sign trajectory points (date, complexity, glyph id), capped at 550
    mdc_unicode.json     MdC sign code -> Unicode hieroglyph (for the 𓂋 (D21) labels)
  gen_data.py           regenerates everything in data/ from the MATLAB outputs
```

## Glyph images

I don't copy the glyphs into this folder. To match the dark theme, each glyph is fetched
as an SVG and recoloured in the browser (the iris colormap from the paper), so it has to
come from a host that allows cross-origin requests. The page therefore loads them from the
jsDelivr CDN, which mirrors this repo's files and sends the right CORS header:

```
https://cdn.jsdelivr.net/gh/writingthroughtime/hieratic-complexity-and-sign-names@main/aku-pal/svgs/ht/ht_45807.svg
```

That base URL lives in `data/scatter.json` under `meta.svg_base`. Note that
`raw.githubusercontent.com` will **not** work for this — it serves images but blocks the
cross-origin `fetch()` the recolouring needs. If you fork the repo or change the default
branch, update `meta.svg_base` (including the `@main` tag) to match.

## Running it in your own fork

1. Make sure `docs/` and `aku-pal/svgs/` are committed to `main` (they are).
2. In your fork: **Settings → Pages**.
3. **Source:** *Deploy from a branch*. **Branch:** `main`, **Folder:** `/docs`. Save.
4. Point `meta.svg_base` in `docs/data/scatter.json` at your fork's path.

It will go live at `https://<your-user>.github.io/hieratic-complexity-and-sign-names/`.

## Viewing it locally

`fetch()` needs HTTP, so opening `index.html` straight from disk won't load the data.
Serve the folder instead:

```
cd docs
python3 -m http.server 8000
```

## Regenerating the data

`gen_data.py` rebuilds everything in `data/` directly from `sign_list_plus_corpus_data.mat`,
`sign_list.csv`, and `dates.csv`. It reproduces the published Figure 3 statistics exactly
(r = 0.3755, p = 0.0061, n = 52) and the six featured per-sign slopes (G17 −0.9874,
A1 −1.1749, G1 −1.2722, D36 −0.0599, D28 +0.8943, G35 +1.4932). Re-run it after changing
the pipeline.
