# Assemble a one-row result with the full, uniform column schema so every
# method returns the same shape.
make_row <- function(method, pooling, k, p_e = NA_real_, p_c = NA_real_,
                     m, het = NULL, var_rd = NA_real_) {
  het_get <- function(field) if (is.null(het)) NA_real_ else het[[field]]
  data.frame(
    method = method, pooling = pooling, k = k,
    p_e = p_e, p_c = p_c,
    rd = m$rd, rd_lb = m$rd_lb, rd_ub = m$rd_ub,
    rr = m$rr, rr_lb = m$rr_lb, rr_ub = m$rr_ub,
    or = m$or, or_lb = m$or_lb, or_ub = m$or_ub,
    nnt = m$nnt, nnt_lb = m$nnt_lb, nnt_ub = m$nnt_ub,
    var_rd = var_rd,
    tau2 = het_get("tau2"), i2 = het_get("i2"),
    q = het_get("q"), q_p = het_get("q_p"),
    pi_lb = het_get("pi_lb"), pi_ub = het_get("pi_ub"),
    stringsAsFactors = FALSE
  )
}

# Select fixed- or random-effect estimate/variance/interval from a pool object.
pick_pool <- function(pool, pooling, conf_level) {
  if (pooling == "random") {
    list(est = pool$est, var = pool$var, lb = pool$ci_lb, ub = pool$ci_ub)
  } else {
    z <- stats::qnorm((1 + conf_level) / 2)
    se <- sqrt(pool$fixed_var)
    list(est = pool$fixed, var = pool$fixed_var, lb = pool$fixed - z * se, ub = pool$fixed + z * se)
  }
}

