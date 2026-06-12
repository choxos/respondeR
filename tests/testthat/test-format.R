# Display formatting helper.

test_that("format_responder_results produces readable columns", {
  res <- responder_analysis(sample_responder_data, mid = 1)
  fmt <- format_responder_results(res)
  expect_setequal(names(fmt), c("Method", "PE", "PC", "RD", "RR", "OR"))
  expect_equal(nrow(fmt), nrow(res))
  expect_type(fmt$RD, "character")
  # methods with intervals show "point (lo to hi)"; summaries show a point only
  expect_match(fmt$RD[res$method == "individual"], "to")
  expect_false(grepl("to", fmt$RD[res$method == "median"]))
})

test_that("individual rows show a dash for the unavailable proportions", {
  res <- responder_analysis(sample_responder_data, mid = 1, method = "individual")
  fmt <- format_responder_results(res)
  expect_equal(fmt$PE, "-")
  expect_equal(fmt$PC, "-")
})
