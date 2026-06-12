#' Responder proportions from continuous arm summaries
#'
#' Estimates, for each study arm, the probability that a patient's change score
#' crosses the minimal important difference (MID) threshold under a parametric
#' model for the change scores, together with a delta-method (sampling)
#' variance for that probability.
#'
#' @param change Numeric vector of mean change scores.
#' @param sd Numeric vector of standard deviations (`> 0`).
#' @param n Numeric vector of sample sizes (`>= 2`).
#' @param mid Single finite number: the minimal important difference threshold.
#' @param direction `"higher"` (a larger change indicates response) or
#'   `"lower"`.
#' @param dist Change-score distribution: `"normal"` (default), `"lognormal"`
#'   or `"t"`.
#' @param df Degrees of freedom when `dist = "t"`.
#'
#' @return A data frame with one row per input element and columns `p`
#'   (responder probability) and `var_p` (delta-method variance).
#'
#' @references
#' Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011). Pooling
#' health-related quality of life outcomes in meta-analysis: a tutorial and
#' review of methods for enhancing interpretability. \emph{Research Synthesis
#' Methods}, 2(3), 188 to 203. \doi{10.1002/jrsm.46}
#'
#' Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings from
#' meta-analyses of continuous outcomes in terms of risks. \emph{Statistics in
#' Medicine}, 30(25), 2867 to 2880. \doi{10.1002/sim.4298}
#'
#' @examples
#' responder_proportions(
#'   change = c(0.96, 0.79, 1.02), sd = c(1.26, 1.28, 1.34),
#'   n = c(43, 139, 156), mid = 1
#' )
#' @export
responder_proportions <- function(change, sd, n, mid,
                                   direction = c("higher", "lower"),
                                   dist = c("normal", "lognormal", "t"),
                                   df = NULL) {
  direction <- match.arg(direction)
  dist <- match.arg(dist)
  validate_mid(mid)
  if (length(unique(c(length(change), length(sd), length(n)))) != 1L) {
    stop("`change`, `sd` and `n` must have the same length.", call. = FALSE)
  }
  if (any(!is.finite(change))) stop("`change` must be finite.", call. = FALSE)
  if (any(!is.finite(sd)) || any(sd <= 0)) {
    stop("`sd` must be finite and greater than 0.", call. = FALSE)
  }
  if (any(!is.finite(n)) || any(n < 2)) {
    stop("`n` must be finite and at least 2.", call. = FALSE)
  }
  if (any(abs(n - round(n)) > 1e-8)) {
    stop("`n` must be whole numbers (sample sizes).", call. = FALSE)
  }

  info <- prob_info(change, sd, n, mid, direction, dist, df)
  data.frame(p = info$p, var_p = info$var_sampling)
}

#' Per-study responder statistics (internal)
#'
#' Dichotomizes every study at the MID and returns, per study, the responder
#' proportions, the risk difference and the log risk ratio / log odds ratio with
#' their variances: the inputs that [responder_analysis()] pools for the
#' `"individual"` method.
#' @noRd
per_study_stats <- function(data, mid, direction, se_method, dist, df, mid_sd) {
  info_e <- prob_info(data$change_e, data$sd_e, data$n_e, mid, direction, dist, df)
  info_c <- prob_info(data$change_c, data$sd_c, data$n_c, mid, direction, dist, df)
  pe <- info_e$p
  pc <- info_c$p

  # Clamp the probabilities that feed logs, logits and inverse-variance weights
  # so that extreme MIDs (which can push pnorm() to exactly 0 or 1) cannot make
  # the ratio measures or the pooling non-finite. The proportions and the risk
  # difference below are reported unclamped.
  pec <- clamp_p(pe)
  pcc <- clamp_p(pc)

  if (se_method == "binomial") {
    var_pe <- pec * (1 - pec) / data$n_e
    var_pc <- pcc * (1 - pcc) / data$n_c
  } else {
    var_pe <- info_e$var_sampling
    var_pc <- info_c$var_sampling
  }

  mid_var <- mid_sd^2
  d_rd <- (info_e$dp_dmid - info_c$dp_dmid)^2 * mid_var
  d_lnrr <- (info_e$dp_dmid / pec - info_c$dp_dmid / pcc)^2 * mid_var
  d_lnor <- (info_e$dp_dmid / (pec * (1 - pec)) -
    info_c$dp_dmid / (pcc * (1 - pcc)))^2 * mid_var

  data.frame(
    study = data$study,
    n_e = data$n_e, n_c = data$n_c,
    p_e = pe, p_c = pc, var_pe = var_pe, var_pc = var_pc,
    rd = pe - pc, var_rd = var_pe + var_pc + d_rd,
    lnrr = log(pec / pcc), var_lnrr = var_pe / pec^2 + var_pc / pcc^2 + d_lnrr,
    lnor = stats::qlogis(pec) - stats::qlogis(pcc),
    var_lnor = var_pe / (pec * (1 - pec))^2 + var_pc / (pcc * (1 - pcc))^2 + d_lnor,
    stringsAsFactors = FALSE
  )
}

#' Per-study responder risk differences
#'
#' Dichotomizes each study at the MID threshold and returns the per-study
#' responder risk difference (experimental minus control) with a confidence
#' interval. Building block for the `"individual"` method of
#' [responder_analysis()]; also feeds the forest plot and per-study table.
#'
#' @inheritParams responder_analysis
#'
#' @return A data frame with one row per study and columns `study`, `p_e`,
#'   `p_c`, `rd`, `se`, `ci_lb`, `ci_ub` (proportion scale).
#'
#' @seealso [responder_analysis()]
#'
#' @examples
#' responder_rd_individual(sample_responder_data, mid = 1)
#' @export
responder_rd_individual <- function(data, mid,
                                    direction = c("higher", "lower"),
                                    se_method = c("binomial", "delta"),
                                    conf_level = 0.95,
                                    dist = c("normal", "lognormal", "t"),
                                    df = NULL, mid_sd = 0) {
  direction <- match.arg(direction)
  se_method <- match.arg(se_method)
  dist <- match.arg(dist)
  validate_mid(mid)
  validate_conf_level(conf_level)
  if (!is.numeric(mid_sd) || length(mid_sd) != 1L || !is.finite(mid_sd) || mid_sd < 0) {
    stop("`mid_sd` must be a single non-negative number.", call. = FALSE)
  }
  data <- validate_responder_data(data)

  ps <- per_study_stats(data, mid, direction, se_method, dist, df, mid_sd)
  se <- sqrt(ps$var_rd)
  z <- stats::qnorm((1 + conf_level) / 2)
  data.frame(
    study = ps$study, p_e = ps$p_e, p_c = ps$p_c, rd = ps$rd, se = se,
    ci_lb = ps$rd - z * se, ci_ub = ps$rd + z * se,
    stringsAsFactors = FALSE
  )
}
