#' Common-language effect size (probabilistic index)
#'
#' A threshold-free responder-type measure: the probability that a randomly
#' chosen treated patient has a better change score than a randomly chosen
#' control. Under a Normal model this is exact,
#' \eqn{\mathrm{CLES} = \Phi(\delta)} with
#' \eqn{\delta = (\mu_e - \mu_c) / \sqrt{\sigma_e^2 + \sigma_c^2}}
#' (the sign is flipped when `direction = "lower"`). Per-study \eqn{\delta} values
#' are pooled by fixed- or random-effect inverse variance and back-transformed,
#' so no minimal important difference is required.
#'
#' @param data A data frame with columns `study`, `change_e`, `sd_e`, `n_e`,
#'   `change_c`, `sd_c`, `n_c`. See [sample_responder_data].
#' @param direction `"higher"` (a larger change is better) or `"lower"`.
#' @param pooling `"fixed"` (default) or `"random"` effects.
#' @param tau_method Between-study variance estimator for random effects:
#'   `"DL"` (default) or `"REML"`.
#' @param ci_method Random-effects interval method: `"wald"` (default) or
#'   `"hksj"` (Hartung-Knapp-Sidik-Jonkman, better for small numbers of studies).
#' @param conf_level Confidence level (default `0.95`).
#'
#' @return A list with:
#'   \describe{
#'     \item{studies}{Per-study data frame: `study`, `delta`, `cles`, `cles_lb`,
#'       `cles_ub`.}
#'     \item{cles, cles_lb, cles_ub}{Pooled CLES and its interval.}
#'     \item{delta, se_delta}{Pooled standardized difference and its SE.}
#'     \item{tau2, i2, q, q_p, pi_lb, pi_ub}{Heterogeneity statistics; the
#'       prediction interval is back-transformed to the CLES scale.}
#'     \item{pooling, k}{Settings echoed back.}
#'   }
#'
#' @references
#' McGraw KO, Wong SP (1992). A common language effect size statistic.
#' \emph{Psychological Bulletin}, 111(2), 361 to 365.
#'
#' @examples
#' cles <- responder_cles(sample_responder_data)
#' cles$cles
#' @export
responder_cles <- function(data,
                           direction = c("higher", "lower"),
                           pooling = c("fixed", "random"),
                           tau_method = c("DL", "REML"),
                           ci_method = c("wald", "hksj"),
                           conf_level = 0.95) {
  direction <- match.arg(direction)
  pooling <- match.arg(pooling)
  tau_method <- match.arg(tau_method)
  ci_method <- match.arg(ci_method)
  validate_conf_level(conf_level)
  data <- validate_responder_data(data)

  sgn <- if (direction == "higher") 1 else -1
  ne <- data$n_e
  nc <- data$n_c
  s2 <- data$sd_e^2 + data$sd_c^2
  s <- sqrt(s2)
  d_num <- sgn * (data$change_e - data$change_c)
  delta <- d_num / s

  var_delta <- (data$sd_e^2 / ne + data$sd_c^2 / nc) / s2 +
    d_num^2 * (data$sd_e^4 / (2 * (ne - 1)) + data$sd_c^4 / (2 * (nc - 1))) / s2^3

  z <- stats::qnorm((1 + conf_level) / 2)
  studies <- data.frame(
    study = data$study,
    delta = delta,
    cles = stats::pnorm(delta),
    cles_lb = stats::pnorm(delta - z * sqrt(var_delta)),
    cles_ub = stats::pnorm(delta + z * sqrt(var_delta)),
    stringsAsFactors = FALSE
  )

  pool <- re_pool(delta, var_delta, conf_level, tau_method, ci_method)
  s_d <- pick_pool(pool, pooling, conf_level)
  pi_lb <- if (pooling == "random") stats::pnorm(pool$pi_lb) else NA_real_
  pi_ub <- if (pooling == "random") stats::pnorm(pool$pi_ub) else NA_real_

  list(
    studies = studies,
    cles = stats::pnorm(s_d$est),
    cles_lb = stats::pnorm(s_d$lb),
    cles_ub = stats::pnorm(s_d$ub),
    delta = s_d$est,
    se_delta = sqrt(s_d$var),
    tau2 = pool$tau2, i2 = pool$i2, q = pool$q, q_p = pool$q_p,
    pi_lb = pi_lb, pi_ub = pi_ub,
    pooling = pooling, k = nrow(data)
  )
}
