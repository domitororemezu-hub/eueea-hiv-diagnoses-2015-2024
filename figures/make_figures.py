"""Draw Figures 1-4 and Supplementary Figures S1-S4 from the tables written by run_all.R.

usage (from the repository root, after Rscript run_all.R):  python3 figures/make_figures.py
Requires Python 3 with matplotlib, numpy and scipy (scipy is used only to draw the dendrogram from
the merge history that R wrote). Figures are drawn at their print size, 170 mm wide (BMC full-page width), with
all text at 8 pt or larger, and written to output/figures as PNG files at 600 dpi.
"""
import csv
import math
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
from matplotlib.ticker import FuncFormatter

TAB = os.path.join("output", "tables")
OUT = os.path.join("output", "figures")
os.makedirs(OUT, exist_ok=True)

# ---- style -----------------------------------------------------------------------------------------
ORANGE, BLUE, DARK = "#D55E00", "#0072B2", "#404040"
SHADE = {"pre": "#FCFAF0", "covid": "#F2FAF4", "post": "#FEF4F2"}
GRID = "#D3D8DC"
MIN_PT = 8.0                       # smallest text size at print size
FIG_W = 170 / 25.4                 # 170 mm, BMC full-page figure width (inches)
plt.rcParams.update({
    "font.family": "sans-serif", "font.sans-serif": ["Liberation Sans", "Arial", "Helvetica", "DejaVu Sans"],
    "font.size": 8, "axes.titlesize": 9, "axes.titleweight": "bold",
    "axes.labelsize": 8, "xtick.labelsize": 8, "ytick.labelsize": 8, "legend.fontsize": 8,
    "axes.spines.top": False, "axes.spines.right": False, "axes.linewidth": 0.6,
    "xtick.major.width": 0.6, "ytick.major.width": 0.6, "xtick.major.size": 2.5, "ytick.major.size": 2.5,
    "lines.linewidth": 1.0, "savefig.dpi": 600, "figure.dpi": 100})
ISO3 = {"Austria": "AUT", "Belgium": "BEL", "Bulgaria": "BGR", "Croatia": "HRV", "Cyprus": "CYP", "Czechia": "CZE",
        "Denmark": "DNK", "Estonia": "EST", "Finland": "FIN", "France": "FRA", "Germany": "DEU", "Greece": "GRC",
        "Hungary": "HUN", "Iceland": "ISL", "Ireland": "IRL", "Italy": "ITA", "Latvia": "LVA", "Liechtenstein": "LIE",
        "Lithuania": "LTU", "Luxembourg": "LUX", "Malta": "MLT", "Netherlands": "NLD", "Norway": "NOR",
        "Poland": "POL", "Portugal": "PRT", "Romania": "ROU", "Slovakia": "SVK", "Slovenia": "SVN", "Spain": "ESP",
        "Sweden": "SWE"}
YEARS = list(range(2015, 2025))
MINUS = "−"