#' Responder analysis of continuous trial outcomes
#'
#' Converts continuous outcomes (mean change, SD and sample size per arm, across
#' studies) into responder proportions and a range of between-arm effect
#' measures: the risk difference (RD), risk ratio (RR), odds ratio (OR) and
#' number needed to treat (NNT), under a parametric model for the change scores.
#' Responders are defined by a minimal important difference (MID) threshold (the
#' cut-point / "dichotomization" approach of Anzures-Cabrera, Sarpatwari and
#' Higgins, 2011). For a threshold-free alternative see [responder_cles()].
#'
#' @section Methods:
#' \describe{
#'   \item{`individual`}{Dichotomize each study, then pool the per-study effect
#'     measures (fixed or random effects). The most defensible option; the
#'     per-study SE follows `se_method`.}
#'   \item{`weighted`}{Pool the mean change by inverse variance and the SD by the
#'     within-study pooled SD, dichotomize the pooled summaries, and obtain
#'     variances by the delta method.}
#'   \item{`unweighted`, `median`}{Dichotomize the arithmetic mean / median of
#'     the study means and SDs. Summaries with no variance model: intervals are
#'     `NA`.}
#'   \item{`smd`}{Pool the standardized mean difference (Hedges' g), bridge to an
#'     odds ratio via the logistic link (`lnOR = (pi / sqrt(3)) g`), and combine
#'     with the weighted-pooled control responder rate to recover risks. The
#'     second approach of the reference; not included by default.}
#' }
#' For the summary methods (`median`, `unweighted`, `weighted`) the control
#' proportion is, by default, pooled the same way as the experimental arm
#' (`control = "matched"`). Set `control = "median"` to instead take the baseline
#' risk from the median control arm for every summary method, as in the
#' Sofi-Mahmudi (2024) simulation study; the experimental arm is still pooled by
#' the chosen method. Because the median control arm carries no sampling-variance
#' model, `control = "median"` reports point estimates only (no intervals) for
#' the summary methods. The `individual` and `smd` methods pool per-study
#' contrasts and ignore `control`.
#'
#' @param data A data frame with one row per study and columns `study`,
#'   `change_e`, `sd_e`, `n_e`, `change_c`, `sd_c`, `n_c`. See
#'   [sample_responder_data].
#' @param mid Single finite number: the minimal important difference threshold.
#' @param direction `"higher"` (a larger change indicates response) or
#'   `"lower"`.
#' @param method Methods to compute: any of `"individual"`, `"weighted"`,
#'   `"unweighted"`, `"median"`, `"smd"`. Defaults to the first four.
#' @param se_method Per-study SE model for `"individual"`: `"binomial"`
#'   (default) or `"delta"`. The `"binomial"` variance `p(1 - p) / n` is a
#'   pseudo-binomial approximation: `p` is a probability implied by the estimated
#'   mean and SD, not a proportion of observed dichotomized patients, so it does
#'   not include the uncertainty in the reported mean and SD. `"delta"`
#'   propagates that uncertainty and is generally preferable for
#'   summary-statistic inputs; `"binomial"` is the default only for continuity
#'   with earlier results.
#' @param pooling `"fixed"` (default) or `"random"` effects, for the
#'   `"individual"` and `"smd"` methods.
#' @param control Baseline-risk rule for the summary methods (`median`,
#'   `unweighted`, `weighted`): `"matched"` (default) pools the control arm the
#'   same way as the experimental arm; `"median"` always takes the control
#'   responder proportion from the median control arm (the Sofi-Mahmudi 2024
#'   baseline), which yields point estimates only. Ignored by `"individual"` and
#'   `"smd"`.
#' @param tau_method Between-study variance estimator when `pooling = "random"`:
#'   `"DL"` (DerSimonian-Laird, default) or `"REML"` (needs the `metafor`
#'   package; falls back to DL with a warning if unavailable).
#' @param ci_method Random-effects interval method: `"wald"` (Normal, default)
#'   or `"hksj"` (Hartung-Knapp-Sidik-Jonkman, a `t`-based interval that is
#'   better calibrated when the number of studies is small).
#' @param dist Change-score distribution: `"normal"` (default), `"lognormal"`
#'   or `"t"`.
#' @param df Degrees of freedom when `dist = "t"`.
#' @param mid_sd Optional standard deviation of the MID threshold; when `> 0`
#'   its uncertainty is propagated into the effect-measure variances.
#' @param ci_type `"wald"` (default) or `"logit"` (keeps proportion and
#'   risk-difference intervals within valid bounds via the logit transform and
#'   Newcombe's MOVER method).
#' @param conf_level Confidence level (default `0.95`).
#'
#' @return A data frame with one row per requested method and columns: `method`,
#'   `pooling`, `k`, `p_e`, `p_c`, `rd`/`rd_lb`/`rd_ub`, `rr`/`rr_lb`/`rr_ub`,
#'   `or`/`or_lb`/`or_ub`, `nnt`/`nnt_lb`/`nnt_ub`, `var_rd`, and the
#'   heterogeneity statistics `tau2`, `i2`, `q`, `q_p`, `pi_lb`, `pi_ub` (for the
#'   pooled methods). Proportions, risk differences and CLES are on the
#'   proportion scale; multiply by 100 for percentages.
#'
#' @references
#' Sofi-Mahmudi A (2024). Identifying an optimal strategy for converting pain as
#' a continuous outcome to a responder analysis. Master's thesis, McMaster
#' University. \url{https://hdl.handle.net/11375/30210}
#'
#' Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011). Pooling
#' health-related quality of life outcomes in meta-analysis: a tutorial and
#' review of methods for enhancing interpretability. \emph{Research Synthesis
#' Methods}, 2(3), 188 to 203. \doi{10.1002/jrsm.46}
#'
#' Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings from
#' meta-analyses of continuous outcomes in terms of risks. \emph{Statistics in
#' Medicine}, 30(25), 2867 to 2880. \doi{10.1002/sim.4298}
#'
#' @seealso [responder_rd_individual()], [responder_cles()],
#'   [responder_proportions()]
#'
#' @examples
#' responder_analysis(sample_responder_data, mid = 1)
#'
#' # Random-effects individual method with relative measures:
#' responder_analysis(sample_responder_data, mid = 1,
#'   method = "individual", pooling = "random")
#' @export
responder_analysis <- function(data, mid,
                               direction = c("higher", "lower"),
                               method = c("individual", "weighted", "unweighted", "median", "smd"),
                               se_method = c("binomial", "delta"),
                               pooling = c("fixed", "random"),
                               control = c("matched", "median"),
                               tau_method = c("DL", "REML"),
                               dist = c("normal", "lognormal", "t"),
                               df = NULL,
                               mid_sd = 0,
                               ci_type = c("wald", "logit"),
                               ci_method = c("wald", "hksj"),
                               conf_level = 0.95) {
  direction <- match.arg(direction)
  se_method <- match.arg(se_method)
  pooling <- match.arg(pooling)
  control <- match.arg(control)
  tau_method <- match.arg(tau_method)
  dist <- match.arg(dist)
  ci_type <- match.arg(ci_type)
  ci_method <- match.arg(ci_method)
  default_methods <- c("individual", "weighted", "unweighted", "median")
  if (missing(method)) {
    method <- default_methods
  } else {
    method <- match.arg(method, several.ok = TRUE)
  }
  validate_mid(mid)
  validate_conf_level(conf_level)
  if (!is.numeric(mid_sd) || length(mid_sd) != 1L || !is.finite(mid_sd) || mid_sd < 0) {
    stop("`mid_sd` must be a single non-negative number.", call. = FALSE)
  }
  data <- validate_responder_data(data)
  if (dist == "lognormal" &&
    (any(data$change_e <= 0) || any(data$change_c <= 0) || mid <= 0)) {
    stop(
      "The lognormal model requires every study-arm mean change and the MID to ",
      "be positive (a lognormal patient-level change cannot be negative).",
      call. = FALSE
    )
  }
  k <- nrow(data)
  z <- stats::qnorm((1 + conf_level) / 2)
  boundary_hit <- FALSE

  summary_method <- function(m) {
    control_m <- if (control == "median") "median" else m
    arm_e <- arm_summary(data$change_e, data$sd_e, data$n_e, m)
    arm_c <- arm_summary(data$change_c, data$sd_c, data$n_c, control_m)
    ie <- prob_info(arm_e$mu, arm_e$sigma, 2, mid, direction, dist, df)
    ic <- prob_info(arm_c$mu, arm_c$sigma, 2, mid, direction, dist, df)
    pe <- ie$p
    pc <- ic$p
    if (is_boundary(pe, pc)) boundary_hit <<- TRUE
    if (m == "weighted") {
      # Full delta-method variance: propagate uncertainty in both the pooled
      # mean and the pooled SD. Var(sigma_pooled) ~= sigma^2 / (2 * df_total)
      # from the chi-square sampling distribution of the pooled variance.
      var_sigma_e <- arm_e$sigma^2 / (2 * sum(data$n_e - 1))
      var_sigma_c <- arm_c$sigma^2 / (2 * sum(data$n_c - 1))
      var_pe <- ie$dp_dmu^2 * arm_e$var_mu + ie$dp_dsigma^2 * var_sigma_e
      var_pc <- ic$dp_dmu^2 * arm_c$var_mu + ic$dp_dsigma^2 * var_sigma_c
      pec <- clamp_p(pe)
      pcc <- clamp_p(pc)
      mv <- mid_sd^2
      extra_rd <- (ie$dp_dmid - ic$dp_dmid)^2 * mv
      extra_lnrr <- (ie$dp_dmid / pec - ic$dp_dmid / pcc)^2 * mv
      extra_lnor <- (ie$dp_dmid / (pec * (1 - pec)) - ic$dp_dmid / (pcc * (1 - pcc)))^2 * mv
      meas <- effect_measures(pe, pc, var_pe, var_pc, conf_level, ci_type,
        extra_rd = extra_rd, extra_lnrr = extra_lnrr, extra_lnor = extra_lnor
      )
      var_rd <- var_pe + var_pc + extra_rd
    } else {
      meas <- effect_measures(pe, pc, NA_real_, NA_real_, conf_level, ci_type)
      var_rd <- NA_real_
    }
    make_row(m, NA_character_, k, pe, pc, meas, het = NULL, var_rd = var_rd)
  }

  individual_method <- function() {
    ps <- per_study_stats(data, mid, direction, se_method, dist, df, mid_sd)
    p_rd <- re_pool(ps$rd, ps$var_rd, conf_level, tau_method, ci_method)
    p_rr <- re_pool(ps$lnrr, ps$var_lnrr, conf_level, tau_method, ci_method)
    p_or <- re_pool(ps$lnor, ps$var_lnor, conf_level, tau_method, ci_method)
    s_rd <- pick_pool(p_rd, pooling, conf_level)
    s_rr <- pick_pool(p_rr, pooling, conf_level)
    s_or <- pick_pool(p_or, pooling, conf_level)
    nnt <- nnt_from_rd(s_rd$est, s_rd$lb, s_rd$ub)
    meas <- list(
      rd = s_rd$est, rd_lb = s_rd$lb, rd_ub = s_rd$ub,
      rr = exp(s_rr$est), rr_lb = exp(s_rr$lb), rr_ub = exp(s_rr$ub),
      or = exp(s_or$est), or_lb = exp(s_or$lb), or_ub = exp(s_or$ub),
      nnt = nnt$nnt, nnt_lb = nnt$nnt_lb, nnt_ub = nnt$nnt_ub
    )
    if (is_boundary(ps$p_e, ps$p_c)) {
      meas[c("rr", "rr_lb", "rr_ub", "or", "or_lb", "or_ub", "nnt", "nnt_lb", "nnt_ub")] <- NA_real_
      boundary_hit <<- TRUE
    }
    het <- p_rd
    if (pooling == "fixed") {
      het$pi_lb <- NA_real_
      het$pi_ub <- NA_real_
    }
    make_row("individual", pooling, k, NA_real_, NA_real_, meas, het, s_rd$var)
  }

  smd_method <- function() {
    sgn <- if (direction == "higher") 1 else -1
    ne <- data$n_e
    nc <- data$n_c
    s_pool <- sqrt(((ne - 1) * data$sd_e^2 + (nc - 1) * data$sd_c^2) / (ne + nc - 2))
    d <- sgn * (data$change_e - data$change_c) / s_pool
    jc <- 1 - 3 / (4 * (ne + nc) - 9)
    g <- jc * d
    var_g <- jc^2 * ((ne + nc) / (ne * nc) + d^2 / (2 * (ne + nc)))
    p_g <- re_pool(g, var_g, conf_level, tau_method, ci_method)
    s_g <- pick_pool(p_g, pooling, conf_level)

    cf <- pi / sqrt(3)
    ln_or <- cf * s_g$est
    se_lnor <- cf * sqrt(s_g$var)
    or <- exp(ln_or)
    or_lb <- exp(ln_or - z * se_lnor)
    or_ub <- exp(ln_or + z * se_lnor)

    arm_c <- arm_summary(data$change_c, data$sd_c, data$n_c, "weighted")
    pc <- responder_p(arm_c$mu, arm_c$sigma, mid, direction, dist, df)
    pe_from_or <- function(o) o * pc / (1 - pc + o * pc)
    pe <- pe_from_or(or)
    rd <- pe - pc
    rd_lb <- pe_from_or(or_lb) - pc
    rd_ub <- pe_from_or(or_ub) - pc
    nnt <- nnt_from_rd(rd, rd_lb, rd_ub)
    meas <- list(
      rd = rd, rd_lb = rd_lb, rd_ub = rd_ub,
      rr = pe / pc, rr_lb = pe_from_or(or_lb) / pc, rr_ub = pe_from_or(or_ub) / pc,
      or = or, or_lb = or_lb, or_ub = or_ub,
      nnt = nnt$nnt, nnt_lb = nnt$nnt_lb, nnt_ub = nnt$nnt_ub
    )
    if (is_boundary(pe, pc)) {
      meas[c("rr", "rr_lb", "rr_ub", "or", "or_lb", "or_ub", "nnt", "nnt_lb", "nnt_ub")] <- NA_real_
      boundary_hit <<- TRUE
    }
    het <- p_g
    if (pooling == "fixed") {
      het$pi_lb <- NA_real_
      het$pi_ub <- NA_real_
    }
    make_row("smd", pooling, k, pe, pc, meas, het, var_rd = NA_real_)
  }

  one_method <- function(m) {
    switch(m,
      individual = individual_method(),
      smd = smd_method(),
      summary_method(m)
    )
  }

  out <- do.call(rbind, lapply(method, one_method))
  rownames(out) <- NULL
  if (boundary_hit) {
    warning(
      "At this MID every responder probability is at 0 or 1 in both arms; the ",
      "risk ratio, odds ratio and NNT are not informative and are returned as ",
      "NA. The risk difference is still reported.",
      call. = FALSE
    )
  }
  out
}

