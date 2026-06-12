# Launch the Responder Analysis Shiny application

Starts the bundled Shiny application, a point-and-click front end to
[`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md):
upload data (or load the example), set the MID and direction of benefit,
and view, plot and download the results.

## Usage

``` r
launch_responder_analysis(...)
```

## Arguments

- ...:

  Additional arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Called for its side effect of launching the app; invisibly returns the
value of [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Examples

``` r
if (FALSE) { # interactive()
launch_responder_analysis()
}
```