def read(name):
    with open(os.path.join(TAB, name + ".csv"), encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def fnum(v):
    return float("nan") if v in ("NA", "") else float(v)


def thousands(x, _pos=None):
    return f"{x:,.0f}"


def signed(v, k=3):
    s = f"{v:+.{k}f}"
    return s.replace("-", MINUS)


def fit_legend(fig, **kw):
    """fig.legend at MIN_PT that uses fewer columns until it fits within the figure width."""
    kw.pop("fontsize", None)
    ncol = kw.pop("ncol", 4)
    while True:
        leg = fig.legend(fontsize=MIN_PT, ncol=ncol, **kw)
        fig.canvas.draw()
        bb = leg.get_window_extent(fig.canvas.get_renderer())
        if bb.width <= 0.98 * fig.bbox.width or ncol == 1:
            return leg
        leg.remove()
        ncol -= 1


def panel_letter(fig, ax, letter, dx_in=0.42, dy_in=0.10):
    bb = ax.get_position()
    w, h = fig.get_size_inches()
    fig.text(bb.x0 - dx_in / w, bb.y1 + dy_in / h, letter, fontsize=11, fontweight="bold", va="bottom", ha="left")


def shade_periods(ax):
    ax.axvspan(2014.5, 2019.5, color=SHADE["pre"], zorder=0, lw=0)
    ax.axvspan(2019.5, 2021.5, color=SHADE["covid"], zorder=0, lw=0)
    ax.axvspan(2021.5, 2024.5, color=SHADE["post"], zorder=0, lw=0)


def ygrid(ax):
    ax.yaxis.grid(True, color=GRID, lw=0.5, zorder=0.5)
    ax.set_axisbelow(True)


# ---- data ------------------------------------------------------------------------------------------
COUNTS = {}
with open(os.path.join("data", "raw", "ecdc2025_tables2to7.csv"), encoding="utf-8") as fh:
    for r in csv.DictReader(fh):
        COUNTS[(r["series"], r["country"])] = [float(r[str(y)]) for y in YEARS]
BENCH = {}
for r in read("benchmarks_2020_2024"):
    BENCH.setdefault(r["series"], []).append(r)


# ---- benchmark panels (Figures 1, 2A-B, S1) ----------------------------------------------------------
def benchmark_panel(ax, observed, rows, title, ylabel):
    """observed: 10 counts 2015-2024; rows: 5 dicts for 2020-2024 with expected, lo, hi, class."""
    shade_periods(ax)
    ygrid(ax)
    yrs5 = [int(r["year"]) for r in rows]
    exp_ = [fnum(r["expected"]) for r in rows]
    lo = [fnum(r["lo"]) for r in rows]
    hi = [fnum(r["hi"]) for r in rows]
    ax.fill_between(yrs5, lo, hi, color=BLUE, alpha=0.2, lw=0, zorder=1)
    ax.plot(yrs5, exp_, ls="--", color=BLUE, lw=1.1, zorder=2)
    ax.plot(YEARS, observed, color=ORANGE, lw=1.2, marker="o", ms=3.3, zorder=3)
    out = [(int(r["year"]), observed[YEARS.index(int(r["year"]))]) for r in rows if r["class"] != "within"]
    if out:
        ax.plot([o[0] for o in out], [o[1] for o in out], ls="none", marker="o", ms=6.0, mfc=ORANGE, mec="black",
                mew=0.8, zorder=4)
    ax.set_xlim(2014.5, 2024.5)
    ax.set_xticks(YEARS)
    ax.set_xticklabels([str(y) for y in YEARS], rotation=45)
    ax.yaxis.set_major_formatter(FuncFormatter(thousands))
    ax.set_title(title, fontsize=9 if len(title) <= 36 else 8.5)
    ax.set_xlabel("Year")
    ax.set_ylabel(ylabel)


def benchmark_legend_handles():
    return [Line2D([], [], color=ORANGE, lw=1.2, marker="o", ms=3.3, label="Observed annual diagnoses"),
            Line2D([], [], ls="none", marker="o", ms=6.0, mfc=ORANGE, mec="black", mew=0.8,
                   label="Observed beyond 95% prediction interval"),
            Line2D([], [], color=BLUE, ls="--", lw=1.1, label="Pre-COVID negative binomial benchmark"),
            Patch(facecolor=BLUE, alpha=0.2, lw=0, label="95% prediction interval"),
            Patch(facecolor=SHADE["pre"], edgecolor="none", label="Pre-COVID period (2015–2019)"),
            Patch(facecolor=SHADE["covid"], edgecolor="none", label="COVID-19 disruption (2020–2021)"),
            Patch(facecolor=SHADE["post"], edgecolor="none", label="Post-full-scale-invasion period (2022–2024)")]


def nb_rows(series):
    return [dict(year=r["year"], expected=r["nb_expected"], lo=r["nb_lo"], hi=r["nb_hi"], **{"class": r["nb_class"]})
            for r in BENCH[series]]


def figure1():
    fig, axs = plt.subplots(2, 2, figsize=(FIG_W, 6.3))
    fig.subplots_adjust(left=0.095, right=0.985, top=0.945, bottom=0.215, hspace=0.50, wspace=0.26)
    spec = [("heterosexual", "Heterosexual transmission"), ("msm", "Men who have sex with men (MSM)"),
            ("pwid", "People who inject drugs (PWID)"), ("mtc", "Mother-to-child transmission (MTC)")]
    for ax, (s, title), letter in zip(axs.flat, spec, "ABCD"):
        benchmark_panel(ax, COUNTS[(s, "Total EU/EEA")], nb_rows(s), title, "Annual EU/EEA diagnoses")
        panel_letter(fig, ax, letter)
    fit_legend(fig, handles=benchmark_legend_handles(), loc="lower center", ncol=2, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.004), columnspacing=1.2, handlelength=2.2)
    fig.savefig(os.path.join(OUT, "Figure_1.png"))
    plt.close(fig)


# ---- scatter panels with automatic, non-overlapping labels -------------------------------------------
def _overlap(a, b, pad=1.0):
    return not (a.x1 + pad < b.x0 or b.x1 + pad < a.x0 or a.y1 + pad < b.y0 or b.y1 + pad < a.y0)


def _area(a, b):
    w = min(a.x1, b.x1) - max(a.x0, b.x0)
    h = min(a.y1, b.y1) - max(a.y0, b.y0)
    return max(w, 0) * max(h, 0)


