#' Responder analysis of continuous trial outcomes
#'
#' Converts continuous outcomes (mean change, SD and sample size per arm, across
#' studies) into responder proportions and the between-arm risk difference (RD),
#' using up to four pooling strategies. Responders are defined by a minimal
#' important difference (MID) threshold under a Normal model for the change
#' scores -- the cut-point ("dichotomisation") approach of Anzures-Cabrera,
#' Sarpatwari and Higgins (2011).
#'
#' @section Methods:
#' \describe{
#'   \item{`individual`}{Dichotomise each study, then pool the per-study RDs by
#'     fixed-effect inverse variance. The most defensible option; the SE of each
#'     study's RD is set by `se_method`. Returns a pooled RD with a confidence
#'     interval; `p_e`/`p_c` are `NA` (they are not single proportions).}
#'   \item{`weighted`}{Pool the mean change by inverse variance and the SD by the
#'     within-study pooled SD, dichotomise the pooled summaries, and obtain the
#'     RD variance by the delta method. Aligned with the pooled-then-dichotomise
#'     estimator of the reference.}
#'   \item{`unweighted`}{Dichotomise the arithmetic mean of the study means and
#'     SDs. A summary with no variance model: the CI is `NA`.}
#'   \item{`median`}{Dichotomise the median of the study means and SDs. A
#'     robustness summary with no variance model: the CI is `NA`.}
#' }
#' The control proportion is always computed with the *same* pooling strategy as
#' the experimental proportion.
#'
#' @param data A data frame with one row per study and columns `study`,
#'   `change_e`, `sd_e`, `n_e` (experimental arm) and `change_c`, `sd_c`, `n_c`
#'   (control arm). See [sample_responder_data].
#' @param mid Single finite number: the minimal important difference threshold.
#' @param direction Either `"higher"` (a larger change indicates response) or
#'   `"lower"` (a smaller change indicates response).
#' @param method Character vector of methods to compute, any of `"individual"`,
#'   `"weighted"`, `"unweighted"`, `"median"`. Defaults to all four.
#' @param se_method Standard-error model for the `"individual"` method:
#'   `"binomial"` (Wald, the default) or `"delta"` (propagates uncertainty in the
#'   estimated mean and SD).
#' @param conf_level Confidence level for the intervals (default `0.95`).
#'
#' @return A data frame with one row per requested method and columns:
#'   \describe{
#'     \item{method}{Method name.}
#'     \item{p_e, p_c}{Experimental and control responder proportions (`[0, 1]`),
#'       or `NA` for `"individual"`.}
#'     \item{rd}{Risk difference (`p_e - p_c`), on the `[0, 1]` scale.}
#'     \item{ci_lb, ci_ub}{Confidence-interval bounds for `rd`, or `NA` when no
#'       variance model applies (`"median"`, `"unweighted"`).}
#'     \item{var_rd}{Variance of `rd`, or `NA`.}
#'     \item{k}{Number of studies.}
#'   }
#'   Proportions and risk differences are on the proportion scale; multiply by
#'   100 for percentages.
#'
#' @references
#' Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011).
#' Expressing findings from meta-analyses of continuous outcomes in terms of
#' risks. \emph{Statistics in Medicine}, 30(25), 2867-2880.
#' \doi{10.1002/sim.4298}
#'
#' @seealso [responder_rd_individual()], [responder_proportions()]
#'
#' @examples
#' responder_analysis(sample_responder_data, mid = 1)
#'
#' # Lower change is better, 90% intervals, individual method only:
#' responder_analysis(
#'   sample_responder_data,
#'   mid = 1,
#'   direction = "lower",
#'   method = "individual",
#'   conf_level = 0.90
#' )
#' @export
responder_analysis <- function(data, mid,
                               direction = c("higher", "lower"),
                               method = c("individual", "weighted", "unweighted", "median"),
                               se_method = c("binomial", "delta"),
                               conf_level = 0.95) {
  direction <- match.arg(direction)
  se_method <- match.arg(se_method)
  method <- match.arg(method, several.ok = TRUE)
  validate_mid(mid)
  validate_conf_level(conf_level)
  data <- validate_responder_data(data)

  k <- nrow(data)
  z <- stats::qnorm((1 + conf_level) / 2)

  one_method <- function(m) {
    if (m == "individual") {
      per_study <- responder_rd_individual(
        data, mid,
        direction = direction, se_method = se_method, conf_level = conf_level
      )
      pooled <- iv_pool(per_study$rd, per_study$se^2)
      se <- sqrt(pooled$var)
      return(data.frame(
        method = m, p_e = NA_real_, p_c = NA_real_, rd = pooled$est,
        ci_lb = pooled$est - z * se, ci_ub = pooled$est + z * se,
        var_rd = pooled$var, k = k, stringsAsFactors = FALSE
      ))
    }

    arm_e <- arm_summary(data$change_e, data$sd_e, data$n_e, method = m)
    arm_c <- arm_summary(data$change_c, data$sd_c, data$n_c, method = m)
    p_e <- responder_p(arm_e$mu, arm_e$sigma, mid, direction)
    p_c <- responder_p(arm_c$mu, arm_c$sigma, mid, direction)
    rd <- p_e - p_c

    if (m == "weighted") {
      a_e <- (arm_e$mu - mid) / arm_e$sigma
      a_c <- (arm_c$mu - mid) / arm_c$sigma
      var_pe <- stats::dnorm(a_e)^2 * arm_e$var_mu / arm_e$sigma^2
      var_pc <- stats::dnorm(a_c)^2 * arm_c$var_mu / arm_c$sigma^2
      var_rd <- var_pe + var_pc
      se <- sqrt(var_rd)
      ci_lb <- rd - z * se
      ci_ub <- rd + z * se
    } else {
      var_rd <- NA_real_
      ci_lb <- NA_real_
      ci_ub <- NA_real_
    }

    data.frame(
      method = m, p_e = p_e, p_c = p_c, rd = rd,
      ci_lb = ci_lb, ci_ub = ci_ub, var_rd = var_rd, k = k,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, lapply(method, one_method))
  rownames(out) <- NULL
  out
}

#' Format responder-analysis results for display
#'
#' Turns the numeric output of [responder_analysis()] into a compact,
#' display-ready data frame: proportions and risk differences as percentages
#' and a combined "RD (CI)" string. Used by the bundled Shiny app and handy for
#' reports.
#'
#' @param results A data frame returned by [responder_analysis()].
#' @param digits Number of decimal places (default `1`).
#'
#' @return A data frame with character columns `Method`, `PE`, `PC` and
#'   `RD (95\% CI)` (percentage points; the confidence level shown matches the
#'   input). Methods without a variance model show the point estimate only.
#'
#' @examples
#' format_responder_results(responder_analysis(sample_responder_data, mid = 1))
#' @export
format_responder_results <- function(results, digits = 1) {
  pct <- function(x) ifelse(is.na(x), "-", formatC(100 * x, format = "f", digits = digits))
  rd_ci <- mapply(function(rd, lb, ub) {
    if (is.na(lb) || is.na(ub)) {
      sprintf("%s", pct(rd))
    } else {
      sprintf("%s (%s to %s)", pct(rd), pct(lb), pct(ub))
    }
  }, results$rd, results$ci_lb, results$ci_ub)

  labels <- c(
    individual = "Individual", weighted = "Weighted mean",
    unweighted = "Unweighted mean", median = "Median"
  )
  data.frame(
    Method = ifelse(results$method %in% names(labels),
      labels[results$method], results$method
    ),
    PE = pct(results$p_e),
    PC = pct(results$p_c),
    RD = rd_ci,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}
