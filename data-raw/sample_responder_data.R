# Builds the bundled `sample_responder_data` dataset.
# Run with: source("data-raw/sample_responder_data.R")

sample_responder_data <- data.frame(
  study = c("Study 1", "Study 2", "Study 3"),
  change_e = c(0.9581395, 0.7920863, 1.0230769),
  sd_e = c(1.257593, 1.281364, 1.341201),
  n_e = c(43L, 139L, 156L),
  change_c = c(0.217777778, 0.003448276, -0.041975309),
  sd_c = c(1.195501, 1.324629, 1.263178),
  n_c = c(45L, 145L, 162L),
  stringsAsFactors = FALSE
)

usethis::use_data(sample_responder_data, overwrite = TRUE)