def _seg_cross(p1, p2, q1, q2):
    def ccw(a, b, c):
        return (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2 = ccw(q1, q2, p1), ccw(q1, q2, p2)
    d3, d4 = ccw(p1, p2, q1), ccw(p1, p2, q2)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def place_labels(fig, ax, pts, lines, avoid_boxes, fontsize=MIN_PT, marker_pt=5.2):
    """pts: list of (x, y, label). lines: list of (xs, ys, weight) in data units to keep clear of.
    Each label goes next to its marker where there is room; otherwise a little further out, joined to the
    marker by a short grey leader line. Every candidate position is scored for overlap with other labels,
    markers, fitted lines and leader lines (and for being closer to another marker than to its own); a
    greedy placement is followed by rounds of re-placing each label given all the others."""
    fig.canvas.draw()
    rend = fig.canvas.get_renderer()
    to_disp = ax.transData.transform
    axbb = ax.get_window_extent(rend)
    mr = marker_pt * fig.dpi / 72.0 / 2 + 1.5
    n = len(pts)
    centers = [tuple(to_disp((x, y))) for x, y, _ in pts]
    mboxes = [matplotlib.transforms.Bbox([[cx - mr, cy - mr], [cx + mr, cy + mr]]) for cx, cy in centers]
    fixed = []
    for xs, ys, wt in lines:
        xs_f = np.linspace(xs[0], xs[-1], 400)
        fixed.append((to_disp(np.column_stack([xs_f, np.interp(xs_f, xs, ys)])), wt))
    near = [(3.5, 1, "left", "bottom"), (3.5, -1, "left", "top"), (-3.5, 1, "right", "bottom"), (-3.5, -1, "right", "top"),
            (4, 0, "left", "center"), (-4, 0, "right", "center"), (0, 3.8, "center", "bottom"), (0, -3.8, "center", "top")]
    far = []
    for dist in (6.5, 9, 12, 16, 21, 27, 34, 42):
        for ang in range(0, 360, 20):
            dx, dy = dist * math.cos(math.radians(ang)), dist * math.sin(math.radians(ang))
            far.append((dx, dy, "left" if dx > 3 else ("right" if dx < -3 else "center"),
                        "bottom" if dy > 3 else ("top" if dy < -3 else "center")))
    cands = near + far
    # measure every candidate once
    boxes = []
    for i, (x, y, lab) in enumerate(pts):
        row = []
        for dx, dy, ha, va in cands:
            t = ax.annotate(lab, (x, y), xytext=(dx, dy), textcoords="offset points", ha=ha, va=va, fontsize=fontsize)
            row.append(t.get_window_extent(rend))
            t.remove()
        boxes.append(row)

    def leader(i, bb, k):
        if k < len(near):
            return None
        cx, cy = centers[i]
        tx, ty = min(max(cx, bb.x0), bb.x1), min(max(cy, bb.y0), bb.y1)
        if math.hypot(tx - cx, ty - cy) <= mr + 2:
            return None
        d = np.array([tx - cx, ty - cy]) / math.hypot(tx - cx, ty - cy)
        return (cx + d[0] * (mr + 0.5), cy + d[1] * (mr + 0.5)), (tx, ty)

    def gap(bb, c):
        return math.hypot(max(bb.x0 - c[0], 0, c[0] - bb.x1), max(bb.y0 - c[1], 0, c[1] - bb.y1))

    def inside(P, bb, pad=1.0):
        return int(((P[:, 0] > bb.x0 - pad) & (P[:, 0] < bb.x1 + pad) & (P[:, 1] > bb.y0 - pad) & (P[:, 1] < bb.y1 + pad)).sum())

    def cost(i, k, state):
        bb = boxes[i][k]
        dx, dy = cands[k][:2]
        c = 0.5 * k
        if bb.x0 < axbb.x0 + 2 or bb.x1 > axbb.x1 - 2 or bb.y0 < axbb.y0 + 2 or bb.y1 > axbb.y1 - 2:
            c += 1e6
        for ob in avoid_boxes:
            c += 1e4 * _overlap(bb, ob, pad=4.0)
        for j in range(n):
            if j != i:
                c += 50 * _area(bb, mboxes[j]) + 200 * _overlap(bb, mboxes[j], pad=0.5)
        for P, wt in fixed:
            c += wt * inside(P, bb)
        ld = leader(i, bb, k)
        if k >= len(near):
            c += 60 + 2.5 * math.hypot(dx, dy)
            # a label joined by a leader line must not sit next to another country's marker
            if any(gap(bb, centers[j]) < mr + 6 for j in range(n) if j != i):
                c += 150
        else:
            d_own = gap(bb, centers[i])
            if any(gap(bb, centers[j]) < d_own + mr + 3 for j in range(n) if j != i):
                c += 90
        seg = np.linspace(ld[0], ld[1], 25) if ld else None
        if seg is not None:
            for j in range(n):
                if j != i and inside(seg, mboxes[j], pad=3) > 0:
                    c += 120
        for j, kj in state.items():
            if j == i or kj is None:
                continue
            bj = boxes[j][kj]
            c += 50 * _area(bb, bj) + 200 * _overlap(bb, bj, pad=3.5)
            lj = leader(j, bj, kj)
            if lj:
                c += 60 * inside(np.linspace(lj[0], lj[1], 25), bb, pad=2.0)
                if seg is not None:
                    c += 150 * _seg_cross(ld[0], ld[1], lj[0], lj[1])
            if seg is not None and inside(seg, bj, pad=2.0) > 0:
                c += 300
        return c

    order = sorted(range(n), key=lambda i: -sum(1 for j in range(n) if abs(centers[i][0] - centers[j][0]) < 60
                                                and abs(centers[i][1] - centers[j][1]) < 40))
    state = {i: None for i in range(n)}
    for i in order:                                  # greedy start
        state[i] = min(range(len(cands)), key=lambda k: cost(i, k, state))
    for _ in range(4):                               # local improvement
        changed = False
        for i in order:
            best = min(range(len(cands)), key=lambda k: cost(i, k, state))
            if cost(i, best, state) < cost(i, state[i], state) - 1e-9:
                state[i] = best
                changed = True
        if not changed:
            break
    inv = ax.transData.inverted()
    for i, (x, y, lab) in enumerate(pts):
        dx, dy, ha, va = cands[state[i]]
        ax.annotate(lab, (x, y), xytext=(dx, dy), textcoords="offset points", ha=ha, va=va, fontsize=fontsize, zorder=6)
        ld = leader(i, boxes[i][state[i]], state[i])
        if ld:
            p0, p1 = inv.transform(ld[0]), inv.transform(ld[1])
            ax.plot([p0[0], p1[0]], [p0[1], p1[1]], color="#8C8C8C", lw=0.5, zorder=5)


def ratio_panel(fig, ax, rows, value, title, ylabel, r_txt, n_txt, xmax, notes=None, ylim=None, wo_fit=None):
    """rows: dicts with country, tp_mean, regional, and the value column.
    wo_fit: (intercept, slope) of the OLS fit without Czechia from the R output, drawn dashed."""
    xs = np.array([float(r["tp_mean"]) for r in rows])
    ys = np.array([float(r[value]) for r in rows])
    reg = np.array([r["regional"] == "TRUE" for r in rows])
    ygrid(ax)
    ax.axhline(1.0, color="#7F7F7F", lw=0.7, ls=":", zorder=1)
    b, a = np.polyfit(xs, ys, 1)
    fx = np.array([0.0, xmax])
    ax.plot(fx, a + b * fx, color=DARK, lw=1.1, zorder=2)
    fit_lines = [(fx, a + b * fx, 25)]
    if wo_fit is not None:
        # drawn over the range of the countries other than Czechia, like the solid line over all countries
        fw = np.array([0.0, max(x for x, r in zip(xs, rows) if r["country"] != "Czechia") + 1])
        ax.plot(fw, wo_fit[0] + wo_fit[1] * fw, color=DARK, lw=0.9, ls=WO_CZ_DASH, zorder=2)
        fit_lines.append((fw, wo_fit[0] + wo_fit[1] * fw, 20))
    ax.plot(xs[~reg], ys[~reg], ls="none", marker="o", ms=5.0, mfc="white", mec=BLUE, mew=1.1, zorder=4)
    ax.plot(xs[reg], ys[reg], ls="none", marker="s", ms=5.0, mfc=ORANGE, mec="black", mew=0.5, zorder=4)
    ax.set_title(title, fontsize=9)
    ax.set_xlabel("Mean Ukrainian temporary-protection beneficiaries\nper 1,000 population (2022–2024)")
    ax.set_ylabel(ylabel)
    if ylim:
        ax.set_ylim(*ylim)
    else:
        lo, hi = ys.min(), ys.max()
        pad = 0.07 * (hi - lo)
        ax.set_ylim(lo - pad, hi + pad)
    ax.set_xlim(-1.5, xmax + 1.5)
    # the r/n box goes in the first corner (upper left, upper right, lower right, lower left) free of markers
    fig.canvas.draw()
    rend = fig.canvas.get_renderer()
    disp = ax.transData.transform(np.column_stack([xs, ys]))
    mr = 5.0 * fig.dpi / 72.0
    for cx, cy, ha, va in ((0.018, 0.975, "left", "top"), (0.982, 0.975, "right", "top"),
                           (0.982, 0.025, "right", "bottom"), (0.018, 0.025, "left", "bottom")):
        box = ax.text(cx, cy, f"Pearson r = {r_txt}\nn = {n_txt}", transform=ax.transAxes, va=va, ha=ha,
                      fontsize=MIN_PT, zorder=7, bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="#AAAAAA", lw=0.5))
        bb = box.get_window_extent(rend)
        if not any(bb.x0 - mr < px < bb.x1 + mr and bb.y0 - mr < py < bb.y1 + mr for px, py in disp):
            break
        box.remove()
    avoid = [box.get_window_extent(rend)]
    labels = [(x, y, ISO3[r["country"]] + ((notes or {}).get(r["country"], ""))) for x, y, r in zip(xs, ys, rows)]
    place_labels(fig, ax, labels, fit_lines + [([ax.get_xlim()[0], ax.get_xlim()[1]], [1.0, 1.0], 6)], avoid)


