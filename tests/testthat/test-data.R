# The bundled datasets are valid and the real one matches its source.

test_that("sample_responder_data has the required columns", {
  expect_named(sample_responder_data, c("study", "change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c"))
  expect_silent(responder_analysis(sample_responder_data, mid = 1))
})

test_that("vas_pain matches the published forest plot", {
  d <- vas_pain
  expect_equal(nrow(d), 20)
  expect_equal(sum(d$n_e), 671)
  expect_equal(sum(d$n_c), 654)
  # Hedges' g per study must match the SMD column of Li et al. (2025) Figure 3.
  sp <- sqrt(((d$n_e - 1) * d$sd_e^2 + (d$n_c - 1) * d$sd_c^2) / (d$n_e + d$n_c - 2))
  jc <- 1 - 3 / (4 * (d$n_e + d$n_c) - 9)
  g <- jc * (d$change_e - d$change_c) / sp
  paper_smd <- c(
    -1.57, 0.16, -0.61, -1.46, -1.40, -0.95, -1.18, -0.39, -0.53, -1.55,
    -0.33, -1.85, -1.00, -1.37, -0.85, -1.22, -0.74, -0.35, -0.56, -0.36
  )
  expect_true(max(abs(g - paper_smd)) < 0.01)
})

test_that("vas_pain runs through the engine with a lower-is-better MID", {
  res <- responder_analysis(vas_pain, mid = -1.5, direction = "lower")
  expect_true(all(res$rd[res$method == "individual"] > 0))
  expect_true(all(res$p_e[!is.na(res$p_e)] >= 0 & res$p_e[!is.na(res$p_e)] <= 1))
})
