#!/usr/bin/env python3
"""Generate JSON figure data for the gh-pages site.

Reproduces the logic of change_in_complexity_tests.m:
 - main scatter: per sign, x = -log(mean frequency) = Information Content,
   y = slope of (skeleton_pixel_count ~ date) regression = Change in Complexity.
 - per-sign trajectory: date vs complexity for each filtered attestation, capped 550.

Column identities in sign_list_plus_corpus_data.mat (#refs#) verified empirically:
  i = sign_id, j = grapheme_id, kCv = date (mean), aCv = skeleton_pixel_count,
  iCv = epoche_startdatum, jCv = epoche_enddatum, mCv = frequency,
  pCv = text_length, o = file_found.
"""
import h5py, numpy as np, csv, json, os, re, collections
from collections import defaultdict

HIER = "/sessions/inspiring-beautiful-cerf/mnt/Sign Names Paper/Code/Matlab/Hieratic"
OUT  = os.path.join(HIER, "docs", "data")
os.makedirs(os.path.join(OUT, "signs"), exist_ok=True)

SEL = ["Altes Reich", "Mittleres Reich", "Neues Reich", "Griechisch-römische Zeit"]
CAP = 550
rng = np.random.default_rng(42)

# ---- mdc corrections, matching data_prep_03 ----
def fix_mdc(m):
    if m == "2": m = "Z4A"
    elif m == "3": m = "Z2"
    m = m.replace(":", "-").replace("&", "-")
    return m

def sanitize(m):
    return re.sub(r"[^A-Za-z0-9]", "_", m)

# ---- dates.csv: epoch bounds for the 4 selected epochs ----
ep_bounds = set()
with open(os.path.join(HIER, "dates.csv"), encoding="utf-8-sig") as fh:
    for r in csv.DictReader(fh):
        if r["epoche"] in SEL:
            ep_bounds.add((float(r["epoche_startdatum"]), float(r["epoche_enddatum"])))

# ---- sign_list.csv: sign_id -> ht id ; grapheme_id -> mdc ----
gid2mdc = {}
sid2ht  = {}
with open(os.path.join(HIER, "sign_list.csv"), encoding="utf-8-sig") as fh:
    rd = csv.reader(fh); hdr = next(rd)
    ci = hdr.index("sign_id"); cg = hdr.index("grapheme_id")
    cm = hdr.index("mdc"); cp = hdr.index("ht_local_path")
    for row in rd:
        if len(row) <= max(ci, cg, cm, cp):
            continue
        try:
            sid = int(row[ci]); gid = int(row[cg])
        except ValueError:
            continue
        gid2mdc[gid] = fix_mdc(row[cm])
        # ht_local_path like "svgs/ht/ht_123.svg" -> "ht_123"
        base = os.path.basename(row[cp])
        sid2ht[sid] = base[:-4] if base.endswith(".svg") else base

# ---- load .mat numeric columns ----
f = h5py.File(os.path.join(HIER, "sign_list_plus_corpus_data.mat"), "r")
R = f["#refs#"]
def col(k): return np.array(R[k]).ravel()
sid   = col("i").astype(np.int64)
gid   = col("j").astype(np.int64)
cplx  = col("aCv").astype(float)
date  = col("kCv").astype(float)
estart= col("iCv").astype(float)
eend  = col("jCv").astype(float)
freq  = col("mCv").astype(float)
tlen  = col("pCv").astype(float)
ffound= col("o").astype(float)
N = len(sid)

# ---- filters (mirroring the MATLAB pipeline) ----
epoch_mask = np.zeros(N, bool)
for (s, e) in ep_bounds:
    epoch_mask |= (np.isclose(estart, s) & np.isclose(eend, e))

base = (np.isfinite(freq)          # ~isnan(frequency)
        & (ffound == 1)            # file_found
        & (tlen > 1)               # text_length > minSigns(=1)
        & epoch_mask               # one of 4 selected epochs
        & np.isfinite(cplx) & np.isfinite(date))

idx_all = np.where(base)[0]

# group rows by corrected mdc
rows_by_mdc = defaultdict(list)
for ix in idx_all:
    m = gid2mdc.get(int(gid[ix]))
    if m:
        rows_by_mdc[m].append(ix)

# minCount >= 2 in EACH of the 4 epochs
def epoch_key(ix): return (estart[ix], eend[ix])
keep_mdc = []
for m, rows in rows_by_mdc.items():
    cnt = collections.Counter(epoch_key(r) for r in rows)
    if all(cnt.get(e, 0) >= 2 for e in ep_bounds):
        keep_mdc.append(m)