WO_CZ_DASH = (0, (5, 3))


def scatter_legend_handles(without_czechia=False):
    h = [Line2D([], [], ls="none", marker="o", ms=5.0, mfc="white", mec=BLUE, mew=1.1, label="Other EU/EEA"),
         Line2D([], [], ls="none", marker="s", ms=5.0, mfc=ORANGE, mec="black", mew=0.5, label="Central/eastern group"),
         Line2D([], [], color=DARK, lw=1.1, label="Linear (OLS) fit")]
    if without_czechia:
        h.append(Line2D([], [], color=DARK, lw=0.9, ls=WO_CZ_DASH, label="OLS fit without Czechia"))
    return h + [Line2D([], [], color="#7F7F7F", lw=0.7, ls=":", label="Ratio = 1")]


RATIOS = read("country_ratios")
S3 = {r["series"]: r for r in read("table_s3_associations")}
FITS_CZ = {r["series"]: (float(r["intercept_without"]), float(r["slope_without"]))
           for r in read("ols_fits_with_without_czechia")}


def inc_rows(series, table=RATIOS, flag="included"):
    return [r for r in table if r["series"] == series and r[flag] == "TRUE"]


def figure2():
    fig, axs = plt.subplots(2, 2, figsize=(FIG_W, 8.6), gridspec_kw=dict(height_ratios=[1, 1.6]))
    fig.subplots_adjust(left=0.095, right=0.985, top=0.96, bottom=0.2, hspace=0.36, wspace=0.26)
    for ax, s, title, letter in ((axs[0, 0], "female", "Female — total HIV diagnoses", "A"),
                                 (axs[0, 1], "male", "Male — total HIV diagnoses", "B")):
        benchmark_panel(ax, COUNTS[(s, "Total EU/EEA")], nb_rows(s), title, "Annual EU/EEA diagnoses")
        panel_letter(fig, ax, letter)
    for ax, s, lab, letter in ((axs[1, 0], "female", "female", "C"), (axs[1, 1], "male", "male", "D")):
        rows = inc_rows(s)
        xmax = max(float(r["tp_mean"]) for r in rows) + 1
        ratio_panel(fig, ax, rows, "ratio", f"{lab.capitalize()} — diagnosis ratio",
                    f"2022–2024 / 2015–2019 {lab} diagnosis ratio", signed(float(S3[s]["pearson_r"])), S3[s]["n"], xmax,
                    wo_fit=FITS_CZ.get(s))
        panel_letter(fig, ax, letter)
    h = benchmark_legend_handles() + scatter_legend_handles(without_czechia=True)
    fit_legend(fig, handles=h, loc="lower center", ncol=3, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.004), columnspacing=1.1, handlelength=2.4)
    fig.savefig(os.path.join(OUT, "Figure_2.png"))
    plt.close(fig)


