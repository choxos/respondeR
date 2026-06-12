# Internal statistical helpers for responder analysis.
# Not exported; small, pure building blocks so the methodology is directly
# unit-testable.

#' Responder probability under a parametric model
#'
#' Probability that a change score crosses the MID threshold, assuming the
#' change follows the requested distribution with the supplied mean and SD.
#'
#' @param mu,sigma Numeric vectors of arm means and SDs (recycled together).
#' @param mid Numeric scalar threshold.
#' @param direction `"higher"` (responder if change > mid) or `"lower"`.
#' @param dist Change-score distribution: `"normal"` (default), `"lognormal"`
#'   (requires `mu > 0`, `mid > 0`) or `"t"` (requires `df > 2`).
#' @param df Degrees of freedom for `dist = "t"`.
#' @return Numeric vector of probabilities in `[0, 1]`.
#' @noRd
responder_p <- function(mu, sigma, mid, direction = c("higher", "lower"),
                        dist = c("normal", "lognormal", "t"), df = NULL) {
  direction <- match.arg(direction)
  dist <- match.arg(dist)

  p_gt <- switch(dist,
    normal = stats::pnorm((mu - mid) / sigma),
    t = {
      if (is.null(df) || df <= 2) {
        stop("`df` must be greater than 2 for the t distribution.", call. = FALSE)
      }
      scale <- sigma * sqrt((df - 2) / df)
      stats::pt((mu - mid) / scale, df = df)
    },
    lognormal = {
      if (any(mu <= 0)) {
        stop("The lognormal model requires positive mean change (`mu` > 0).", call. = FALSE)
      }
      if (mid <= 0) {
        stop("The lognormal model requires `mid` > 0.", call. = FALSE)
      }
      sdlog <- sqrt(log(1 + (sigma / mu)^2))
      meanlog <- log(mu) - sdlog^2 / 2
      stats::plnorm(mid, meanlog = meanlog, sdlog = sdlog, lower.tail = FALSE)
    }
  )

  if (direction == "higher") p_gt else 1 - p_gt
}

#' Responder probability with sampling-variance information
#'
#' Returns the responder probability together with the gradients and the
#' delta-method sampling variance needed downstream (including the derivative
#' with respect to the threshold, used for optional MID-uncertainty
#' propagation). Gradients are analytic for the Normal model and numerical
#' (central differences) otherwise.
#'
#' @inheritParams responder_p
#' @param n Numeric vector of sample sizes (`>= 2`).
#' @return A list of equal-length numeric vectors: `p`, `dp_dmid`, and
#'   `var_sampling` (variance of `p` from estimating the mean and SD).
#' @noRd
prob_info <- function(mu, sigma, n, mid, direction = c("higher", "lower"),
                      dist = c("normal", "lognormal", "t"), df = NULL) {
  direction <- match.arg(direction)
  dist <- match.arg(dist)
  p <- responder_p(mu, sigma, mid, direction, dist, df)

  if (dist == "normal") {
    sgn <- if (direction == "higher") 1 else -1
    g <- sgn * (mu - mid) / sigma
    phi <- stats::dnorm(g)
    dp_dmu <- phi * sgn / sigma
    dp_dsigma <- -phi * sgn * (mu - mid) / sigma^2
    dp_dmid <- -dp_dmu
  } else {
    f <- function(m, s, md) responder_p(m, s, md, direction, dist, df)
    hm <- 1e-5 * pmax(1, abs(mu))
    hs <- 1e-5 * pmax(1, abs(sigma))
    hd <- 1e-5 * max(1, abs(mid))
    dp_dmu <- (f(mu + hm, sigma, mid) - f(mu - hm, sigma, mid)) / (2 * hm)
    dp_dsigma <- (f(mu, sigma + hs, mid) - f(mu, sigma - hs, mid)) / (2 * hs)
    dp_dmid <- (f(mu, sigma, mid + hd) - f(mu, sigma, mid - hd)) / (2 * hd)
  }

  var_sampling <- dp_dmu^2 * sigma^2 / n + dp_dsigma^2 * sigma^2 / (2 * (n - 1))
  list(
    p = p, dp_dmu = dp_dmu, dp_dsigma = dp_dsigma, dp_dmid = dp_dmid,
    var_sampling = var_sampling
  )
}

