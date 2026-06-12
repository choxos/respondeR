# Generate the respondeR hex logo.
# Concept: responder analysis dichotomizes two continuous distributions
# (control A and experimental B) at a cut-point C; the shaded tails beyond C are
# the responder proportions pA and pB, whose contrast is the risk difference.
#
# Run with: source("man/figures/generate_logo.R")

library(hexSticker)
library(ggplot2)
library(systemfonts)

# ── Register Poppins as a *native* font (downloaded once if absent) ──
# We register with systemfonts rather than using showtext, because both the
# ragg PNG device and the svglite SVG device read systemfonts and draw real
# (vector) text. showtext would rasterize text on the SVG device and mis-size
# it. This keeps the PNG and SVG identical and both rendered in Poppins.
text_family <- "sans"
try(
  {
    cache <- file.path(tempdir(), "respondeR-fonts")
    dir.create(cache, showWarnings = FALSE, recursive = TRUE)
    fetch <- function(file) {
      dest <- file.path(cache, file)
      if (!file.exists(dest)) {
        utils::download.file(
          paste0("https://github.com/google/fonts/raw/main/ofl/poppins/", file),
          dest,
          mode = "wb", quiet = TRUE
        )
      }
      dest
    }
    register_font(
      "Poppins",
      plain = fetch("Poppins-Regular.ttf"),
      bold = fetch("Poppins-Bold.ttf")
    )
    text_family <- "Poppins"
  },
  silent = TRUE
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
  geom_line(aes(y = dens_a), color = col_a, linewidth = 0.9) +
  geom_line(aes(y = dens_b), color = col_b, linewidth = 0.9) +
  # The cut-point C.
  geom_segment(
    x = cut, xend = cut, y = 0, yend = dnorm(cut, mu_b, sds),
    linetype = "dashed", color = "#1A1A2E", linewidth = 0.5
  ) +
  coord_cartesian(ylim = c(0, 0.52), expand = FALSE) +
  theme_void() +
  theme(legend.position = "none")

hex <- sticker(
  subplot = p,
  package = "respondeR",
  p_size = 5.2,
  p_y = 1.5,
  p_color = "#1A1A2E",
  p_family = text_family,
  p_fontface = "bold",
  s_x = 1.0,
  s_y = 0.98,
  s_width = 1.2,
  s_height = 1.04,
  h_fill = "#F7F8FC",
  h_color = "#2D4BD8",
  h_size = 1.6,
  url = "choxos.github.io/respondeR",
  u_size = 1.4,
  u_color = "#1A1A2E",
  u_family = text_family,
  filename = file.path(tempdir(), "respondeR-logo-preview.png")
)

# Save both formats through systemfonts-aware devices so Poppins renders
# natively (and the SVG stays scalable).
ggsave("man/figures/logo.png", hex,
  width = 43.9, height = 50.8, units = "mm", dpi = 500,
  bg = "transparent", device = ragg::agg_png
)
ggsave("man/figures/logo.svg", hex,
  width = 43.9, height = 50.8, units = "mm",
  bg = "transparent", device = svglite::svglite
)

cat(sprintf("respondeR logo written (font: %s)\n", text_family))
