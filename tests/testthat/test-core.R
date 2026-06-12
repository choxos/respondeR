# Known-answer tests for the internal statistical helpers.

test_that("responder_p matches the Normal CDF and respects direction", {
  expect_equal(respondeR:::responder_p(1, 2, 1, "higher"), 0.5)
  expect_equal(respondeR:::responder_p(3, 2, 1, "higher"), pnorm(1))
  expect_equal(
    respondeR:::responder_p(3, 2, 1, "lower"),
    1 - respondeR:::responder_p(3, 2, 1, "higher")
  )
})

test_that("responder_p supports lognormal and t models", {
  # t with large df approaches the Normal
  expect_equal(
    respondeR:::responder_p(3, 2, 1, "higher", dist = "t", df = 1e6),
    pnorm(1),
    tolerance = 1e-3
  )
  # lognormal probability is in (0, 1)
  p <- respondeR:::responder_p(2, 1, 1, "higher", dist = "lognormal")
  expect_true(p > 0 && p < 1)
  expect_error(
    respondeR:::responder_p(1, 1, 1, "higher", dist = "t", df = 2),
    "df"
  )
})

test_that("pooled_sd is the df-weighted RMS of SDs", {
  expect_equal(
    respondeR:::pooled_sd(c(2, 4), c(10, 20)),
    sqrt((9 * 4 + 19 * 16) / 28)
  )
  # equal SDs pool to that SD
  expect_equal(respondeR:::pooled_sd(c(3, 3, 3), c(5, 8, 11)), 3)
})

test_that("iv_pool reproduces closed-form inverse-variance pooling", {
  res <- respondeR:::iv_pool(c(1, 3), c(1, 1))
  expect_equal(res$est, 2)
  expect_equal(res$var, 0.5)
})

test_that("prob_info Normal variance matches the analytic delta formula", {
  mu <- 3; sigma <- 2; n <- 10; mid <- 1
  info <- respondeR:::prob_info(mu, sigma, n, mid, "higher")
  a <- (mu - mid) / sigma
  expected <- dnorm(a)^2 * (1 / n + a^2 / (2 * (n - 1)))
  expect_equal(info$var_sampling, expected)
  # dp/dmid is minus dp/dmu for the Normal model
  expect_equal(info$dp_dmid, -info$dp_dmu)
})

test_that("dl_pool returns no heterogeneity for identical studies", {
  res <- respondeR:::dl_pool(c(0.2, 0.2, 0.2), c(0.01, 0.01, 0.01))
  expect_equal(res$fixed, 0.2)
  expect_equal(res$q, 0)
  expect_equal(res$tau2, 0)
  expect_equal(res$i2, 0)
})

test_that("dl_pool flags heterogeneity for discordant studies", {
  res <- respondeR:::dl_pool(c(0, 1), c(0.01, 0.01))
  expect_gt(res$q, 3.84) # well beyond chi-square_1 at 0.05
  expect_gt(res$tau2, 0)
  expect_gt(res$i2, 0)
})

test_that("dl_pool treats a single study as having undefined heterogeneity", {
  res <- respondeR:::dl_pool(0.3, 0.02)
  expect_equal(res$est, 0.3)
  expect_true(is.na(res$i2))
  expect_true(is.na(res$q))
})
