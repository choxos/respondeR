# respondeR

**respondeR** re-expresses meta-analyses of *continuous* trial outcomes
in terms of **responders**. Clinicians and patients reason about “how
many people get better”, not about standardized mean differences. It
uses only the summary statistics that trials usually report: the **mean
change**, **standard deviation** and **sample size** in each arm. From
these respondeR estimates the proportion of patients whose change
crosses a **minimal important difference (MID)** threshold, and
contrasts the arms as a **risk difference (RD)**, **risk ratio (RR)**,
**odds ratio (OR)** or **number needed to treat (NNT)**.

It follows the interpretability tutorial of Thorlund, Walter, Johnston,
Furukawa & Guyatt (2011), implementing the cut-point (“dichotomization”)
and standardized-mean-difference conversions it reviews, and adds a
threshold-free common-language effect size. The estimation methods were
evaluated in a simulation study (Sofi-Mahmudi, 2024).

**Try it in the browser (no install):**
<https://choxos.github.io/respondeR/app>

**Documentation:** <https://choxos.github.io/respondeR/>

## Installation

``` r

# From CRAN (when available)
install.packages("respondeR")

# Development version from GitHub
# install.packages("remotes")
remotes::install_github("choxos/respondeR")
```

## Quick start

``` r

library(respondeR)

# Built-in example: three trials of a continuous change score
sample_responder_data
#>     study  change_e     sd_e n_e     change_c     sd_c n_c
#> 1 Study 1 0.9581395 1.257593  43  0.217777778 1.195501  45
#> 2 Study 2 0.7920863 1.281364 139  0.003448276 1.324629 145
#> 3 Study 3 1.0230769 1.341201 156 -0.041975309 1.263178 162

# Proportion of responders (change > MID of 1) and between-arm contrasts
responder_analysis(sample_responder_data, mid = 1)
```

| method     |   p_e |   p_c |    rd | rd_lb | rd_ub |   rr |   or | nnt |
|------------|------:|------:|------:|------:|------:|-----:|-----:|----:|
| individual |    NA |    NA | 0.255 | 0.187 | 0.324 | 2.15 | 3.20 | 3.9 |
| weighted   | 0.474 | 0.221 | 0.254 | 0.201 | 0.306 | 2.15 | 3.19 | 3.9 |
| unweighted | 0.477 | 0.228 | 0.249 |    NA |    NA | 2.09 | 3.09 | 4.0 |
| median     | 0.487 | 0.215 | 0.272 |    NA |    NA | 2.26 | 3.46 | 3.7 |

Proportions and risk differences are on the `[0, 1]` scale; multiply by
100 for percentages.

``` r

# Random-effects individual method with heterogeneity statistics
responder_analysis(sample_responder_data, mid = 1,
                   method = "individual", pooling = "random")

# Lower change is better (e.g. a symptom score), 90% logit intervals
responder_analysis(sample_responder_data, mid = 1,
                   direction = "lower", ci_type = "logit", conf_level = 0.90)

# Threshold-free: how often does a treated patient respond better than a control?
responder_cles(sample_responder_data)
```

## Data format

One row per study, with these columns (the experimental arm is `_e`, the
control arm `_c`):

| Column     | Meaning                              |
|------------|--------------------------------------|
| `study`    | Study label                          |
| `change_e` | Mean change in the experimental arm  |
| `sd_e`     | SD of change in the experimental arm |
| `n_e`      | Experimental arm sample size         |
| `change_c` | Mean change in the control arm       |
| `sd_c`     | SD of change in the control arm      |
| `n_c`      | Control arm sample size              |

Two datasets ship with the package: `sample_responder_data` (a small toy
example) and `vas_pain`, a real meta-analysis of 20 trials of exercise
for spinal health pooled on the VAS pain scale (Li et al., 2025,
reproduced under CC BY 4.0). Because VAS change is negative when pain
improves, analyze it with `direction = "lower"`:

``` r

# Proportion reaching a 1.5 cm VAS reduction, exercise vs control
responder_analysis(vas_pain, mid = -1.5, direction = "lower",
                   pooling = "random", ci_method = "hksj")
```

## Methods

A responder is a patient whose change crosses the MID. Under a Normal
model an arm’s responder probability is `p = Phi((mu - mid) / sigma)`
(for `direction = "higher"`). The methods differ in how the per-arm
summaries are pooled across studies before, or after, dichotomizing.

