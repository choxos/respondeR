# VAS pain change scores from a spinal-health exercise meta-analysis

Per-study change in pain on a 0-10 cm visual analogue scale (VAS) for an
exercise-therapy arm versus a control arm, from the 20 randomized trials
pooled for the VAS outcome by Li, Bao, Wang and Zhao (2025). The change
scores are post minus baseline VAS, so a more negative value is a larger
pain reduction; analyze with `direction = "lower"` and a negative MID
equal to the required reduction (for example `mid = -1.5` for a 1.5 cm
responder threshold).

## Usage

``` r
vas_pain
```

## Format

A data frame with 20 rows and 7 columns:

- study:

  Study label (first author and year).

- change_e:

  Mean VAS change in the exercise (experimental) arm.

- sd_e:

  Standard deviation of the change in the exercise arm.

- n_e:

  Exercise-arm sample size.

- change_c:

  Mean VAS change in the control arm.

- sd_c:

  Standard deviation of the change in the control arm.

- n_c:

  Control-arm sample size.

## Source

Li Z, Bao Z, Wang S, Zhao M (2025). Meta-analysis of the best exercise
mode and dose study for improving spinal health. *Frontiers in Sports
and Active Living*, 7, 1614906.
[doi:10.3389/fspor.2025.1614906](https://doi.org/10.3389/fspor.2025.1614906)
. Figure 3 (VAS pain). Reproduced under the Creative Commons Attribution
License (CC BY 4.0); the original authors and journal are credited as
required.

## Examples

``` r
# Proportion achieving at least a 1.5 cm VAS reduction (responder),
# exercise versus control, random-effects with HKSJ intervals.
responder_analysis(vas_pain, mid = -1.5, direction = "lower",
  pooling = "random", ci_method = "hksj")
#>       method pooling  k       p_e       p_c        rd     rd_lb     rd_ub
#> 1 individual  random 20        NA        NA 0.1749569 0.1064748 0.2434389
#> 2   weighted    <NA> 20 0.8437480 0.6342443 0.2095037 0.1822245 0.2367828
#> 3 unweighted    <NA> 20 0.7866327 0.4709021 0.3157305        NA        NA
#> 4     median    <NA> 20 0.8394395 0.3725571 0.4668824        NA        NA
#>         rr    rr_lb    rr_ub       or    or_lb    or_ub      nnt   nnt_lb
#> 1 1.192139 1.080045 1.315868 3.222034 2.273167 4.566978 5.715694 4.107807
#> 2 1.330320 1.280565 1.382008 3.114021 2.633212 3.682624 4.773186 4.223280
#> 3 1.670480       NA       NA 4.142374       NA       NA 3.167258       NA
#> 4 2.253183       NA       NA 8.805054       NA       NA 2.141867       NA
#>     nnt_ub       var_rd        tau2        i2        q        q_p        pi_lb
#> 1 9.391889 0.0008172005 0.006867891 0.5133031 39.03867 0.00436654 -0.009219726
#> 2 5.487736 0.0001937160          NA        NA       NA         NA           NA
#> 3       NA           NA          NA        NA       NA         NA           NA
#> 4       NA           NA          NA        NA       NA         NA           NA
#>       pi_ub
#> 1 0.3591335
#> 2        NA
#> 3        NA
#> 4        NA
```
