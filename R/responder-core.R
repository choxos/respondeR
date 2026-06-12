# Internal statistical helpers for responder analysis.
# These are not exported; they are the building blocks used by the exported
# user-facing functions. Keeping them small and pure makes the methodology
# directly unit-testable.

#' Responder probability under a Normal model
#'
#' Probability that a change score crosses the MID threshold, assuming the
#' change is Normally distributed with the supplied mean and SD.
#'
#' @param mu,sigma Numeric vectors of arm means and SDs (recycled together).
#' @param mid Numeric scalar threshold.
#' @param direction `"higher"` if larger change indicates response (responder
#'   if change > mid), `"lower"` otherwise (responder if change < mid).
#' @return Numeric vector of probabilities in `[0, 1]`.
#' @noRd
responder_p <- function(mu, sigma, mid, direction = c("higher", "lower")) {
  direction <- match.arg(direction)
  z <- (mu - mid) / sigma
  if (direction == "lower") {
    z <- -z
  }
  stats::pnorm(z)
}

#' Delta-method variance of a responder probability
#'
#' Propagates the sampling uncertainty in the estimated arm mean and SD through
#' the Normal CDF. With `a = (mu - mid) / sigma`,
#' `Var(p) = phi(a)^2 * (1 / n + a^2 / (2 * (n - 1)))`,
#' using `Var(mean) = sigma^2 / n` and `Var(sd) ~= sigma^2 / (2 * (n - 1))`.
#' The result is invariant to `direction` (phi is symmetric).
#'
#' @param mu,sigma,n Numeric vectors (recycled together); `n >= 2`.
#' @param mid Numeric scalar threshold.
#' @return Numeric vector of variances.
#' @noRd
responder_p_var <- function(mu, sigma, n, mid) {
  a <- (mu - mid) / sigma
  stats::dnorm(a)^2 * (1 / n + a^2 / (2 * (n - 1)))
}

#' Pooled (within-study) standard deviation
#'
#' Square root of the degrees-of-freedom-weighted mean of the study variances,
#' `sqrt(sum((n - 1) * sd^2) / sum(n - 1))`. This is the natural common-SD
#' estimate on the original scale and replaces the statistically dubious
#' inverse-variance pooling of SDs used previously.
#'
#' @param sd,n Numeric vectors of study SDs and sample sizes.
#' @return Numeric scalar.
#' @noRd
pooled_sd <- function(sd, n) {
  df <- n - 1
  sqrt(sum(df * sd^2) / sum(df))
}

#' Fixed-effect inverse-variance pooling
#'
#' @param est,var Numeric vectors of estimates and their variances.
#' @return List with `est` (pooled estimate) and `var` (its variance).
#' @noRd
iv_pool <- function(est, var) {
  w <- 1 / var
  list(est = sum(w * est) / sum(w), var = 1 / sum(w))
}

#' Summarise one arm across studies for the median/mean/weighted methods
#'
#' Reduces the per-study mean changes and SDs of a single arm to a pooled
#' location (`mu`), spread (`sigma`) and -- where a variance model exists -- the
#' variance of the pooled mean (`var_mu`, `NA` for median/unweighted).
#'
#' @param change,sd,n Numeric vectors for one arm.
#' @param method One of `"median"`, `"unweighted"`, `"weighted"`.
#' @return List with `mu`, `sigma`, `var_mu`.
#' @noRd
arm_summary <- function(change, sd, n, method = c("median", "unweighted", "weighted")) {
  method <- match.arg(method)
  switch(method,
    median = list(
      mu = stats::median(change),
      sigma = stats::median(sd),
      var_mu = NA_real_
    ),
    unweighted = list(
      mu = mean(change),
      sigma = mean(sd),
      var_mu = NA_real_
    ),
    weighted = {
      v <- sd^2 / n
      w <- 1 / v
      list(
        mu = sum(w * change) / sum(w),
        sigma = pooled_sd(sd, n),
        var_mu = 1 / sum(w)
      )
    }
  )
}
