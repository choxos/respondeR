# Input validation and argument checking.

test_that("missing required columns are reported by name", {
  d <- sample_responder_data
  expect_error(responder_analysis(d[, -2], mid = 1), "change_e")
  expect_error(responder_analysis(d[, c("study", "change_e")], mid = 1), "missing required column")
})

test_that("invalid numeric values are rejected", {
  d <- sample_responder_data
  expect_error(responder_analysis(transform(d, sd_e = c(0, 1, 1)), mid = 1), "greater than 0")
  expect_error(responder_analysis(transform(d, sd_c = c(-1, 1, 1)), mid = 1), "greater than 0")
  expect_error(responder_analysis(transform(d, n_e = c(1, 10, 10)), mid = 1), "at least 2")
  bad <- d
  bad$change_e <- c("a", "b", "c")
  expect_error(responder_analysis(bad, mid = 1), "non-numeric")
})

test_that("scalar arguments are validated", {
  d <- sample_responder_data
  expect_error(responder_analysis(d, mid = c(1, 2)), "single finite number")
  expect_error(responder_analysis(d, mid = NA), "single finite number")
  expect_error(responder_analysis(d, mid = 1, conf_level = 0), "between 0 and 1")
  expect_error(responder_analysis(d, mid = 1, conf_level = 1), "between 0 and 1")
  expect_error(responder_analysis(d, mid = 1, mid_sd = -1), "non-negative")
})

test_that("non-data-frame input is rejected", {
  expect_error(responder_analysis(list(a = 1), mid = 1), "data frame")
})

test_that("a t distribution needs df > 2 and lognormal needs positive support", {
  d <- sample_responder_data
  expect_error(responder_analysis(d, mid = 1, method = "weighted", dist = "t", df = 2), "df")
  expect_error(
    responder_analysis(d, mid = -1, method = "weighted", dist = "lognormal"),
    "mid"
  )
})