def figure3():
    fig, axs = plt.subplots(2, 2, figsize=(FIG_W, 8.0))
    fig.subplots_adjust(left=0.095, right=0.985, top=0.96, bottom=0.15, hspace=0.38, wspace=0.26)
    spec = [("heterosexual", "Heterosexual diagnoses"), ("msm", "MSM diagnoses"),
            ("pwid", "PWID diagnoses"), ("mtc", "MTC diagnoses")]
    for ax, (s, title), letter in zip(axs.flat, spec, "ABCD"):
        rows = inc_rows(s)   # Malta's MSM series is excluded in R (no reported transmission mode in 2019)
        xmax = max(float(r["tp_mean"]) for r in rows) + 1
        ratio_panel(fig, ax, rows, "ratio", title, "2022–2024 / 2015–2019 diagnosis ratio",
                    signed(float(S3[s]["pearson_r"])), S3[s]["n"], xmax, wo_fit=FITS_CZ.get(s))
        panel_letter(fig, ax, letter)
    fit_legend(fig, handles=scatter_legend_handles(without_czechia=True), loc="lower center", ncol=3, frameon=True,
               edgecolor="#BBBBBB", bbox_to_anchor=(0.5, 0.004), columnspacing=1.6, handlelength=2.4)
    fig.savefig(os.path.join(OUT, "Figure_3.png"))
    plt.close(fig)


