# Regression anchors and structural checks for the main entry point.

test_that("individual and median reproduce the legacy app numbers", {
  d <- sample_responder_data
  mid <- 1

  # Recompute the legacy formulas independently (percent scale).
  pe <- (1 - pnorm((mid - d$change_e) / d$sd_e)) * 100
  pc <- (1 - pnorm((mid - d$change_c) / d$sd_c)) * 100
  rd <- pe - pc
  se <- sqrt(pe * (100 - pe) / d$n_e + pc * (100 - pc) / d$n_c)
  w <- 1 / se^2
  rd_ind_legacy <- sum(rd * w) / sum(w)
  rd_med_legacy <- ((1 - pnorm((mid - median(d$change_e)) / median(d$sd_e))) -
    (1 - pnorm((mid - median(d$change_c)) / median(d$sd_c)))) * 100

  res <- responder_analysis(d, mid = mid)
  expect_equal(res$rd[res$method == "individual"] * 100, rd_ind_legacy, tolerance = 1e-9)
  expect_equal(res$rd[res$method == "median"] * 100, rd_med_legacy, tolerance = 1e-9)
})

test_that("corrected weighted/unweighted values are stable (regression anchors)", {
  res <- responder_analysis(sample_responder_data, mid = 1)
  get <- function(m, col) res[[col]][res$method == m]
  expect_equal(get("weighted", "rd"), 0.2537409816, tolerance = 1e-8)
  expect_equal(get("unweighted", "rd"), 0.2487438017, tolerance = 1e-8)
  expect_equal(get("weighted", "rd_lb"), 0.1985864974, tolerance = 1e-8)
  expect_equal(get("weighted", "rd_ub"), 0.3088954658, tolerance = 1e-8)
  expect_equal(get("individual", "rr"), 2.1488085019, tolerance = 1e-8)
  expect_equal(get("individual", "or"), 3.1980979564, tolerance = 1e-8)
})

test_that("output has the full schema and valid invariants", {
  res <- responder_analysis(sample_responder_data, mid = 1)
  expect_setequal(res$method, c("individual", "weighted", "unweighted", "median"))
  cols <- c(
    "method", "pooling", "k", "p_e", "p_c", "rd", "rd_lb", "rd_ub",
    "rr", "rr_lb", "rr_ub", "or", "or_lb", "or_ub",
    "nnt", "nnt_lb", "nnt_ub", "var_rd", "tau2", "i2", "q", "q_p", "pi_lb", "pi_ub"
  )
  expect_true(all(cols %in% names(res)))

  # proportions in [0, 1]; CI brackets the point estimate where present
  summ <- res[res$method %in% c("weighted", "unweighted", "median"), ]
  expect_true(all(summ$p_e >= 0 & summ$p_e <= 1))
  expect_true(all(summ$p_c >= 0 & summ$p_c <= 1))
  with_ci <- res[!is.na(res$rd_lb), ]
  expect_true(all(with_ci$rd_lb <= with_ci$rd & with_ci$rd <= with_ci$rd_ub))
})

test_that("median and unweighted have no variance model", {
  res <- responder_analysis(sample_responder_data, mid = 1)
  expect_true(all(is.na(res$rd_lb[res$method %in% c("median", "unweighted")])))
})

test_that("direction flip negates the risk difference for symmetric methods", {
  hi <- responder_analysis(sample_responder_data, mid = 1, method = "individual", direction = "higher")
  lo <- responder_analysis(sample_responder_data, mid = 1, method = "individual", direction = "lower")
  expect_equal(hi$rd, -lo$rd, tolerance = 1e-10)
})

test_that("random effects report heterogeneity and widen with tau2 > 0", {
  res <- responder_analysis(sample_responder_data, mid = 1,
    method = "individual", pooling = "random")
  expect_equal(res$pooling, "random")
  expect_false(is.na(res$i2))
  expect_false(is.na(res$q))
})

