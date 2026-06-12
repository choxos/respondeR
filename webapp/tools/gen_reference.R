# Generate the parity fixture: run the respondeR engine on the example data
# across a range of options and write the results to JSON for the web app's
# vitest parity test.  Run with: Rscript webapp/tools/gen_reference.R

library(respondeR)
library(jsonlite)

d <- sample_responder_data

# Replace non-finite numbers with NA so they serialise as null.
clean <- function(x) {
  if (is.data.frame(x)) {
    for (j in seq_along(x)) if (is.numeric(x[[j]])) x[[j]][!is.finite(x[[j]])] <- NA
    return(x)
  }
  if (is.list(x)) return(lapply(x, clean))
  if (is.numeric(x)) x[!is.finite(x)] <- NA
  x
}

cases <- list()
add <- function(fn, args, result) {
  cases[[length(cases) + 1]] <<- list(fn = fn, args = args, result = clean(result))
}

all_methods <- c("individual", "weighted", "unweighted", "median", "smd")

# responder_analysis across the option grid
for (direction in c("higher", "lower")) {
  for (pooling in c("fixed", "random")) {
    for (ci_type in c("wald", "logit")) {
      args <- list(mid = 1, direction = direction, method = all_methods,
                   se_method = "binomial", pooling = pooling, ci_type = ci_type,
                   conf_level = 0.95)
      res <- responder_analysis(d, mid = 1, direction = direction, method = all_methods,
                                se_method = "binomial", pooling = pooling,
                                ci_type = ci_type, conf_level = 0.95)
      add("responder_analysis", args, res)
    }
  }
}

# delta SE, mid_sd, alternative distributions, other confidence level
add("responder_analysis",
    list(mid = 0.5, direction = "higher", method = c("individual", "weighted"),
         se_method = "delta", pooling = "fixed", ci_type = "wald", conf_level = 0.90),
    responder_analysis(d, mid = 0.5, method = c("individual", "weighted"),
                       se_method = "delta", conf_level = 0.90))

add("responder_analysis",
    list(mid = 1, direction = "higher", method = "weighted", se_method = "binomial",
         pooling = "fixed", dist = "t", df = 8, ci_type = "wald", conf_level = 0.95),
    responder_analysis(d, mid = 1, method = "weighted", dist = "t", df = 8))

add("responder_analysis",
    list(mid = 1, direction = "higher", method = "weighted", se_method = "binomial",
         pooling = "fixed", dist = "lognormal", ci_type = "wald", conf_level = 0.95),
    responder_analysis(d, mid = 1, method = "weighted", dist = "lognormal"))

add("responder_analysis",
    list(mid = 1, direction = "higher", method = "weighted", se_method = "binomial",
         pooling = "fixed", mid_sd = 0.3, ci_type = "wald", conf_level = 0.95),
    responder_analysis(d, mid = 1, method = "weighted", mid_sd = 0.3))

# responder_rd_individual
for (direction in c("higher", "lower")) {
  add("responder_rd_individual",
      list(mid = 1, direction = direction, se_method = "binomial", conf_level = 0.95),
      responder_rd_individual(d, mid = 1, direction = direction))
}

# responder_cles
for (direction in c("higher", "lower")) {
  for (pooling in c("fixed", "random")) {
    cl <- responder_cles(d, direction = direction, pooling = pooling)
    res <- list(
      studies = cl$studies,
      cles = cl$cles, cles_lb = cl$cles_lb, cles_ub = cl$cles_ub,
      delta = cl$delta, se_delta = cl$se_delta,
      tau2 = cl$tau2, i2 = cl$i2, q = cl$q, q_p = cl$q_p,
      pi_lb = cl$pi_lb, pi_ub = cl$pi_ub
    )
    add("responder_cles",
        list(direction = direction, pooling = pooling, conf_level = 0.95), res)
  }
}

out <- "webapp/src/lib/__fixtures__/reference.json"
writeLines(toJSON(cases, dataframe = "rows", na = "null", null = "null",
                  auto_unbox = TRUE, digits = NA), out)
cat("Wrote", length(cases), "cases to", out, "\n")
