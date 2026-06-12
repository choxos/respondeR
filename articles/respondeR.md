# Getting started with respondeR

``` r

library(respondeR)
```

## The idea

Trials of continuous outcomes usually report a **mean change** and
**standard deviation** in each arm. Those are hard to communicate: a
standardised mean difference of 0.3 means little to a patient. A
**responder analysis** translates the continuous result into something
concrete — the proportion of patients who improve by at least a
**minimal important difference (MID)** — and contrasts the arms on
familiar scales: risk difference, risk ratio, odds ratio, number needed
to treat.

respondeR does this from summary statistics alone, using the cut-point
approach of Anzures-Cabrera, Sarpatwari & Higgins (2011). It never needs
individual patient data.

## Data format

One row per study. The experimental arm columns end in `_e`, the control
arm in `_c`:

``` r

sample_responder_data
#>     study  change_e     sd_e n_e     change_c     sd_c n_c
#> 1 Study 1 0.9581395 1.257593  43  0.217777778 1.195501  45
#> 2 Study 2 0.7920863 1.281364 139  0.003448276 1.324629 145
#> 3 Study 3 1.0230769 1.341201 156 -0.041975309 1.263178 162
```

| Column                 | Meaning              |
|------------------------|----------------------|
| `study`                | Study label          |
| `change_e`, `change_c` | Mean change per arm  |
| `sd_e`, `sd_c`         | SD of change per arm |
| `n_e`, `n_c`           | Sample size per arm  |

## A first analysis

Suppose a change above `1` is clinically meaningful. With the default
settings,
[`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md)
returns one row per pooling method:

``` r

res <- responder_analysis(sample_responder_data, mid = 1)
res[, c("method", "p_e", "p_c", "rd", "rd_lb", "rd_ub", "rr", "or", "nnt")]
#>       method       p_e       p_c        rd     rd_lb     rd_ub       rr
#> 1 individual        NA        NA 0.2554475 0.1869705 0.3239244 2.148809
#> 2   weighted 0.4742782 0.2205372 0.2537410 0.2012903 0.3061917 2.150558
#> 3 unweighted 0.4767051 0.2279613 0.2487438        NA        NA 2.091167
#> 4     median 0.4869694 0.2150781 0.2718912        NA        NA 2.264151
#>         or      nnt
#> 1 3.198098 3.914699
#> 2 3.188531 3.941027
#> 3 3.085185 4.020201
#> 4 3.464085 3.677941
```

- `p_e`, `p_c` are the experimental and control responder proportions
  (on the `[0, 1]` scale).
- `rd`, `rr`, `or`, `nnt` are the between-arm contrasts, each with a
  confidence interval (`*_lb`, `*_ub`).
- The `individual` method pools per-study risk differences, so it
  reports a pooled `rd` but leaves `p_e`/`p_c` as `NA`.

For a quick, readable summary use
[`format_responder_results()`](https://choxos.github.io/respondeR/reference/format_responder_results.md):

``` r

format_responder_results(res)
#>            Method   PE   PC                  RD                  RR
#> 1      Individual    -    - 25.5 (18.7 to 32.4) 2.15 (1.71 to 2.70)
#> 2   Weighted mean 47.4 22.1 25.4 (20.1 to 30.6) 2.15 (1.82 to 2.54)
#> 3 Unweighted mean 47.7 22.8                24.9                2.09
#> 4          Median 48.7 21.5                27.2                2.26
#>                    OR
#> 1 3.20 (2.30 to 4.45)
#> 2 3.19 (2.49 to 4.08)
#> 3                3.09
#> 4                3.46
```

## Which way is “better”?

By default a *higher* change is a response. For outcomes where *lower*
is better (pain, symptom scores), set `direction = "lower"`:

``` r

responder_analysis(sample_responder_data, mid = 1, direction = "lower",
                   method = "individual")[, c("method", "rd", "rd_lb", "rd_ub")]
#>       method         rd      rd_lb      rd_ub
#> 1 individual -0.2554475 -0.3239244 -0.1869705
```

## Per-study results and a forest plot

[`responder_rd_individual()`](https://choxos.github.io/respondeR/reference/responder_rd_individual.md)
returns the per-study risk differences that feed a forest plot:

``` r

responder_rd_individual(sample_responder_data, mid = 1)
#>     study       p_e       p_c        rd         se      ci_lb     ci_ub
#> 1 Study 1 0.4867232 0.2564577 0.2302655 0.10023645 0.03380566 0.4267253
#> 2 Study 2 0.4355507 0.2259278 0.2096229 0.05454152 0.10272350 0.3165223
#> 3 Study 3 0.5068639 0.2047187 0.3021452 0.05106129 0.20206690 0.4022235
```

``` r

ps <- responder_rd_individual(sample_responder_data, mid = 1)
pooled <- responder_analysis(sample_responder_data, mid = 1, method = "individual")

y <- rev(seq_len(nrow(ps) + 1))
est <- c(ps$rd, pooled$rd) * 100
lo  <- c(ps$ci_lb, pooled$rd_lb) * 100
hi  <- c(ps$ci_ub, pooled$rd_ub) * 100
labels <- c(as.character(ps$study), "Pooled")

op <- par(mar = c(4, 6, 1, 1))
plot(NA, xlim = range(c(lo, hi, 0)), ylim = c(0.5, length(y) + 0.5),
     yaxt = "n", xlab = "Risk difference (%)", ylab = "", bty = "n")
abline(v = 0, lty = 2, col = "grey60")
segments(lo, y, hi, y, lwd = 2)
points(est, y, pch = c(rep(15, nrow(ps)), 18), cex = c(rep(1.4, nrow(ps)), 2))
axis(2, at = y, labels = labels, las = 1, tick = FALSE)
```

![Forest plot of per-study responder risk
differences](respondeR_files/figure-html/unnamed-chunk-7-1.png)

``` r

par(op)
```

## Random effects and heterogeneity

When studies disagree, use random-effects pooling. respondeR reports
Cochran’s Q, I-squared, tau-squared and a prediction interval:

``` r

responder_analysis(sample_responder_data, mid = 1, method = "individual",
                   pooling = "random")[, c("method", "rd", "rd_lb", "rd_ub",
                                           "tau2", "i2", "pi_lb", "pi_ub")]
#>       method        rd     rd_lb     rd_ub tau2 i2    pi_lb     pi_ub
#> 1 individual 0.2554475 0.1869705 0.3239244    0  0 -0.18848 0.6993749
```

## A threshold-free alternative

Choosing a MID is sometimes contentious. The common-language effect size
sidesteps it entirely: the probability that a randomly chosen treated
patient responds better than a randomly chosen control.

``` r

cles <- responder_cles(sample_responder_data)
sprintf("CLES = %.1f%% (%.1f%% to %.1f%%)",
        100 * cles$cles, 100 * cles$cles_lb, 100 * cles$cles_ub)
#> [1] "CLES = 69.0% (65.1% to 72.7%)"
```

## The Shiny application

Everything above is available in a point-and-click app:

``` r

launch_responder_analysis()
```

The same tool runs in the browser, with no installation, at
<https://choxos.github.io/respondeR/app>.

## Where next

See
[`vignette("methodology")`](https://choxos.github.io/respondeR/articles/methodology.md)
for the full statistical detail: each method’s estimator and variance,
the relative measures, the SMD bridge, the
logit/MID-uncertainty/distribution options, assumptions and a
method-choice guide.
