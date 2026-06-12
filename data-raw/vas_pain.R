# Builds the bundled `vas_pain` dataset: per-study VAS pain change scores from
# the exercise-for-spinal-health meta-analysis of Li, Bao, Wang & Zhao (2025),
# Frontiers in Sports and Active Living, doi:10.3389/fspor.2025.1614906
# (Figure 3, the VAS pain forest plot). Distributed here under CC BY 4.0 with
# attribution; see R/data.R for the citation.
#
# Columns follow the package contract: the experimental arm (`_e`) is the
# exercise-therapy group, the control arm (`_c`) is usual care. The change
# scores are post minus baseline VAS (cm), so a more negative value is a larger
# pain reduction (use direction = "lower").
#
# Run with: source("data-raw/vas_pain.R")

vas_pain <- data.frame(
  study = c(
    "Aboufazeli 2021", "Erika 2014", "Falla 2013", "Farzaneh a 2022",
    "Farzaneh b 2022", "Hua Song 2008", "Lin Li 2021", "Lin Li 2023",
    "Peng Qiu a 2014", "Peng Qiu b 2014", "Shanju Bao 2023", "Weimin Zou 2023",
    "Xiaojian Ke 2018", "Xingping Hu 2018", "Xiuyuan Li 2024", "Yong Ding 2014",
    "Yue Guo 2025", "Yuping Chong 2011", "Yuping Chong 2014", "Zhou 2022"
  ),
  change_e = c(
    -5.06, -0.30, -1.70, -3.00, -2.83, -1.81, -4.10, -3.95, -1.31, -2.75,
    -1.34, -2.86, -1.40, -3.83, -2.78, -2.66, -1.16, -3.57, -3.77, -2.71
  ),
  sd_e = c(
    1.15, 2.03, 2.62, 2.15, 2.10, 1.23, 1.10, 1.29, 1.40, 1.26,
    2.47, 0.60, 1.08, 0.83, 0.98, 0.98, 1.36, 1.33, 1.77, 1.07
  ),
  n_e = c(
    12L, 21L, 23L, 14L, 14L, 37L, 60L, 30L, 10L, 10L,
    31L, 60L, 20L, 30L, 50L, 22L, 37L, 30L, 30L, 130L
  ),
  change_c = c(
    -3.08, -0.66, -0.20, 0.36, 0.36, -0.60, -2.84, -3.43, -0.51, -0.51,
    -0.55, -1.93, -0.20, -2.57, -1.92, -1.42, 0.08, -3.04, -2.81, -2.31
  ),
  sd_c = c(
    1.28, 2.49, 2.17, 2.32, 2.32, 1.28, 1.02, 1.34, 1.49, 1.49,
    2.29, 0.37, 1.28, 0.98, 1.02, 1.01, 1.91, 1.62, 1.61, 1.12
  ),
  n_c = c(
    12L, 20L, 23L, 14L, 14L, 31L, 60L, 30L, 10L, 10L,
    29L, 60L, 17L, 30L, 50L, 18L, 37L, 30L, 30L, 129L
  ),
  stringsAsFactors = FALSE
)

usethis::use_data(vas_pain, overwrite = TRUE)
