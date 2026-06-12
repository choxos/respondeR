# Common-language effect size (threshold-free).

test_that("identical arms give CLES of 0.5", {
  d <- data.frame(
    study = c("a", "b"),
    change_e = c(1, 2), sd_e = c(1, 1.5), n_e = c(20, 30),
    change_c = c(1, 2), sd_c = c(1, 1.5), n_c = c(20, 30)
  )
  res <- responder_cles(d)
  expect_equal(res$cles, 0.5, tolerance = 1e-12)
  expect_equal(res$studies$cles, c(0.5, 0.5), tolerance = 1e-12)
})

test_that("CLES matches the closed form for a single study", {
  d <- sample_responder_data[1, ]
  res <- responder_cles(d)
  delta <- (d$change_e - d$change_c) / sqrt(d$sd_e^2 + d$sd_c^2)
  expect_equal(res$cles, pnorm(delta), tolerance = 1e-10)
})

test_that("direction flips CLES around 0.5", {
  hi <- responder_cles(sample_responder_data, direction = "higher")
  lo <- responder_cles(sample_responder_data, direction = "lower")
  expect_equal(hi$cles, 1 - lo$cles, tolerance = 1e-10)
})

test_that("CLES is a valid probability with heterogeneity statistics", {
  res <- responder_cles(sample_responder_data, pooling = "random")
  expect_true(res$cles > 0 && res$cles < 1)
  expect_true(res$cles_lb <= res$cles && res$cles <= res$cles_ub)
  expect_false(is.na(res$i2))
  expect_equal(res$pooling, "random")
})
