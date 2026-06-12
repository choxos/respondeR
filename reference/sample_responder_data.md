# Example responder-analysis dataset

A small illustrative dataset of three trials reporting continuous change
scores per arm. Used in examples, the bundled Shiny app and the package
tests. Values are fictional but plausible.

## Usage

``` r
sample_responder_data
```

## Format

A data frame with 3 rows and 7 columns:

- study:

  Study identifier.

- change_e:

  Mean change in the experimental arm.

- sd_e:

  Standard deviation of change in the experimental arm.

- n_e:

  Sample size of the experimental arm.

- change_c:

  Mean change in the control arm.

- sd_c:

  Standard deviation of change in the control arm.

- n_c:

  Sample size of the control arm.

## Examples

``` r
responder_analysis(sample_responder_data, mid = 1)
#>       method pooling k       p_e       p_c        rd     rd_lb     rd_ub
#> 1 individual   fixed 3        NA        NA 0.2554475 0.1869705 0.3239244
#> 2   weighted    <NA> 3 0.4742782 0.2205372 0.2537410 0.2012903 0.3061917
#> 3 unweighted    <NA> 3 0.4767051 0.2279613 0.2487438        NA        NA
#> 4     median    <NA> 3 0.4869694 0.2150781 0.2718912        NA        NA
#>         rr    rr_lb    rr_ub       or    or_lb    or_ub      nnt   nnt_lb
#> 1 2.148809 1.712779 2.695841 3.198098 2.296864 4.452953 3.914699 3.087140
#> 2 2.150558 1.821290 2.539355 3.188531 2.489707 4.083504 3.941027 3.265928
#> 3 2.091167       NA       NA 3.085185       NA       NA 4.020201       NA
#> 4 2.264151       NA       NA 3.464085       NA       NA 3.677941       NA
#>     nnt_ub       var_rd tau2 i2      q       q_p pi_lb pi_ub
#> 1 5.348437 0.0012206534    0  0 1.6054 0.4481173    NA    NA
#> 2 4.967949 0.0007161536   NA NA     NA        NA    NA    NA
#> 3       NA           NA   NA NA     NA        NA    NA    NA
#> 4       NA           NA   NA NA     NA        NA    NA    NA
```
