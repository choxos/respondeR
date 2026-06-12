# Effect-measure conversions and intervals.

test_that("effect_measures reproduces RD, RR and OR algebra", {
  pe <- 0.5
  pc <- 0.25
  m <- respondeR:::effect_measures(pe, pc, 0.001, 0.001, 0.95, "wald")
  expect_equal(m$rd, 0.25)
  expect_equal(m$rr, 2)
  expect_equal(m$or, (0.5 / 0.5) / (0.25 / 0.75))
  expect_equal(m$nnt, 1 / 0.25)
})

test_that("missing variances give point estimates with NA intervals", {
  m <- respondeR:::effect_measures(0.5, 0.25, NA_real_, NA_real_, 0.95, "wald")
  expect_equal(m$rd, 0.25)
  expect_true(is.na(m$rd_lb))
  expect_true(is.na(m$rr_lb))
  expect_true(is.na(m$nnt_lb))
})

test_that("NNT is unbounded when the RD interval crosses zero", {
  zero_cross <- respondeR:::nnt_from_rd(0.01, -0.02, 0.04)
  expect_true(is.na(zero_cross$nnt_lb))
  expect_true(is.na(zero_cross$nnt_ub))
  clean <- respondeR:::nnt_from_rd(0.25, 0.10, 0.40)
  expect_equal(sort(clean$nnt_lb), 1 / 0.40)
  expect_equal(clean$nnt_ub, 1 / 0.10)
})

test_that("logit proportion intervals stay within (0, 1)", {
  ci <- respondeR:::prop_ci(0.02, 0.0004, 0.95, "logit")
  expect_gt(ci["lb"], 0)
  expect_lt(ci["ub"], 1)
})

test_that("MOVER risk-difference interval stays within [-1, 1]", {
  ci_e <- respondeR:::prop_ci(0.9, 0.002, 0.95, "logit")
  ci_c <- respondeR:::prop_ci(0.1, 0.002, 0.95, "logit")
  rd_ci <- respondeR:::mover_rd(0.9, 0.1, ci_e, ci_c)
  expect_gte(rd_ci["lb"], -1)
  expect_lte(rd_ci["ub"], 1)
})

test_that("logit and Wald agree closely for proportions away from the boundary", {
  w <- respondeR:::prop_ci(0.5, 1e-4, 0.95, "wald")
  l <- respondeR:::prop_ci(0.5, 1e-4, 0.95, "logit")
  expect_equal(unname(w), unname(l), tolerance = 1e-3)
})