| Method | What it pools | Variance / CI | Notes |
|----|----|----|----|
| `individual` | Per-study risk differences (fixed/random) | Yes | Most defensible; the default workhorse |
| `weighted` | IV-pooled mean + within-study pooled SD | Delta method | Paper-aligned pool-then-dichotomize |
| `unweighted` | Arithmetic mean of study means/SDs | None | Sensitivity summary (point estimate) |
| `median` | Median of study means/SDs | None | Robustness summary (point estimate) |
| `smd` | Standardized mean difference to odds ratio | Delta method | Cox logistic bridge; opt-in |

The control proportion always uses the **same** pooling as the
experimental arm.

**Effect measures.** Every method that yields proportions reports the
absolute **risk difference**, the relative **risk ratio** and **odds
ratio**, and the **number needed to treat**.
[`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md)
adds the threshold-free **common-language effect size** (probabilistic
index).

**Options.** `pooling = "random"` (DerSimonian-Laird or REML),
`ci_type = "logit"` for bounded intervals, `se_method` for the
individual SE model, `mid_sd` to propagate MID uncertainty, and
`dist = "lognormal"`/`"t"` for non-Normal change scores.

## Key functions

| Function | Purpose |
|----|----|
| [`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md) | Pooled responder proportions and effect measures |
| [`responder_rd_individual()`](https://choxos.github.io/respondeR/reference/responder_rd_individual.md) | Per-study risk differences (forest-plot input) |
| [`responder_proportions()`](https://choxos.github.io/respondeR/reference/responder_proportions.md) | Per-arm responder probabilities with variances |
| [`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md) | Threshold-free common-language effect size |
| [`format_responder_results()`](https://choxos.github.io/respondeR/reference/format_responder_results.md) | Display-ready formatting |
| [`launch_responder_analysis()`](https://choxos.github.io/respondeR/reference/launch_responder_analysis.md) | Launch the Shiny application |

## The Shiny application

The package bundles a point-and-click app: upload a CSV or use the
bundled example, set the MID and direction, choose methods and options,
and view the results table, per-study forest plot and CLES, with CSV
downloads.

``` r

launch_responder_analysis()
```

The same tool runs entirely in your browser (no R, no install) at
<https://choxos.github.io/respondeR/app>.

## Vignettes

- [`vignette("respondeR")`](https://choxos.github.io/respondeR/articles/respondeR.md):
  getting started; data format, a worked example, and interpreting the
  output.
- [`vignette("methodology")`](https://choxos.github.io/respondeR/articles/methodology.md):
  the statistics in full; the cut-point approach, each method and its
  variance, the relative measures, CLES, the SMD bridge, heterogeneity,
  assumptions and a method-choice guide.

## References

> Sofi-Mahmudi, A. (2024). Identifying an optimal strategy for
> converting pain as a continuous outcome to a responder analysis
> \[Master’s thesis, McMaster University\]. MacSphere.
> <http://hdl.handle.net/11375/30210>

> Thorlund, K., Walter, S. D., Johnston, B. C., Furukawa, T. A., &
> Guyatt, G. H. (2011). Pooling health-related quality of life outcomes
> in meta-analysis: a tutorial and review of methods for enhancing
> interpretability. *Research Synthesis Methods*, 2(3), 188 to 203.
> [doi:10.1002/jrsm.46](https://doi.org/10.1002/jrsm.46)

> Anzures-Cabrera, J., Sarpatwari, A., & Higgins, J. P. T. (2011).
> Expressing findings from meta-analyses of continuous outcomes in terms
> of risks. *Statistics in Medicine*, 30(25), 2867 to 2880.
> [doi:10.1002/sim.4298](https://doi.org/10.1002/sim.4298)

> McGraw, K. O., & Wong, S. P. (1992). A common language effect size
> statistic. *Psychological Bulletin*, 111(2), 361 to 365.

> Chinn, S. (2000). A simple method for converting an odds ratio to
> effect size for use in meta-analysis. *Statistics in Medicine*,
> 19(22), 3127 to 3131.

Bundled data:

> Li, Z., Bao, Z., Wang, S., & Zhao, M. (2025). Meta-analysis of the
> best exercise mode and dose study for improving spinal health.
> *Frontiers in Sports and Active Living*, 7, 1614906.
> [doi:10.3389/fspor.2025.1614906](https://doi.org/10.3389/fspor.2025.1614906)
> (the `vas_pain` dataset, Figure 3, reproduced under CC BY 4.0).

## Citing respondeR

``` r

citation("respondeR")
```

## The logo

The hex logo shows two Normal change-score distributions, control and
experimental, split by a dashed MID cut-point. The shaded tails beyond
the cut are the responder proportions in each arm; their contrast is the
risk difference. That is responder analysis in one picture.

## Author

[Ahmad Sofi-Mahmudi](https://orcid.org/0000-0001-6829-0823)

## License

GPL-3. See <https://www.gnu.org/licenses/gpl-3.0> for the full license
text.
