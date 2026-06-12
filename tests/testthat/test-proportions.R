# Exported building block: responder_proportions().

test_that("responder_proportions matches the Normal model", {
  res <- responder_proportions(
    change = c(1, 3), sd = c(2, 2), n = c(10, 30), mid = 1
  )
  expect_equal(res$p, c(0.5, pnorm(1)))
  expect_equal(nrow(res), 2)
  expect_true(all(res$var_p > 0))
})

test_that("direction reflects the probability", {
  hi <- responder_proportions(2, 1, 50, 1, direction = "higher")
  lo <- responder_proportions(2, 1, 50, 1, direction = "lower")
  expect_equal(hi$p, 1 - lo$p, tolerance = 1e-12)
})

test_that("length mismatches and invalid inputs error", {
  expect_error(responder_proportions(c(1, 2), 1, 10, 1), "same length")
  expect_error(responder_proportions(1, -1, 10, 1), "greater than 0")
  expect_error(responder_proportions(1, 1, 1, 1), "at least 2")
  expect_error(responder_proportions(1, 1, 10, c(1, 2)), "single finite number")
})