#' Random- or fixed-effect pooling, dispatching on the tau-squared estimator
#'
#' Wraps the DerSimonian-Laird helper (dependency-free) and, when
#' `tau_method = "REML"`, `metafor::rma()` if available (falling back to DL with
#' a warning otherwise). Returns the same list structure as `dl_pool()`.
#' @noRd
re_pool <- function(y, v, conf_level = 0.95, tau_method = c("DL", "REML")) {
  tau_method <- match.arg(tau_method)
  if (tau_method == "DL") {
    return(dl_pool(y, v, conf_level))
  }
  if (!requireNamespace("metafor", quietly = TRUE)) {
    warning(
      "Package `metafor` is not installed; falling back to the ",
      "DerSimonian-Laird estimator.",
      call. = FALSE
    )
    return(dl_pool(y, v, conf_level))
  }
  fit <- metafor::rma(yi = y, vi = v, method = "REML", level = 100 * conf_level)
  pr <- metafor::predict.rma(fit)
  k <- length(y)
  wf <- 1 / v
  list(
    k = k, fixed = sum(wf * y) / sum(wf), fixed_var = 1 / sum(wf),
    est = as.numeric(fit$b), var = as.numeric(fit$se)^2,
    tau2 = fit$tau2, i2 = fit$I2 / 100, q = fit$QE,
    q_p = fit$QEp,
    ci_lb = fit$ci.lb, ci_ub = fit$ci.ub,
    pi_lb = if (!is.null(pr$pi.lb)) pr$pi.lb else NA_real_,
    pi_ub = if (!is.null(pr$pi.ub)) pr$pi.ub else NA_real_
  )
}

#' Pooled (within-study) standard deviation
#'
#' `sqrt(sum((n - 1) * sd^2) / sum(n - 1))`: the degrees-of-freedom-weighted
#' root-mean-square of the study SDs.
#' @noRd
pooled_sd <- function(sd, n) {
  df <- n - 1
  sqrt(sum(df * sd^2) / sum(df))
}

#' Fixed-effect inverse-variance pooling
#' @return List with `est` and `var`.
#' @noRd
iv_pool <- function(est, var) {
  w <- 1 / var
  list(est = sum(w * est) / sum(w), var = 1 / sum(w))
}

#' DerSimonian-Laird random-effects pooling with heterogeneity statistics
#'
#' Closed-form (dependency-free) fixed- and random-effects pooling of estimates
#' `y` with variances `v`, plus Cochran's Q, I-squared, tau-squared and a
#' (random-effects) prediction interval.
#'
#' @param y,v Numeric vectors of estimates and their variances.
#' @param conf_level Confidence level.
#' @return A list with `k`, `fixed`, `fixed_var`, `est` (random), `var`
#'   (random), `tau2`, `i2`, `q`, `q_p`, `ci_lb`, `ci_ub`, `pi_lb`, `pi_ub`.
#' @noRd
dl_pool <- function(y, v, conf_level = 0.95) {
  k <- length(y)
  wf <- 1 / v
  fixed <- sum(wf * y) / sum(wf)
  fixed_var <- 1 / sum(wf)
  if (k < 2) {
    # Heterogeneity is undefined for a single study.
    z1 <- stats::qnorm((1 + conf_level) / 2)
    return(list(
      k = k, fixed = fixed, fixed_var = fixed_var, est = fixed, var = fixed_var,
      tau2 = 0, i2 = NA_real_, q = NA_real_, q_p = NA_real_,
      ci_lb = fixed - z1 * sqrt(fixed_var), ci_ub = fixed + z1 * sqrt(fixed_var),
      pi_lb = NA_real_, pi_ub = NA_real_
    ))
  }
  q <- sum(wf * (y - fixed)^2)
  cc <- sum(wf) - sum(wf^2) / sum(wf)
  tau2 <- if (cc > 0) max(0, (q - (k - 1)) / cc) else 0
  i2 <- if (q > 0) max(0, (q - (k - 1)) / q) else 0
  wr <- 1 / (v + tau2)
  est <- sum(wr * y) / sum(wr)
  var <- 1 / sum(wr)
  z <- stats::qnorm((1 + conf_level) / 2)
  pi_lb <- NA_real_
  pi_ub <- NA_real_
  if (k > 2) {
    tcrit <- stats::qt((1 + conf_level) / 2, df = k - 2)
    pi_lb <- est - tcrit * sqrt(tau2 + var)
    pi_ub <- est + tcrit * sqrt(tau2 + var)
  }
  list(
    k = k, fixed = fixed, fixed_var = fixed_var, est = est, var = var,
    tau2 = tau2, i2 = i2, q = q,
    q_p = stats::pchisq(q, df = k - 1, lower.tail = FALSE),
    ci_lb = est - z * sqrt(var), ci_ub = est + z * sqrt(var),
    pi_lb = pi_lb, pi_ub = pi_ub
  )
}

#' Summarise one arm across studies for the median/mean/weighted methods
#'
#' @param change,sd,n Numeric vectors for one arm.
#' @param method One of `"median"`, `"unweighted"`, `"weighted"`.
#' @return List with `mu`, `sigma`, `var_mu` (`NA` for median/unweighted).
#' @noRd
arm_summary <- function(change, sd, n, method = c("median", "unweighted", "weighted")) {
  method <- match.arg(method)
  switch(method,
    median = list(mu = stats::median(change), sigma = stats::median(sd), var_mu = NA_real_),
    unweighted = list(mu = mean(change), sigma = mean(sd), var_mu = NA_real_),
    weighted = {
      w <- n / sd^2
      list(mu = sum(w * change) / sum(w), sigma = pooled_sd(sd, n), var_mu = 1 / sum(w))
    }
  )
}
