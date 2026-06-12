#' Example responder-analysis dataset
#'
#' A small illustrative dataset of three trials reporting continuous change
#' scores per arm. Used in examples, the bundled Shiny app and the package
#' tests. Values are fictional but plausible.
#'
#' @format A data frame with 3 rows and 7 columns:
#' \describe{
#'   \item{study}{Study identifier.}
#'   \item{change_e}{Mean change in the experimental arm.}
#'   \item{sd_e}{Standard deviation of change in the experimental arm.}
#'   \item{n_e}{Sample size of the experimental arm.}
#'   \item{change_c}{Mean change in the control arm.}
#'   \item{sd_c}{Standard deviation of change in the control arm.}
#'   \item{n_c}{Sample size of the control arm.}
#' }
#' @examples
#' responder_analysis(sample_responder_data, mid = 1)
"sample_responder_data"

#' VAS pain change scores from a spinal-health exercise meta-analysis
#'
#' Per-study change in pain on a 0-10 cm visual analogue scale (VAS) for an
#' exercise-therapy arm versus a control arm, from the 20 randomized trials
#' pooled for the VAS outcome by Li, Bao, Wang and Zhao (2025). The change scores
#' are post minus baseline VAS, so a more negative value is a larger pain
#' reduction; analyze with `direction = "lower"` and a negative MID equal to the
#' required reduction (for example `mid = -1.5` for a 1.5 cm responder threshold).
#'
#' @format A data frame with 20 rows and 7 columns:
#' \describe{
#'   \item{study}{Study label (first author and year).}
#'   \item{change_e}{Mean VAS change in the exercise (experimental) arm.}
#'   \item{sd_e}{Standard deviation of the change in the exercise arm.}
#'   \item{n_e}{Exercise-arm sample size.}
#'   \item{change_c}{Mean VAS change in the control arm.}
#'   \item{sd_c}{Standard deviation of the change in the control arm.}
#'   \item{n_c}{Control-arm sample size.}
#' }
#'
#' @source
#' Li Z, Bao Z, Wang S, Zhao M (2025). Meta-analysis of the best exercise mode
#' and dose study for improving spinal health. \emph{Frontiers in Sports and
#' Active Living}, 7, 1614906. \doi{10.3389/fspor.2025.1614906}. Figure 3 (VAS
#' pain). Reproduced under the Creative Commons Attribution License (CC BY 4.0);
#' the original authors and journal are credited as required.
#'
#' @examples
#' # Proportion achieving at least a 1.5 cm VAS reduction (responder),
#' # exercise versus control, random-effects with HKSJ intervals.
#' responder_analysis(vas_pain, mid = -1.5, direction = "lower",
#'   pooling = "random", ci_method = "hksj")
"vas_pain"
