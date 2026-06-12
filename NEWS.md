# respondeR 0.1.0

First public release. The package began life as a small Shiny app; this release
rebuilds it as a documented, tested R package with the statistics in pure,
exported functions and the Shiny app as a thin front end.

## Robustness and methodology hardening

In response to an external methodology audit:

* **Boundary handling.** Extreme MIDs that push a responder probability to
  exactly 0 or 1 no longer crash or return infinite intervals; probabilities are
  clamped away from 0 and 1 only where they feed logs, logits and weights, while
  the reported proportions and risk difference stay unclamped.
* **Small-study random effects.** Added `ci_method = "hksj"` for the
  Hartung-Knapp-Sidik-Jonkman interval, better calibrated than Wald when the
  number of studies is small.
* **Weighted-method variance** now propagates uncertainty in the pooled SD as
  well as the pooled mean (full delta method), so its intervals are no longer too
  narrow. Weighted confidence intervals are slightly wider than in the first
  build; the point estimates are unchanged.
* **Stricter validation.** Sample sizes must be whole numbers; the lognormal
  model now rejects negative study-arm mean changes before aggregation; and the
  vector building blocks reject non-finite `sd`/`n`.
* The `binomial` SE is documented as a pseudo-binomial approximation, with
  `delta` recommended for summary-statistic inputs.

## Features

* `responder_analysis()`: the main entry point. Converts continuous arm
  summaries (mean change, SD, n) into responder proportions and a tidy table of
  between-arm effect measures: risk difference, risk ratio, odds ratio and
  number needed to treat. Pooling methods: `"individual"`, `"weighted"`,
  `"unweighted"`, `"median"` and `"smd"`.
* `responder_rd_individual()` and `responder_proportions()`: exported building
  blocks for per-study risk differences and arm responder probabilities.
* `responder_cles()`: threshold-free common-language effect size (the
  probabilistic index), pooled fixed or random effects, requiring no MID.
* `format_responder_results()`: display-ready formatting for reports and the
  app.
* `launch_responder_analysis()`: launches the bundled **ResponderAnalysis**
  Shiny application (direction toggle, method/pooling/interval options, RR/OR/NNT,
  a per-study forest plot, CLES and CSV I/O).
* `sample_responder_data`: small bundled example dataset.
* `vas_pain`: a real bundled dataset of 20 exercise-for-spinal-health trials
  pooled on the VAS pain scale (Li et al., 2025, doi:10.3389/fspor.2025.1614906,
  reproduced under CC BY 4.0).

## Methods and options

* **Random effects.** The individual and SMD methods support fixed- or
  random-effects pooling (`pooling = "random"`) with DerSimonian-Laird
  (dependency-free) or REML (`tau_method = "REML"`, via *metafor*) between-study
  variance, reporting Cochran's Q, I-squared, tau-squared and a prediction
  interval.
* **Relative measures.** Risk ratio and odds ratio (log-scale pooling) and
  number needed to treat (Altman, 1998) accompany the absolute risk difference.
* **SMD bridge.** The `"smd"` method pools the standardized mean difference
  (Hedges' g) and maps it to an odds ratio through the logistic link, combined
  with the weighted-pooled control risk (Cox; Chinn, 2000).
* **Refinements.** Logit-transformed proportion intervals and Newcombe MOVER
  risk-difference intervals (`ci_type = "logit"`); propagation of uncertainty in
  the MID threshold (`mid_sd`); alternative change-score distributions
  (`dist = "lognormal"` or `"t"`).
* **Baseline-risk option.** `control = "median"` takes the control responder
  proportion from the median control arm for every summary method (the
  Sofi-Mahmudi 2024 simulation baseline), while still pooling the experimental
  arm by the chosen method; the default `control = "matched"` pools the control
  arm the same way as the experimental arm. Because the median control arm has no
  sampling-variance model, `control = "median"` returns point estimates only.

## Statistical corrections (results differ from the previous app)

The earlier Shiny app contained several errors that are fixed here. Numbers from
the weighted and unweighted methods, and all confidence intervals, will differ
from that app; the individual and median point estimates are unchanged.

* The control responder proportion is, by default, computed with the **same**
  pooling as the experimental arm (previously every method reused the *median*
  method's control proportion). The earlier median-baseline behavior remains
  available as an explicit, documented choice via `control = "median"`.
* The weighted method now pools the SD with the within-study pooled SD
  `sqrt(sum((n-1) sd^2) / sum(n-1))` rather than inverse-variance pooling of SDs,
  with a delta-method variance for the risk difference.
* The median and unweighted methods are reported as point-estimate summaries (no
  variance model) instead of carrying a spurious interval.
* Proportions are kept on the `[0, 1]` scale internally, removing a class of
  percent-scale variance errors.

## Removed

* The unused and incorrect Mantel-Haenszel helpers `rr_meta()`, `rd_meta()` and
  `prop_meta()` (which operated on a 2x2 count format the package never
  produced; `rr_meta()` returned swapped confidence limits) have been removed,
  along with the duplicated, unvalidated `iv_meta()`.

## Infrastructure

* Full **roxygen2** documentation with runnable examples and references.
* A **testthat** suite (104 checks) covering known-answer results, regression
  anchors, edge cases and every method.
* A **pkgdown** website, methodology and getting-started vignettes, and a hex
  logo.