print(f"Signs passing all filters: {len(keep_mdc)}")

# ---- build per-sign scatter + trajectory ----
scatter = []
for m in keep_mdc:
    rows = np.array(rows_by_mdc[m])
    d = date[rows]; c = cplx[rows]
    slope, intercept = np.polyfit(d, c, 1)
    ic = -np.log(np.nanmean(freq[rows]))
    # representative glyph = earliest-dated attestation
    rep_ix = rows[np.argmin(d)]
    rep_ht = sid2ht.get(int(sid[rep_ix]), "")

    # trajectory points, capped at CAP
    order = np.argsort(d)
    rr = rows[order]
    if len(rr) > CAP:
        sub = np.sort(rng.choice(len(rr), CAP, replace=False))
        rr = rr[sub]
    points = []
    for ix in rr:
        ht = sid2ht.get(int(sid[ix]), "")
        if not ht:
            continue
        points.append({"d": float(date[ix]), "c": float(cplx[ix]), "s": ht})

    fname = sanitize(m)
    sign_obj = {
        "mdc": m,
        "slope": float(slope),
        "intercept": float(intercept),
        "n_total": int(len(rows)),
        "n_shown": len(points),
        "points": points,
    }
    with open(os.path.join(OUT, "signs", f"{fname}.json"), "w", encoding="utf-8") as fh:
        json.dump(sign_obj, fh, ensure_ascii=False, separators=(",", ":"))

    scatter.append({
        "mdc": m, "file": fname,
        "ic": float(ic), "slope": float(slope),
        "n": int(len(rows)), "rep": rep_ht,
    })

# ---- main scatter regression + correlation ----
xs = np.array([s["ic"] for s in scatter])
ys = np.array([s["slope"] for s in scatter])
fit_slope, fit_int = np.polyfit(xs, ys, 1)
xm, ym = xs - xs.mean(), ys - ys.mean()
r = float((xm @ ym) / np.sqrt((xm @ xm) * (ym @ ym)))
n = len(xs)
t = r * np.sqrt((n - 2) / (1 - r**2))
# two-sided p from t via survival function (normal approx + exact via betainc)
from math import lgamma, log, exp
def studentt_sf(t, df):
    # regularized incomplete beta for two-sided p-value
    x = df / (df + t*t)
    return betainc(df/2, 0.5, x)
def betainc(a, b, x):
    if x <= 0: return 0.0
    if x >= 1: return 1.0
    lbeta = lgamma(a) + lgamma(b) - lgamma(a+b)
    front = exp(a*log(x) + b*log(1-x) - lbeta) / a
    # Lentz continued fraction
    f, c, d = 1.0, 1.0, 0.0
    for i in range(0, 300):
        m_ = i // 2
        if i == 0: num = 1.0
        elif i % 2 == 0: num = (m_*(b-m_)*x)/((a+2*m_-1)*(a+2*m_))
        else: num = -((a+m_)*(a+b+m_)*x)/((a+2*m_)*(a+2*m_+1))
        d = 1.0 + num*d
        if abs(d) < 1e-30: d = 1e-30
        d = 1.0/d
        c = 1.0 + num/c
        if abs(c) < 1e-30: c = 1e-30
        f *= d*c
        if abs(1.0 - d*c) < 1e-12: break
    return front*(f-1.0)
p = float(studentt_sf(abs(t), n-2))

meta = {
    "title": "Information Content vs. Change in Complexity",
    "xlabel": "Information Content",
    "ylabel": "Change in Complexity",
    "r": r, "p": p, "n": n,
    "fit": {"slope": float(fit_slope), "intercept": float(fit_int),
            "x0": float(xs.min()), "x1": float(xs.max())},
    "svg_base": "https://raw.githubusercontent.com/writingthroughtime/hieratic-complexity-and-sign-names/main/aku-pal/svgs/ht/",
}
scatter.sort(key=lambda s: s["mdc"])
with open(os.path.join(OUT, "scatter.json"), "w", encoding="utf-8") as fh:
    json.dump({"meta": meta, "signs": scatter}, fh, ensure_ascii=False, separators=(",", ":"))

print(f"r = {r:.4f}, p = {p:.4f}, n = {n}")
print(f"x (IC) range: [{xs.min():.2f}, {xs.max():.2f}]")
print(f"y (slope) range: [{ys.min():.4f}, {ys.max():.4f}]")
print("Wrote scatter.json and", len(scatter), "sign files.")
