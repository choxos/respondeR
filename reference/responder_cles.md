# Common-language effect size (probabilistic index)

A threshold-free responder-type measure: the probability that a randomly
chosen treated patient has a better change score than a randomly chosen
control. Under a Normal model this is exact, \\\mathrm{CLES} =
\Phi(\delta)\\ with \\\delta = (\mu_e - \mu_c) / \sqrt{\sigma_e^2 +
\sigma_c^2}\\ (the sign is flipped when `direction = "lower"`).
Per-study \\\delta\\ values are pooled by fixed- or random-effect
inverse variance and back-transformed, so no minimal important
difference is required.

## Usage

``` r
responder_cles(
  data,
  direction = c("higher", "lower"),
  pooling = c("fixed", "random"),
  tau_method = c("DL", "REML"),
  conf_level = 0.95
)
```

## Arguments

- data:

  A data frame with columns `study`, `change_e`, `sd_e`, `n_e`,
  `change_c`, `sd_c`, `n_c`. See
  [sample_responder_data](https://choxos.github.io/respondeR/reference/sample_responder_data.md).

- direction:

  `"higher"` (a larger change is better) or `"lower"`.

- pooling:

  `"fixed"` (default) or `"random"` effects.

- tau_method:

  Between-study variance estimator for random effects: `"DL"` (default)
  or `"REML"`.

- conf_level:

  Confidence level (default `0.95`).

## Value

A list with:

- studies:

  Per-study data frame: `study`, `delta`, `cles`, `cles_lb`, `cles_ub`.

- cles, cles_lb, cles_ub:

  Pooled CLES and its interval.

- delta, se_delta:

  Pooled standardised difference and its SE.

- tau2, i2, q, q_p, pi_lb, pi_ub:

  Heterogeneity statistics; the prediction interval is back-transformed
  to the CLES scale.

- pooling, k:

  Settings echoed back.

## References

McGraw KO, Wong SP (1992). A common language effect size statistic.
*Psychological Bulletin*, 111(2), 361-365.

## Examples

``` r
cles <- responder_cles(sample_responder_data)
cles$cles
#> [1] 0.6899041
```
