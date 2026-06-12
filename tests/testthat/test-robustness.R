# Robustness fixes from the 2026 methodology audit: boundary handling, small-k
# random-effects intervals, weighted SD uncertainty, and stricter validation.

test_that("extreme MIDs do not crash and return finite RD intervals", {
  d <- sample_responder_data
  # MID far below every mean change: everyone responds, p -> 1.
  res <- suppressWarnings(responder_analysis(d, mid = -20, method = "individual"))
  expect_true(is.finite(res$rd) && is.finite(res$rd_lb) && is.finite(res$rd_ub))
  # MID far above: nobody responds, p -> 0.
  hi <- suppressWarnings(responder_analysis(d, mid = 50, method = "weighted"))
  expect_true(is.finite(hi$rd) && is.finite(hi$rd_lb) && is.finite(hi$rd_ub))
})

test_that("boundary policy returns NA ratios and warns when both arms pin", {
  d <- sample_responder_data
  expect_warning(
    res <- responder_analysis(d, mid = -20, method = c("individual", "weighted", "smd")),
    "not informative"
  )
  # Risk difference stays finite; the ratio measures are NA.
  expect_true(all(is.finite(res$rd)))
  for (col in c("rr", "rr_lb", "rr_ub", "or", "or_lb", "or_ub", "nnt", "nnt_lb", "nnt_ub")) {
    expect_true(all(is.na(res[[col]])), info = col)
  }
  # A normal MID is unaffected: ratios are finite, no warning.
  expect_silent(ok <- responder_analysis(d, mid = 1, method = "individual"))
  expect_true(is.finite(ok$rr) && is.finite(ok$or))
})

test_that("is_boundary detects only same-side pinning", {
  expect_true(respondeR:::is_boundary(c(1, 1), c(1, 1)))
  expect_true(respondeR:::is_boundary(0, 0))
  expect_false(respondeR:::is_boundary(1, 0))
  expect_false(respondeR:::is_boundary(0.8, 0.4))
})

test_that("clamp_p keeps boundary proportions away from 0 and 1", {
  expect_equal(respondeR:::clamp_p(0), 1e-10)
  expect_equal(respondeR:::clamp_p(1), 1 - 1e-10)
  expect_equal(respondeR:::clamp_p(0.4), 0.4)
})

test_that("HKSJ widens the random-effects interval for few studies", {
  d <- sample_responder_data
  wald <- responder_analysis(d, mid = 1, method = "individual", pooling = "random", ci_method = "wald")
  hksj <- responder_analysis(d, mid = 1, method = "individual", pooling = "random", ci_method = "hksj")
  expect_gt(hksj$rd_ub - hksj$rd_lb, wald$rd_ub - wald$rd_lb)
})

test_that("the weighted method propagates pooled-SD uncertainty", {
  # Variance now includes the dp/dsigma term, so the interval is wider than the
  # mean-only version would be.
  res <- responder_analysis(sample_responder_data, mid = 1, method = "weighted")
  expect_gt(res$var_rd, 0)
  # mean-only variance would be ~7.16e-4; with the SD term it is larger.
  expect_gt(res$var_rd, 7.2e-4)
})

test_that("non-integer sample sizes are rejected", {
  d <- sample_responder_data
  expect_error(responder_analysis(transform(d, n_e = c(43.5, 139, 156)), mid = 1), "whole numbers")
})

test_that("lognormal requires positive arm means at the study level", {
  d <- sample_responder_data
  bad <- transform(d, change_c = c(-0.2, 0.0, 0.1))
  expect_error(
    responder_analysis(bad, mid = 1, method = "weighted", dist = "lognormal"),
    "lognormal"
  )
})

test_that("responder_proportions validates finite sd and n", {
  expect_error(responder_proportions(c(1, 2), c(1, NA), c(10, 10), mid = 1), "sd")
  expect_error(responder_proportions(c(1, 2), c(1, 1), c(10, NA), mid = 1), "n")
  expect_error(responder_proportions(c(1, 2), c(1, 1), c(10, 10.5), mid = 1), "whole numbers")
})
