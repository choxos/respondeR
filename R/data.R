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
