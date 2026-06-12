# Responder analysis of continuous trial outcomes

Converts continuous outcomes (mean change, SD and sample size per arm,
across studies) into responder proportions and a range of between-arm
effect measures: the risk difference (RD), risk ratio (RR), odds ratio
(OR) and number needed to treat (NNT), under a parametric model for the
change scores. Responders are defined by a minimal important difference
(MID) threshold (the cut-point / "dichotomization" approach of
Anzures-Cabrera, Sarpatwari and Higgins, 2011). For a threshold-free
alternative see
[`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md).

## Usage

``` r
responder_analysis(
  data,
  mid,
  direction = c("higher", "lower"),
  method = c("individual", "weighted", "unweighted", "median", "smd"),
  se_method = c("binomial", "delta"),
  pooling = c("fixed", "random"),
  control = c("matched", "median"),
  tau_method = c("DL", "REML"),
  dist = c("normal", "lognormal", "t"),
  df = NULL,
  mid_sd = 0,
  ci_type = c("wald", "logit"),
  ci_method = c("wald", "hksj"),
  conf_level = 0.95
)
```

## Arguments

- data:

  A data frame with one row per study and columns `study`, `change_e`,
  `sd_e`, `n_e`, `change_c`, `sd_c`, `n_c`. See
  [sample_responder_data](https://choxos.github.io/respondeR/reference/sample_responder_data.md).

- mid:

  Single finite number: the minimal important difference threshold.

- direction:

  `"higher"` (a larger change indicates response) or `"lower"`.

- method:

  Methods to compute: any of `"individual"`, `"weighted"`,
  `"unweighted"`, `"median"`, `"smd"`. Defaults to the first four.

- se_method:

  Per-study SE model for `"individual"`: `"binomial"` (default) or
  `"delta"`. The `"binomial"` variance `p(1 - p) / n` is a
  pseudo-binomial approximation: `p` is a probability implied by the
  estimated mean and SD, not a proportion of observed dichotomized
  patients, so it does not include the uncertainty in the reported mean
  and SD. `"delta"` propagates that uncertainty and is generally
  preferable for summary-statistic inputs; `"binomial"` is the default
  only for continuity with earlier results.

- pooling:

  `"fixed"` (default) or `"random"` effects, for the `"individual"` and
  `"smd"` methods.

- control:

  Baseline-risk rule for the summary methods (`median`, `unweighted`,
  `weighted`): `"matched"` (default) pools the control arm the same way
  as the experimental arm; `"median"` always takes the control responder
  proportion from the median control arm (the Sofi-Mahmudi 2024
  baseline), which yields point estimates only. Ignored by
  `"individual"` and `"smd"`.

- tau_method:

  Between-study variance estimator when `pooling = "random"`: `"DL"`
  (DerSimonian-Laird, default) or `"REML"` (needs the `metafor` package;
  falls back to DL with a warning if unavailable).

- dist:

  Change-score distribution: `"normal"` (default), `"lognormal"` or
  `"t"`.

- df:

  Degrees of freedom when `dist = "t"`.

- mid_sd:

  Optional standard deviation of the MID threshold; when `> 0` its
  uncertainty is propagated into the effect-measure variances.

- ci_type:

  `"wald"` (default) or `"logit"` (keeps proportion and risk-difference
  intervals within valid bounds via the logit transform and Newcombe's
  MOVER method).

- ci_method:

  Random-effects interval method: `"wald"` (Normal, default) or `"hksj"`
  (Hartung-Knapp-Sidik-Jonkman, a `t`-based interval that is better
  calibrated when the number of studies is small).

- conf_level:

  Confidence level (default `0.95`).

## Value

A data frame with one row per requested method and columns: `method`,
`pooling`, `k`, `p_e`, `p_c`, `rd`/`rd_lb`/`rd_ub`,
`rr`/`rr_lb`/`rr_ub`, `or`/`or_lb`/`or_ub`, `nnt`/`nnt_lb`/`nnt_ub`,
`var_rd`, and the heterogeneity statistics `tau2`, `i2`, `q`, `q_p`,
`pi_lb`, `pi_ub` (for the pooled methods). Proportions, risk differences
and CLES are on the proportion scale; multiply by 100 for percentages.

## Methods

- `individual`:

  Dichotomize each study, then pool the per-study effect measures (fixed
  or random effects). The most defensible option; the per-study SE
  follows `se_method`.

- `weighted`:

  Pool the mean change by inverse variance and the SD by the
  within-study pooled SD, dichotomize the pooled summaries, and obtain
  variances by the delta method.

- `unweighted`, `median`:

  Dichotomize the arithmetic mean / median of the study means and SDs.
  Summaries with no variance model: intervals are `NA`.

- `smd`:

  Pool the standardized mean difference (Hedges' g), bridge to an odds
  ratio via the logistic link (`lnOR = (pi / sqrt(3)) g`), and combine
  with the weighted-pooled control responder rate to recover risks. The
  second approach of the reference; not included by default.

For the summary methods (`median`, `unweighted`, `weighted`) the control
proportion is, by default, pooled the same way as the experimental arm
(`control = "matched"`). Set `control = "median"` to instead take the
baseline risk from the median control arm for every summary method, as
in the Sofi-Mahmudi (2024) simulation study; the experimental arm is
still pooled by the chosen method. Because the median control arm
carries no sampling-variance model, `control = "median"` reports point
estimates only (no intervals) for the summary methods. The `individual`
and `smd` methods pool per-study contrasts and ignore `control`.

## References

Sofi-Mahmudi A (2024). Identifying an optimal strategy for converting
pain as a continuous outcome to a responder analysis. Master's thesis,
McMaster University. <https://hdl.handle.net/11375/30210>

Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011).
Pooling health-related quality of life outcomes in meta-analysis: a
tutorial and review of methods for enhancing interpretability. *Research
Synthesis Methods*, 2(3), 188 to 203.
[doi:10.1002/jrsm.46](https://doi.org/10.1002/jrsm.46)

Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings
from meta-analyses of continuous outcomes in terms of risks. *Statistics
in Medicine*, 30(25), 2867 to 2880.
[doi:10.1002/sim.4298](https://doi.org/10.1002/sim.4298)

## See also

[`responder_rd_individual()`](https://choxos.github.io/respondeR/reference/responder_rd_individual.md),
[`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md),
[`responder_proportions()`](https://choxos.github.io/respondeR/reference/responder_proportions.md)

## Examples

``` r
responder_analysis(sample_responder_data, mid = 1)
#>       method pooling k       p_e       p_c        rd     rd_lb     rd_ub
#> 1 individual   fixed 3        NA        NA 0.2554475 0.1869705 0.3239244
#> 2   weighted    <NA> 3 0.4742782 0.2205372 0.2537410 0.1985865 0.3088955
#> 3 unweighted    <NA> 3 0.4767051 0.2279613 0.2487438        NA        NA
#> 4     median    <NA> 3 0.4869694 0.2150781 0.2718912        NA        NA
#>         rr    rr_lb    rr_ub       or    or_lb    or_ub      nnt   nnt_lb
#> 1 2.148809 1.712779 2.695841 3.198098 2.296864 4.452953 3.914699 3.087140
#> 2 2.150558 1.790679 2.582764 3.188531 2.442773 4.161963 3.941027 3.237341
#> 3 2.091167       NA       NA 3.085185       NA       NA 4.020201       NA
#> 4 2.264151       NA       NA 3.464085       NA       NA 3.677941       NA
#>     nnt_ub       var_rd tau2 i2      q       q_p pi_lb pi_ub
#> 1 5.348437 0.0012206534    0  0 1.6054 0.4481173    NA    NA
#> 2 5.035589 0.0007918911   NA NA     NA        NA    NA    NA
#> 3       NA           NA   NA NA     NA        NA    NA    NA
#> 4       NA           NA   NA NA     NA        NA    NA    NA

# Random-effects individual method with relative measures:
responder_analysis(sample_responder_data, mid = 1,
  method = "individual", pooling = "random")
#>       method pooling k p_e p_c        rd     rd_lb     rd_ub       rr    rr_lb
#> 1 individual  random 3  NA  NA 0.2554475 0.1869705 0.3239244 2.148809 1.712779
#>      rr_ub       or    or_lb    or_ub      nnt  nnt_lb   nnt_ub      var_rd
#> 1 2.695841 3.198098 2.296864 4.452953 3.914699 3.08714 5.348437 0.001220653
#>   tau2 i2      q       q_p    pi_lb     pi_ub
#> 1    0  0 1.6054 0.4481173 -0.18848 0.6993749
```
