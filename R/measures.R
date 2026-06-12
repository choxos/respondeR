# Effect-measure helpers (internal): convert responder proportions into risk
# difference, risk ratio, odds ratio and number needed to treat, with Wald or
# logit/log confidence intervals.

#' Confidence interval for a proportion
#'
#' Wald (`ci_type = "wald"`) or logit-transformed (`"logit"`, kept inside
#' `[0, 1]`) interval from a proportion and its variance.
#' @noRd
prop_ci <- function(p, var_p, conf_level, ci_type = c("wald", "logit")) {
  ci_type <- match.arg(ci_type)
  z <- stats::qnorm((1 + conf_level) / 2)
  if (is.na(var_p)) {
    return(c(lb = NA_real_, ub = NA_real_))
  }
  if (ci_type == "wald") {
    c(lb = p - z * sqrt(var_p), ub = p + z * sqrt(var_p))
  } else {
    g <- stats::qlogis(p)
    var_g <- var_p / (p * (1 - p))^2
    c(lb = stats::plogis(g - z * sqrt(var_g)), ub = stats::plogis(g + z * sqrt(var_g)))
  }
}

#' MOVER interval for a risk difference
#'
#' Combines the separate proportion intervals (Newcombe's method of variance
#' estimates recovery) so the risk-difference interval stays within `[-1, 1]`.
#' @noRd
mover_rd <- function(pe, pc, ci_e, ci_c) {
  le <- unname(ci_e["lb"])
  ue <- unname(ci_e["ub"])
  lc <- unname(ci_c["lb"])
  uc <- unname(ci_c["ub"])
  rd <- pe - pc
  c(
    lb = rd - sqrt((pe - le)^2 + (uc - pc)^2),
    ub = rd + sqrt((ue - pe)^2 + (pc - lc)^2)
  )
}

#' Risk difference, ratio, odds ratio and NNT from two proportions
#'
#' For the summary methods (median/unweighted/weighted). When the proportion
#' variances are `NA` (median/unweighted) only point estimates are returned.
#'
#' @param pe,pc Experimental and control responder proportions.
#' @param var_pe,var_pc Their variances (may be `NA`).
#' @param conf_level Confidence level.
#' @param ci_type `"wald"` or `"logit"`.
#' @return A named list of point estimates and interval bounds.
#' @noRd
effect_measures <- function(pe, pc, var_pe, var_pc, conf_level,
                            ci_type = c("wald", "logit"),
                            extra_rd = 0, extra_lnrr = 0, extra_lnor = 0) {
  ci_type <- match.arg(ci_type)
  z <- stats::qnorm((1 + conf_level) / 2)
  rd <- pe - pc
  # Clamp the proportions that feed ratios, logits and their standard errors so
  # boundary proportions (exactly 0 or 1) cannot make these non-finite. The risk
  # difference is computed from the unclamped proportions.
  pec <- clamp_p(pe)
  pcc <- clamp_p(pc)
  rr <- pec / pcc
  or <- (pec / (1 - pec)) / (pcc / (1 - pcc))

  has_var <- !is.na(var_pe) && !is.na(var_pc)
  if (has_var) {
    # MID-uncertainty contributions (extra_*) force the Wald scale for the
    # contrast, since they encode a between-arm correlation MOVER cannot use.
    if (ci_type == "logit" && extra_rd == 0) {
      ci_e <- prop_ci(pec, var_pe, conf_level, "logit")
      ci_c <- prop_ci(pcc, var_pc, conf_level, "logit")
      rd_ci <- mover_rd(pe, pc, ci_e, ci_c)
      rd_lb <- unname(rd_ci["lb"])
      rd_ub <- unname(rd_ci["ub"])
    } else {
      se_rd <- sqrt(var_pe + var_pc + extra_rd)
      rd_lb <- rd - z * se_rd
      rd_ub <- rd + z * se_rd
    }
    se_lnrr <- sqrt(var_pe / pec^2 + var_pc / pcc^2 + extra_lnrr)
    rr_lb <- rr * exp(-z * se_lnrr)
    rr_ub <- rr * exp(z * se_lnrr)
    se_lnor <- sqrt(var_pe / (pec * (1 - pec))^2 + var_pc / (pcc * (1 - pcc))^2 + extra_lnor)
    or_lb <- or * exp(-z * se_lnor)
    or_ub <- or * exp(z * se_lnor)
  } else {
    rd_lb <- rd_ub <- rr_lb <- rr_ub <- or_lb <- or_ub <- NA_real_
  }

  nnt <- nnt_from_rd(rd, rd_lb, rd_ub)
  # Boundary policy: when both arms are pinned to the same probability bound, the
  # ratio measures are clamp artifacts; report NA (the risk difference is kept).
  if (is_boundary(pe, pc)) {
    rr <- rr_lb <- rr_ub <- or <- or_lb <- or_ub <- NA_real_
    nnt$nnt <- nnt$nnt_lb <- nnt$nnt_ub <- NA_real_
  }
  list(
    rd = unname(rd), rd_lb = unname(rd_lb), rd_ub = unname(rd_ub),
    rr = unname(rr), rr_lb = unname(rr_lb), rr_ub = unname(rr_ub),
    or = unname(or), or_lb = unname(or_lb), or_ub = unname(or_ub),
    nnt = nnt[["nnt"]], nnt_lb = nnt[["nnt_lb"]], nnt_ub = nnt[["nnt_ub"]]
  )
}

#' Number needed to treat from a risk difference (Altman 1998)
#'
#' `NNT = 1 / RD`. When the RD interval excludes 0 the NNT bounds are the
#' reciprocals of the RD bounds. When the RD interval includes 0 the NNT is
#' unbounded (the interval spans NNH ... infinity ... NNT); bounds are returned
#' as `NA` to flag that.
#' @noRd
nnt_from_rd <- function(rd, rd_lb, rd_ub) {
  nnt <- if (rd == 0) Inf else 1 / rd
  if (is.na(rd_lb) || is.na(rd_ub)) {
    return(list(nnt = nnt, nnt_lb = NA_real_, nnt_ub = NA_real_))
  }
  if (rd_lb > 0 || rd_ub < 0) {
    bounds <- sort(c(1 / rd_lb, 1 / rd_ub))
    list(nnt = nnt, nnt_lb = bounds[1], nnt_ub = bounds[2])
  } else {
    list(nnt = nnt, nnt_lb = NA_real_, nnt_ub = NA_real_)
  }
}
