# Generate the respondeR hex logo.
# Concept: responder analysis dichotomises two continuous distributions
# (control A and experimental B) at a cut-point C; the shaded tails beyond C are
# the responder proportions pA and pB, whose contrast is the risk difference.
#
# Run with: source("man/figures/generate_logo.R")

library(hexSticker)
library(ggplot2)
library(showtext)

# Modern font (fall back to the default if Google Fonts is unreachable).
family <- "sans"
ok <- tryCatch(
  {
    font_add_google("Poppins", "poppins")
    showtext_auto()
    family <- "poppins"
    TRUE
  },
  error = function(e) FALSE
)

# ── Two overlapping Normal densities with a responder cut-point ──
mu_a <- 0      # control mean
mu_b <- 1.5    # experimental mean (shifted right)
sds <- 1
cut <- 1.95    # MID cut-point C

x <- seq(-2.9, 4.7, length.out = 500)
dens_a <- dnorm(x, mu_a, sds)
dens_b <- dnorm(x, mu_b, sds)
df <- data.frame(x, dens_a, dens_b)
tail <- df[df$x >= cut, ]

col_a <- "#2D4BD8" # control (blue)
col_b <- "#E23232" # experimental (red)

p <- ggplot(df, aes(x)) +
  # Responder tails beyond the cut-point (overlap reads as purple).
  geom_area(data = tail, aes(y = dens_b), fill = col_b, alpha = 0.45) +
  geom_area(data = tail, aes(y = dens_a), fill = col_a, alpha = 0.60) +
  # Density curves.
  geom_line(aes(y = dens_a), colour = col_a, linewidth = 0.9) +
  geom_line(aes(y = dens_b), colour = col_b, linewidth = 0.9) +
  # The cut-point C.
  geom_segment(
    x = cut, xend = cut, y = 0, yend = dnorm(cut, mu_b, sds),
    linetype = "dashed", colour = "#1A1A2E", linewidth = 0.5
  ) +
  coord_cartesian(ylim = c(0, 0.52), expand = FALSE) +
  theme_void() +
  theme(legend.position = "none")

args <- list(
  subplot = p,
  package = "respondeR",
  p_size = 19,
  p_y = 1.5,
  p_color = "#1A1A2E",
  p_family = family,
  p_fontface = "bold",
  s_x = 1.0,
  s_y = 0.92,
  s_width = 1.2,
  s_height = 1.04,
  h_fill = "#F7F8FC",
  h_color = "#2D4BD8",
  h_size = 1.6,
  url = "choxos.github.io/respondeR",
  u_size = 5.5,
  u_color = "#1A1A2E",
  u_family = family,
  dpi = 500
)

# PNG only: hexSticker + showtext does not size fonts correctly on the SVG
# device, and the PNG is what the README, pkgdown site and GitHub use.
do.call(sticker, c(args, filename = "man/figures/logo.png"))

cat("respondeR logo written to man/figures/logo.png\n")