#' Format responder-analysis results for display
#'
#' Turns the numeric output of [responder_analysis()] into a compact,
#' display-ready data frame: proportions and risk differences as percentages,
#' the risk ratio and odds ratio with intervals, and a combined "RD (CI)"
#' string. Used by the bundled Shiny app and handy for reports.
#'
#' @param results A data frame returned by [responder_analysis()].
#' @param digits Number of decimal places (default `1`).
#'
#' @return A data frame with character columns `Method`, `PE`, `PC`, `RD`, `RR`
#'   and `OR` (percentages for proportions/RD; ratios for RR/OR). Methods
#'   without a variance model show point estimates only.
#'
#' @examples
#' format_responder_results(responder_analysis(sample_responder_data, mid = 1))
#' @export
format_responder_results <- function(results, digits = 1) {
  pct <- function(x) ifelse(is.na(x), "-", formatC(100 * x, format = "f", digits = digits))
  rat <- function(x) ifelse(is.na(x) | !is.finite(x), "-", formatC(x, format = "f", digits = 2))
  with_ci <- function(point, lb, ub, fmt) {
    mapply(function(p, l, u) {
      if (is.na(l) || is.na(u)) fmt(p) else sprintf("%s (%s to %s)", fmt(p), fmt(l), fmt(u))
    }, point, lb, ub)
  }
  labels <- c(
    individual = "Individual", weighted = "Weighted mean",
    unweighted = "Unweighted mean", median = "Median", smd = "SMD (Cox)"
  )
  data.frame(
    Method = ifelse(results$method %in% names(labels), labels[results$method], results$method),
    PE = pct(results$p_e),
    PC = pct(results$p_c),
    RD = with_ci(results$rd, results$rd_lb, results$rd_ub, pct),
    RR = with_ci(results$rr, results$rr_lb, results$rr_ub, rat),
    OR = with_ci(results$or, results$or_lb, results$or_ub, rat),
    stringsAsFactors = FALSE, row.names = NULL
  )
}