# ---- Figure 4 ----------------------------------------------------------------------------------------
def figure4():
    rows = read("cee_origin_nine_countries")
    colours = {"Germany": "#1f77b4", "Poland": "#ff7f0e", "Czechia": "#2ca02c", "Netherlands": "#d62728",
               "Italy": "#9467bd", "Belgium": "#8c564b", "Ireland": "#e377c2", "Spain": "#7f7f7f", "Slovakia": "#bcbd22"}
    fig, ax = plt.subplots(figsize=(FIG_W, 4.4))
    fig.subplots_adjust(left=0.105, right=0.985, top=0.975, bottom=0.235)
    ax.axvspan(2014.5, 2019.5, color=SHADE["pre"], zorder=0, lw=0)
    ax.axvspan(2019.5, 2021.5, color=SHADE["covid"], zorder=0, lw=0)
    ax.axvspan(2021.5, 2024.5, color=SHADE["post"], zorder=0, lw=0)
    ygrid(ax)
    last = {}
    for c, col in colours.items():
        v = {int(r["year"]): fnum(r["cee_n"]) for r in rows if r["country"] == c}
        ys = [v[y] for y in YEARS]
        ax.plot(YEARS, ys, color=col, lw=1.2, marker="o", ms=3.3, zorder=3)
        last[c] = ys[-1]
    ax.axvline(2022, color="#555555", ls="--", lw=0.9, zorder=2)
    ax.text(2022.22, 1190, "Full-scale invasion\n(February 2022)", style="italic", color="#555555", fontsize=MIN_PT,
            va="top", ha="left")
    # right-hand labels: spread vertically so that they do not overlap, joined by thin grey lines
    ax.set_ylim(-40, 1220)
    order = sorted(last, key=lambda c: last[c])
    ax_h_pt = ax.get_position().height * fig.get_size_inches()[1] * 72
    ymin_gap = (1220 + 40) / ax_h_pt * (MIN_PT * 1.25)    # one text line in data units
    pos = []
    for c in order:
        y = last[c]
        if pos and y < pos[-1][1] + ymin_gap:
            y = pos[-1][1] + ymin_gap
        pos.append((c, y))
    for c, y in pos:
        ax.plot([2024.05, 2025.15], [last[c], y], color="#8C8C8C", lw=0.5, zorder=2)
        ax.text(2025.25, y, f"{c} ({last[c]:,.0f})", color=colours[c], fontweight="bold", fontsize=MIN_PT, va="center")
    ax.set_xlim(2014.5, 2028.2)
    ax.set_xticks(YEARS)
    ax.set_xticklabels([str(y) for y in YEARS], rotation=45)
    ax.set_xlabel("Year")
    ax.set_ylabel("HIV diagnoses attributed to\nCentral & Eastern Europe origin")
    h = [Patch(facecolor=SHADE["pre"], edgecolor="none", label="Pre-COVID period (2015–2019)"),
         Patch(facecolor=SHADE["covid"], edgecolor="none", label="COVID-19 disruption (2020–2021)"),
         Patch(facecolor=SHADE["post"], edgecolor="none", label="Post-full-scale-invasion period (2022–2024)"),
         Line2D([], [], color="#555555", ls="--", lw=0.9, label="Full-scale invasion (Feb 2022)")]
    fit_legend(fig, handles=h, loc="lower center", ncol=2, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.006), columnspacing=1.5)
    fig.savefig(os.path.join(OUT, "Figure_4.png"))
    plt.close(fig)


# ---- Figure S1: illustrative four-country comparator ------------------------------------------------
def figure_s1():
    rows = read("comparator_four_countries")
    fig, axs = plt.subplots(2, 2, figsize=(FIG_W, 6.3))
    fig.subplots_adjust(left=0.095, right=0.985, top=0.945, bottom=0.215, hspace=0.50, wspace=0.26)
    spec = [("Spain", "Spain — selected low-intensity comparator"), ("Czechia", "Czechia — selected high-intensity host"),
            ("Poland", "Poland — selected high-intensity host"), ("Germany", "Germany — selected high-intensity host")]
    for ax, (c, title), letter in zip(axs.flat, spec, "ABCD"):
        rr = [r for r in rows if r["country"] == c]
        obs = [float(r["observed"]) for r in rr]
        proj = [dict(year=r["year"], expected=r["expected"], lo=r["lo"], hi=r["hi"], **{"class": r["class"]})
                for r in rr if r["expected"] != "NA"]
        benchmark_panel(ax, obs, proj, title, "Annual heterosexual diagnoses")
        panel_letter(fig, ax, letter)
    fit_legend(fig, handles=benchmark_legend_handles(), loc="lower center", ncol=2, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.004), columnspacing=1.2, handlelength=2.2)
    fig.savefig(os.path.join(OUT, "Figure_S1.png"))
    plt.close(fig)


# ---- Figure S2: trajectory deviation map and cumulative observed minus expected -----------------------
LAB = {"heterosexual": "Heterosexual", "msm": "MSM", "pwid": "PWID", "mtc": "MTC", "female": "Female (total)",
       "male": "Male (total)"}
SER = ["heterosexual", "msm", "pwid", "mtc", "female", "male"]


