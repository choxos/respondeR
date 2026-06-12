# Responder proportions from continuous arm summaries

Estimates, for each study arm, the probability that a patient's change
score crosses the minimal important difference (MID) threshold under a
parametric model for the change scores, together with a delta-method
(sampling) variance for that probability.

## Usage

``` r
responder_proportions(
  change,
  sd,
  n,
  mid,
  direction = c("higher", "lower"),
  dist = c("normal", "lognormal", "t"),
  df = NULL
)
```

## Arguments

- change:

  Numeric vector of mean change scores.

- sd:

  Numeric vector of standard deviations (`> 0`).

- n:

  Numeric vector of sample sizes (`>= 2`).

- mid:

  Single finite number: the minimal important difference threshold.

- direction:

  `"higher"` (a larger change indicates response) or `"lower"`.

- dist:

  Change-score distribution: `"normal"` (default), `"lognormal"` or
  `"t"`.

- df:

  Degrees of freedom when `dist = "t"`.

## Value

A data frame with one row per input element and columns `p` (responder
probability) and `var_p` (delta-method variance).

## References

Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011).
Pooling health-related quality of life outcomes in meta-analysis – a
tutorial and review of methods for enhancing interpretability. *Research
Synthesis Methods*, 2(3), 188-203.
[doi:10.1002/jrsm.46](https://doi.org/10.1002/jrsm.46)

Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings
from meta-analyses of continuous outcomes in terms of risks. *Statistics
in Medicine*, 30(25), 2867-2880.
[doi:10.1002/sim.4298](https://doi.org/10.1002/sim.4298)

## Examples

``` r
responder_proportions(
  change = c(0.96, 0.79, 1.02), sd = c(1.26, 1.28, 1.34),
  n = c(43, 139, 156), mid = 1
)
#>           p       var_p
#> 1 0.4873373 0.003699457
#> 2 0.4348410 0.001129700
#> 3 0.5059541 0.001020111
```
