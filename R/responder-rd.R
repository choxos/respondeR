#' Responder proportions from continuous arm summaries
#'
#' Estimates, for each study arm, the probability that a patient's change score
#' crosses the minimal important difference (MID) threshold under a Normal model
#' for the change scores, together with a delta-method variance for that
#' probability.
#'
#' For an arm with mean change \eqn{\mu}, SD \eqn{\sigma} and size \eqn{n}, and
#' threshold \eqn{m}, the responder probability is
#' \eqn{p = \Phi((\mu - m) / \sigma)} when `direction = "higher"` and
#' \eqn{p = \Phi((m - \mu) / \sigma)} when `direction = "lower"`. The variance is
#' obtained by the delta method, propagating the uncertainty in the estimated
#' mean (\eqn{\sigma^2 / n}) and SD (\eqn{\sigma^2 / (2(n - 1))}).
#'
#' @param change Numeric vector of mean change scores.
#' @param sd Numeric vector of standard deviations (must be `> 0`).
#' @param n Numeric vector of sample sizes (must be `>= 2`).
#' @param mid Single finite number: the minimal important difference threshold.
#' @param direction Either `"higher"` (a larger change indicates response) or
#'   `"lower"` (a smaller change indicates response).
#'
#' @return A data frame with one row per input element and columns:
#'   \describe{
#'     \item{p}{Responder probability in `[0, 1]`.}
#'     \item{var_p}{Delta-method variance of `p`.}
#'   }
#'
#' @references
#' Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011).
#' Expressing findings from meta-analyses of continuous outcomes in terms of
#' risks. \emph{Statistics in Medicine}, 30(25), 2867-2880.
#' \doi{10.1002/sim.4298}
#'
#' @examples
#' responder_proportions(
#'   change = c(0.96, 0.79, 1.02),
#'   sd = c(1.26, 1.28, 1.34),
#'   n = c(43, 139, 156),
#'   mid = 1
#' )
#' @export
responder_proportions <- function(change, sd, n, mid,
                                   direction = c("higher", "lower")) {
  direction <- match.arg(direction)
  validate_mid(mid)
  lengths <- c(length(change), length(sd), length(n))
  if (length(unique(lengths)) != 1L) {
    stop("`change`, `sd` and `n` must have the same length.", call. = FALSE)
  }
  if (any(!is.finite(change))) {
    stop("`change` must be finite.", call. = FALSE)
  }
  if (any(sd <= 0)) {
    stop("`sd` must be greater than 0.", call. = FALSE)
  }
  if (any(n < 2)) {
    stop("`n` must be at least 2.", call. = FALSE)
  }

  data.frame(
    p = responder_p(change, sd, mid, direction),
    var_p = responder_p_var(change, sd, n, mid)
  )
}

#' Per-study responder risk differences
#'
#' Dichotomises each study at the MID threshold and returns the per-study
#' responder risk difference (experimental minus control) with a confidence
#' interval. This is the building block for the `"individual"` method of
#' [responder_analysis()] and feeds the forest plot / per-study table.
#'
#' @inheritParams responder_analysis
#'
#' @return A data frame with one row per study and columns `study`, `p_e`,
#'   `p_c`, `rd`, `se`, `ci_lb`, `ci_ub`. Proportions and risk differences are
#'   on the `[0, 1]` (proportion) scale.
#'
#' @seealso [responder_analysis()]
#'
#' @examples
#' responder_rd_individual(sample_responder_data, mid = 1)
#' @export
responder_rd_individual <- function(data, mid,
                                    direction = c("higher", "lower"),
                                    se_method = c("binomial", "delta"),
                                    conf_level = 0.95) {
  direction <- match.arg(direction)
  se_method <- match.arg(se_method)
  validate_mid(mid)
  validate_conf_level(conf_level)
  data <- validate_responder_data(data)

  p_e <- responder_p(data$change_e, data$sd_e, mid, direction)
  p_c <- responder_p(data$change_c, data$sd_c, mid, direction)
  rd <- p_e - p_c

  if (se_method == "binomial") {
    var_rd <- p_e * (1 - p_e) / data$n_e + p_c * (1 - p_c) / data$n_c
  } else {
    var_rd <- responder_p_var(data$change_e, data$sd_e, data$n_e, mid) +
      responder_p_var(data$change_c, data$sd_c, data$n_c, mid)
  }
  se <- sqrt(var_rd)
  z <- stats::qnorm((1 + conf_level) / 2)

  data.frame(
    study = data$study,
    p_e = p_e,
    p_c = p_c,
    rd = rd,
    se = se,
    ci_lb = rd - z * se,
    ci_ub = rd + z * se,
    stringsAsFactors = FALSE
  )
}