def pct_axis(ax, ticks):
    ax.set_yscale("log")
    ax.set_yticks([1 + t / 100 for t in ticks])
    ax.set_yticklabels([("+" if t > 0 else "") + f"{t:g}%".replace("-", MINUS) for t in ticks])
    ax.yaxis.set_minor_locator(matplotlib.ticker.NullLocator())


def figure_s2():
    dev = {r["series"]: r for r in read("deviation_map")}
    cum = read("cumulative_observed_minus_expected")
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(FIG_W, 3.9), gridspec_kw=dict(width_ratios=[1, 1.15]))
    fig.subplots_adjust(left=0.135, right=0.985, top=0.9, bottom=0.27, wspace=0.40)
    ygrid(a1)
    a1.axhline(1.0, color="#7F7F7F", lw=0.7, ls=":", zorder=1)
    for s in SER:
        r = dev[s]
        x, xl, xh = float(r["annual_change_pct"]), float(r["change_lo"]), float(r["change_hi"])
        y = float(r["observed"]) / float(r["expected"])
        yl, yh = float(r["observed"]) / float(r["hi"]), float(r["observed"]) / float(r["lo"])
        sex = s in ("female", "male")
        a1.errorbar([x], [y], xerr=[[x - xl], [xh - x]], yerr=[[y - yl], [yh - y]], fmt="s" if sex else "o",
                    ms=4.8, mfc=ORANGE if sex else BLUE, mec="black", mew=0.5, ecolor="#7F7F7F", elinewidth=0.7,
                    capsize=1.5, zorder=4)
    a1.set_xlim(-12, 0.5)
    a1.set_ylim(0.88, 3.5)
    pct_axis(a1, [-10, 0, 25, 50, 100, 200])
    fig.canvas.draw()
    pts = [(float(dev[s]["annual_change_pct"]), float(dev[s]["observed"]) / float(dev[s]["expected"]), LAB[s]) for s in SER]
    place_labels(fig, a1, pts, [], [], fontsize=MIN_PT, marker_pt=4.8)
    a1.set_xlabel("Pre-COVID trend, 2015–2019\n(% change per year)")
    a1.set_ylabel("Observed vs projected diagnoses,\n2022–2024")
    a1.set_title("Trajectory deviation map")
    panel_letter(fig, a1, "A")
    # panel B: cumulative difference by period
    ygrid(a2)
    a2.axhline(1.0, color="#7F7F7F", lw=0.7, ls=":", zorder=1)
    periods = [("2020-2021", "2020–2021", "#7FB3D5", "v"), ("2022-2024", "2022–2024", ORANGE, "o"),
               ("2020-2024", "2020–2024", "#404040", "D")]
    for k, (p, plab, col, mk) in enumerate(periods):
        for i, s in enumerate(SER):
            r = [x for x in cum if x["series"] == s and x["period"] == p][0]
            o, e, lo, hi = float(r["observed"]), float(r["expected"]), float(r["lo"]), float(r["hi"])
            xx = i + (k - 1) * 0.24
            a2.errorbar([xx], [o / e], yerr=[[o / e - o / hi], [o / lo - o / e]], fmt=mk, ms=4.0, mfc=col, mec="black",
                        mew=0.4, ecolor=col, elinewidth=0.9, capsize=0, zorder=4, label=plab if i == 0 else None)
    a2.set_xticks(range(len(SER)))
    a2.set_xticklabels([LAB[s].replace(" (total)", "\n(total)").replace("Heterosexual", "Hetero-\nsexual") for s in SER])
    a2.set_xlim(-0.6, len(SER) - 0.4)
    a2.set_ylim(0.6, 3.5)
    pct_axis(a2, [-30, -20, -10, 0, 25, 50, 100, 200])
    a2.set_ylabel("Cumulative observed vs\nprojected diagnoses")
    a2.set_title("Cumulative difference by period")
    a2.legend(loc="upper left", frameon=True, edgecolor="#BBBBBB", fontsize=MIN_PT, title="Period", title_fontsize=MIN_PT)
    panel_letter(fig, a2, "B")
    h = [Line2D([], [], ls="none", marker="o", ms=4.8, mfc=BLUE, mec="black", mew=0.5, label="Transmission category"),
         Line2D([], [], ls="none", marker="s", ms=4.8, mfc=ORANGE, mec="black", mew=0.5, label="Total by sex"),
         Line2D([], [], color="#7F7F7F", lw=0.7, label="95% interval")]
    fit_legend(fig, handles=h, loc="lower center", ncol=3, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.01))
    fig.savefig(os.path.join(OUT, "Figure_S2.png"))
    plt.close(fig)


