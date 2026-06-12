# Format responder-analysis results for display

Turns the numeric output of
[`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md)
into a compact, display-ready data frame: proportions and risk
differences as percentages, the risk ratio and odds ratio with
intervals, and a combined "RD (CI)" string. Used by the bundled Shiny
app and handy for reports.

## Usage

``` r
format_responder_results(results, digits = 1)
```

## Arguments

- results:

  A data frame returned by
  [`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md).

- digits:

  Number of decimal places (default `1`).

## Value

A data frame with character columns `Method`, `PE`, `PC`, `RD`, `RR` and
`OR` (percentages for proportions/RD; ratios for RR/OR). Methods without
a variance model show point estimates only.

## Examples

``` r
format_responder_results(responder_analysis(sample_responder_data, mid = 1))
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
