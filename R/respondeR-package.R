#' @details
#' The package converts continuous trial outcomes (mean change, standard
#' deviation and sample size per arm, across studies) into the proportion of
#' "responders": patients whose change crosses a minimal important
#' difference (MID) threshold, under a Normal model for the change scores. It
#' expresses the between-arm contrast as a risk difference (RD). Four
#' pooling strategies are provided (median, unweighted mean, weighted mean and
#' individual), following the interpretability methods reviewed by Thorlund and
#' colleagues (2011) and the cut-point ("dichotomization") and
#' standardized-mean-difference approaches of Anzures-Cabrera, Sarpatwari and
#' Higgins (2011).
#'
#' The statistical engine lives in exported, side-effect-free functions
#' ([responder_analysis()], [responder_proportions()],
#' [responder_rd_individual()], [responder_cles()]) so that results are
#' reproducible and unit tested independently of the bundled Shiny application
#' ([launch_responder_analysis()]).
#'
#' @references
#' Sofi-Mahmudi A (2024). Identifying an optimal strategy for converting pain as
#' a continuous outcome to a responder analysis. Master's thesis, McMaster
#' University. \url{https://hdl.handle.net/11375/30210}
#'
#' Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011).
#' Pooling health-related quality of life outcomes in meta-analysis: a tutorial
#' and review of methods for enhancing interpretability.
#' \emph{Research Synthesis Methods}, 2(3), 188 to 203. \doi{10.1002/jrsm.46}
#'
#' Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011).
#' Expressing findings from meta-analyses of continuous outcomes in terms of
#' risks. \emph{Statistics in Medicine}, 30(25), 2867 to 2880.
#' \doi{10.1002/sim.4298}
#'
#' @keywords internal
"_PACKAGE"

#' @importFrom stats pnorm qnorm dnorm median
NULL