# ---- Figure S3: country observed/predicted ratios versus temporary-protection intensity ---------------
def figure_s3():
    op = read("country_observed_predicted")
    assoc = {r["series"]: r for r in read("observed_predicted_associations")}
    fig, axs = plt.subplots(3, 2, figsize=(FIG_W, 8.75))
    fig.subplots_adjust(left=0.095, right=0.985, top=0.965, bottom=0.115, hspace=0.50, wspace=0.26)
    titles = {"heterosexual": "Heterosexual diagnoses", "msm": "MSM diagnoses", "pwid": "PWID diagnoses",
              "mtc": "MTC diagnoses", "female": "Female (total) diagnoses", "male": "Male (total) diagnoses"}
    for ax, s, letter in zip(axs.flat, SER, "ABCDEF"):
        rows = inc_rows(s, op)
        xmax = max(float(r["tp_mean"]) for r in rows) + 1
        ratio_panel(fig, ax, rows, "op_2022_2024", titles[s], "Observed / projected, 2022–2024",
                    signed(float(assoc[s]["pearson_r"])), assoc[s]["n"], xmax)
        panel_letter(fig, ax, letter)
    h = scatter_legend_handles()
    h[-1] = Line2D([], [], color="#7F7F7F", lw=0.7, ls=":", label="Observed = projected")
    fit_legend(fig, handles=h, loc="lower center", ncol=4, frameon=True, edgecolor="#BBBBBB",
               bbox_to_anchor=(0.5, 0.004), columnspacing=1.6)
    fig.savefig(os.path.join(OUT, "Figure_S3.png"))
    plt.close(fig)


# ---- Figure S4: exploratory clustering ----------------------------------------------------------------
def figure_s4():
    from scipy.cluster.hierarchy import dendrogram
    cl = read("clustering_countries")
    merge = read("clustering_ward_merge")
    n = len(cl)
    Z = np.zeros((n - 1, 4))
    size = {}
    for k, r in enumerate(merge):
        ids = []
        for v in (int(r["merge1"]), int(r["merge2"])):
            ids.append(-v - 1 if v < 0 else n + v - 1)
        cnt = sum(1 if i < n else size[i] for i in ids)
        size[n + k] = cnt
        Z[k] = [ids[0], ids[1], float(r["height"]), cnt]
    names = [r["country"] for r in cl]
    zcols = ["z_log_tp_mean", "z_tp_change", "z_log_op_heterosexual", "z_log_op_msm", "z_log_op_female",
             "z_log_op_male", "z_log_op_disruption"]
    zlabs = ["Intensity (log mean)", "Intensity change", "Heterosexual O/P, 2022–24", "MSM O/P, 2022–24",
             "Female O/P, 2022–24", "Male O/P, 2022–24", "Total O/P, 2020–21"]
    fig = plt.figure(figsize=(FIG_W, 5.2))
    a_d = fig.add_axes([0.06, 0.29, 0.25, 0.62])
    a_h = fig.add_axes([0.45, 0.29, 0.44, 0.62])
    a_c = fig.add_axes([0.905, 0.29, 0.02, 0.62])
    clus = {r["country"]: int(r["cluster_ward"]) for r in cl}
    dn = dendrogram(Z, orientation="left", labels=names, ax=a_d, color_threshold=0, above_threshold_color="#404040",
                    no_labels=True)
    a_d.spines[["top", "right", "left"]].set_visible(False)
    a_d.set_yticks([])
    a_d.set_xlabel("Ward distance")
    a_d.set_title("Ward clustering (21 countries)", fontsize=9)
    leaves = dn["ivl"][::-1]          # top to bottom (the dendrogram draws its first leaf at the bottom)
    M = np.array([[float([r for r in cl if r["country"] == c][0][z]) for z in zcols] for c in leaves])
    im = a_h.imshow(M, aspect="auto", cmap="RdBu_r", vmin=-3, vmax=3)
    a_h.set_yticks(range(len(leaves)))
    a_h.set_yticklabels(leaves, fontsize=MIN_PT)
    for t in a_h.get_yticklabels():
        if clus[t.get_text()] == 2:
            t.set_color(ORANGE); t.set_fontweight("bold")
    a_h.set_xticks(range(len(zcols)))
    a_h.set_xticklabels(zlabs, fontsize=MIN_PT, rotation=40, ha="right", rotation_mode="anchor")
    a_h.tick_params(axis="x", length=0)
    a_h.set_title("Standardised clustering variables (z-scores)", fontsize=9)
    for sp in a_h.spines.values():
        sp.set_visible(False)
    cb = fig.colorbar(im, cax=a_c)
    cb.set_label("z-score")
    panel_letter(fig, a_d, "A", dx_in=0.25, dy_in=0.30)
    panel_letter(fig, a_h, "B", dx_in=1.05, dy_in=0.30)
    fig.savefig(os.path.join(OUT, "Figure_S4.png"))
    plt.close(fig)


if __name__ == "__main__":
    figure1()
    figure2()
    figure3()
    figure4()
    figure_s1()
    figure_s2()
    figure_s3()
    figure_s4()
    print("Figures written to", OUT)
