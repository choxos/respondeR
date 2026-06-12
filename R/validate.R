# Input validation helpers (internal).

#' Validate and coerce a responder-analysis data frame
#'
#' Checks that all required columns are present, coerces the numeric columns,
#' and rejects values that would make the Normal model ill-defined.
#'
#' @param data A data frame with columns `study`, `change_e`, `sd_e`, `n_e`,
#'   `change_c`, `sd_c`, `n_c`.
#' @return The validated data frame with numeric columns coerced to numeric.
#' @noRd
validate_responder_data <- function(data) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  required <- c("study", "change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "`data` is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  if (nrow(data) < 1L) {
    stop("`data` has no rows.", call. = FALSE)
  }

  numeric_cols <- c("change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c")
  for (col in numeric_cols) {
    coerced <- suppressWarnings(as.numeric(data[[col]]))
    if (anyNA(coerced)) {
      stop(
        "Column `", col, "` contains missing or non-numeric values.",
        call. = FALSE
      )
    }
    data[[col]] <- coerced
  }

  if (any(!is.finite(data$change_e)) || any(!is.finite(data$change_c))) {
    stop("Mean change columns must be finite.", call. = FALSE)
  }
  if (any(data$sd_e <= 0) || any(data$sd_c <= 0)) {
    stop("Standard deviations (`sd_e`, `sd_c`) must be greater than 0.", call. = FALSE)
  }
  if (any(data$n_e < 2) || any(data$n_c < 2)) {
    stop("Sample sizes (`n_e`, `n_c`) must be at least 2.", call. = FALSE)
  }

  data
}

#' Validate a scalar MID
#' @noRd
validate_mid <- function(mid) {
  if (!is.numeric(mid) || length(mid) != 1L || !is.finite(mid)) {
    stop("`mid` must be a single finite number.", call. = FALSE)
  }
  invisible(mid)
}

#' Validate a confidence level in (0, 1)
#' @noRd
validate_conf_level <- function(conf_level) {
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
    !is.finite(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must be a single number strictly between 0 and 1.", call. = FALSE)
  }
  invisible(conf_level)
}