test_that("smd method yields OR > 1 for a beneficial treatment", {
  res <- responder_analysis(sample_responder_data, mid = 1, method = "smd")
  expect_gt(res$or, 1)
  expect_true(res$p_e > res$p_c)
  expect_equal(res$or, 3.5511218305, tolerance = 1e-7)
})

test_that("logit intervals stay within valid bounds", {
  res <- responder_analysis(sample_responder_data, mid = 1,
    method = "weighted", ci_type = "logit")
  expect_gte(res$rd_lb, -1)
  expect_lte(res$rd_ub, 1)
})

test_that("MID uncertainty widens the weighted interval", {
  base <- responder_analysis(sample_responder_data, mid = 1, method = "weighted")
  wide <- responder_analysis(sample_responder_data, mid = 1, method = "weighted", mid_sd = 0.3)
  expect_equal(base$rd, wide$rd, tolerance = 1e-12) # point estimate unchanged
  expect_gt(wide$rd_ub - wide$rd_lb, base$rd_ub - base$rd_lb)
})

test_that("conf_level scales the interval half-width", {
  r90 <- responder_analysis(sample_responder_data, mid = 1, method = "weighted", conf_level = 0.90)
  r95 <- responder_analysis(sample_responder_data, mid = 1, method = "weighted", conf_level = 0.95)
  hw90 <- (r90$rd_ub - r90$rd_lb) / 2
  hw95 <- (r95$rd_ub - r95$rd_lb) / 2
  expect_equal(hw90 / hw95, qnorm(0.95) / qnorm(0.975), tolerance = 1e-8)
})

test_that("a single study still produces a result", {
  res <- responder_analysis(sample_responder_data[1, ], mid = 1, method = c("individual", "weighted"))
  expect_equal(nrow(res), 2)
  expect_false(any(is.na(res$rd)))
})

test_that("control = 'median' takes the baseline from the median control arm", {
  d <- sample_responder_data
  mid <- 1
  pc_med <- pnorm((median(d$change_c) - mid) / median(d$sd_c))

  res <- responder_analysis(d, mid = mid, control = "median")
  summ <- res[res$method %in% c("median", "unweighted", "weighted"), ]
  # every summary method now shares the single median-control baseline
  expect_true(all(abs(summ$p_c - pc_med) < 1e-12))

  # the experimental arm is still pooled by its own method
  pe_unw <- pnorm((mean(d$change_e) - mid) / mean(d$sd_e))
  expect_equal(res$p_e[res$method == "unweighted"], pe_unw, tolerance = 1e-12)
  expect_equal(res$rd[res$method == "unweighted"], pe_unw - pc_med, tolerance = 1e-12)

  # and it differs from the matched baseline (the option does something)
  matched <- responder_analysis(d, mid = mid)
  expect_false(isTRUE(all.equal(
    matched$p_c[matched$method == "unweighted"], pc_med
  )))
})

test_that("control = 'median' leaves the median method unchanged", {
  d <- sample_responder_data
  m <- responder_analysis(d, mid = 1, method = "median", control = "matched")
  mm <- responder_analysis(d, mid = 1, method = "median", control = "median")
  expect_equal(m$rd, mm$rd, tolerance = 1e-12)
  expect_equal(m$p_c, mm$p_c, tolerance = 1e-12)
})

test_that("control = 'median' reports point estimates only for the weighted method", {
  res <- responder_analysis(sample_responder_data, mid = 1, method = "weighted", control = "median")
  expect_false(is.na(res$rd))
  expect_true(is.na(res$rd_lb))
  expect_true(is.na(res$var_rd))
})

test_that("control is ignored by the individual and smd methods", {
  d <- sample_responder_data
  for (m in c("individual", "smd")) {
    a <- responder_analysis(d, mid = 1, method = m, control = "matched")
    b <- responder_analysis(d, mid = 1, method = m, control = "median")
    expect_equal(a$rd, b$rd, tolerance = 1e-12)
  }
})
