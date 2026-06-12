# Methodology

This vignette sets out the statistics behind respondeR: the cut-point
approach, each pooling method and its variance, the relative effect
measures, the threshold-free common-language effect size, the
standardized-mean-difference bridge, random effects, the refinement
options, and the assumptions and their limits. It closes with a guide to
choosing a method.

## The cut-point approach

For one study arm with mean change $`\mu`$, standard deviation
$`\sigma`$ and a minimal important difference (MID) threshold $`m`$,
assume the patient-level change $`X`$ is Normally distributed. A
*responder* is a patient whose change crosses the threshold. The
responder probability is

``` math
p = \Pr(X > m) = \Phi\!\left(\frac{\mu - m}{\sigma}\right)
\quad\text{(higher change is better),}
```

or $`p = \Phi\!\left(\frac{m - \mu}{\sigma}\right)`$ when a *lower*
change is better. This is the cut-point (“dichotomization”) method
reviewed by Thorlund and colleagues (2011) and detailed by
Anzures-Cabrera, Sarpatwari & Higgins (2011). The between-arm contrast
is then a familiar binary effect measure: by default the **risk
difference** $`\mathrm{RD} = p_e - p_c`$.

respondeR keeps proportions on the $`[0, 1]`$ scale internally and
converts to percentages only for display.

## The pooling methods

Studies report per-arm summaries; the methods differ in how those are
combined. Throughout, study $`i`$ contributes
$`(\bar d_{e,i}, s_{e,i}, n_{e,i})`$ for the experimental arm and
$`(\bar d_{c,i}, s_{c,i}, n_{c,i})`$ for the control arm.

### Individual (the default workhorse)

Dichotomize each study, form its risk difference, then pool. With
$`p_{e,i} = \Phi((\bar d_{e,i} - m)/s_{e,i})`$ and likewise $`p_{c,i}`$,

``` math
\mathrm{RD}_i = p_{e,i} - p_{c,i}, \qquad
\widehat{\mathrm{RD}} = \frac{\sum_i w_i \mathrm{RD}_i}{\sum_i w_i}, \quad
w_i = 1/\widehat{\mathrm{Var}}(\mathrm{RD}_i).
```

The per-study variance follows `se_method`:

- `"binomial"` (default): $`\widehat{\mathrm{Var}}(\mathrm{RD}_i) =
  \frac{p_{e,i}(1 - p_{e,i})}{n_{e,i}} + \frac{p_{c,i}(1 - p_{c,i})}{n_{c,i}}`$.
- `"delta"`: propagates the uncertainty in the estimated mean and SD
  through the Normal CDF,
  $`\widehat{\mathrm{Var}}(p) = \phi(a)^2\left[\frac{1}{n} +
  \frac{a^2}{2(n-1)}\right]`$ with $`a = (\mu - m)/\sigma`$.

The `"binomial"` form is a *pseudo-binomial* approximation: $`p_{e,i}`$
and $`p_{c,i}`$ are probabilities implied by the estimated mean and SD,
not proportions of observed dichotomized patients, so it does not carry
the uncertainty in the reported mean and SD. The `"delta"` form does,
and is generally preferable for summary-statistic inputs; `"binomial"`
is the default only for continuity with earlier results. This is the
most defensible method because it respects each study’s own scale.

### Weighted mean

Pool *before* dichotomizing. The mean is combined by inverse variance
and the SD by the within-study pooled SD:

``` math
\bar d^{\star} = \frac{\sum_i \bar d_i / v_i}{\sum_i 1/v_i},\;
v_i = \frac{s_i^2}{n_i}; \qquad
s^{\star} = \sqrt{\frac{\sum_i (n_i - 1)\, s_i^2}{\sum_i (n_i - 1)}}.
```

Then $`p^{\star} = \Phi((\bar d^{\star} - m)/s^{\star})`$ and the
risk-difference variance comes from the delta method, propagating
uncertainty in **both** the pooled mean and the pooled SD,
``` math
\mathrm{Var}(p^{\star}) \approx
\left(\frac{\partial p^{\star}}{\partial \mu}\right)^2 \mathrm{Var}(\bar d^{\star})
+ \left(\frac{\partial p^{\star}}{\partial \sigma}\right)^2 \mathrm{Var}(s^{\star}),
\qquad
\mathrm{Var}(s^{\star}) \approx \frac{s^{\star 2}}{2 \sum_i (n_i - 1)} .
```
Including the SD term keeps this method consistent with the individual
delta method and avoids intervals that are too narrow. This is the
paper-aligned “pool-then-dichotomize” estimator.

### Unweighted mean and median

Replace the pooled summaries with the arithmetic mean or the median of
the study means and SDs. These are useful robustness summaries but have
**no variance model**, so respondeR reports the point estimate with `NA`
intervals rather than a spurious confidence interval.

``` r

responder_analysis(sample_responder_data, mid = 1)[,
  c("method", "p_e", "p_c", "rd", "rd_lb", "rd_ub")]
#>       method       p_e       p_c        rd     rd_lb     rd_ub
#> 1 individual        NA        NA 0.2554475 0.1869705 0.3239244
#> 2   weighted 0.4742782 0.2205372 0.2537410 0.1985865 0.3088955
#> 3 unweighted 0.4767051 0.2279613 0.2487438        NA        NA
#> 4     median 0.4869694 0.2150781 0.2718912        NA        NA
```

### Baseline risk: matched or median control

By default (`control = "matched"`) the control responder proportion is
pooled the same way as the experimental arm, so each summary method
contrasts like with like.

The simulation study that motivated this package (Sofi-Mahmudi, 2024)
instead held the baseline risk fixed at the **median control arm** for
every summary method, varying only how the experimental arm was pooled.
That choice is available via `control = "median"`. It treats the control
event rate as a single nuisance baseline, much as a GRADE
summary-of-findings table takes one representative control risk, and
reports the experimental pooling against it. Because the median control
arm carries no sampling-variance model, this option returns point
estimates only.

``` r

matched <- responder_analysis(sample_responder_data, mid = 1)
medbase <- responder_analysis(sample_responder_data, mid = 1, control = "median")
keep <- matched$method %in% c("median", "unweighted", "weighted")
data.frame(
  method     = matched$method[keep],
  pc_matched = round(matched$p_c[keep], 3),
  pc_median  = round(medbase$p_c[keep], 3),
  rd_matched = round(matched$rd[keep], 3),
  rd_median  = round(medbase$rd[keep], 3)
)
#>       method pc_matched pc_median rd_matched rd_median
#> 1   weighted      0.221     0.215      0.254     0.259
#> 2 unweighted      0.228     0.215      0.249     0.262
#> 3     median      0.215     0.215      0.272     0.272
```

Under `control = "median"` every summary method shares one control
proportion (the median control arm); the `median` method is unchanged,
and the `individual` and `smd` methods, which pool per-study contrasts,
ignore the option.

## Relative effect measures

From $`p_e`$ and $`p_c`$ (and their variances) respondeR also reports
relative measures on the log scale and the number needed to treat:

``` math
\mathrm{RR} = \frac{p_e}{p_c}, \quad
\mathrm{OR} = \frac{p_e/(1 - p_e)}{p_c/(1 - p_c)}, \quad
\mathrm{NNT} = \frac{1}{\mathrm{RD}}.
```

Confidence intervals for RR and OR are formed on the log scale and
back-transformed. Following Altman (1998), when the risk-difference
interval *excludes* zero the NNT bounds are the reciprocals of the RD
bounds; when it *includes* zero the NNT is unbounded and respondeR
returns `NA` bounds to flag it.

``` r

responder_analysis(sample_responder_data, mid = 1, method = "individual")[,
  c("rd", "rr", "rr_lb", "rr_ub", "or", "nnt")]
#>          rd       rr    rr_lb    rr_ub       or      nnt
#> 1 0.2554475 2.148809 1.712779 2.695841 3.198098 3.914699
```

## Common-language effect size (threshold-free)

Choosing a MID can be contentious. The common-language effect size
(CLES, the probabilistic index) is the probability that a randomly
chosen treated patient has a better change than a randomly chosen
control. Under a Normal model it is exact:

``` math
\mathrm{CLES} = \Phi(\delta), \qquad
\delta = \frac{\mu_e - \mu_c}{\sqrt{\sigma_e^2 + \sigma_c^2}}.
```

Per-study $`\delta_i`$ are pooled by inverse variance (with a
delta-method variance) and back-transformed. No threshold is required.

``` r

cles <- responder_cles(sample_responder_data)
c(cles = cles$cles, lb = cles$cles_lb, ub = cles$cles_ub)
#>      cles        lb        ub 
#> 0.6899041 0.6505162 0.7272252
```

## The SMD bridge (`method = "smd"`)

The second approach of Anzures-Cabrera et al. (2011) pools the
standardized mean difference and maps it to an odds ratio. respondeR
pools Hedges’ $`g`$, applies the Cox logistic link
$`\ln\mathrm{OR} = \frac{\pi}{\sqrt 3}\, g`$, and combines the result
with the weighted-pooled control responder rate to recover risks. It is
a useful cross-check on the cut-point methods because it bridges to
risks through a different distributional assumption.

``` r

responder_analysis(sample_responder_data, mid = 1, method = "smd")[,
  c("method", "p_e", "p_c", "rd", "or", "or_lb", "or_ub")]
#>   method       p_e       p_c        rd       or    or_lb    or_ub
#> 1    smd 0.5011813 0.2205372 0.2806441 3.551122 2.688786 4.690023
```

## Random effects and heterogeneity

The individual and SMD methods pool across studies and so can use random
effects (`pooling = "random"`). respondeR offers DerSimonian-Laird
(closed-form, dependency-free) or REML (`tau_method = "REML"`, via
*metafor*), and reports Cochran’s $`Q`$, $`I^2`$, $`\tau^2`$ and a
prediction interval.

``` r

responder_analysis(sample_responder_data, mid = 1, method = "individual",
                   pooling = "random")[, c("tau2", "i2", "q", "q_p",
                                           "pi_lb", "pi_ub")]
#>   tau2 i2      q       q_p    pi_lb     pi_ub
#> 1    0  0 1.6054 0.4481173 -0.18848 0.6993749
```

Prediction intervals use a $`t_{k-2}`$ critical value and are unstable
for very few studies; interpret them cautiously when $`k`$ is small.

For the pooled confidence interval itself, the default Normal (Wald)
interval can under-cover when $`k`$ is small, because $`\tau^2`$ is
poorly estimated. Set `ci_method = "hksj"` for the
Hartung-Knapp-Sidik-Jonkman interval, a $`t`$-based interval whose width
adapts to the observed dispersion of the study estimates and which is
better calibrated for few-study meta-analyses (Rover, Knapp & Friede,
2015). The example below has only three studies, exactly where this
matters.

``` r

rbind(
  wald = responder_analysis(sample_responder_data, mid = 1, method = "individual",
                            pooling = "random", ci_method = "wald")[, c("rd", "rd_lb", "rd_ub")],
  hksj = responder_analysis(sample_responder_data, mid = 1, method = "individual",
                            pooling = "random", ci_method = "hksj")[, c("rd", "rd_lb", "rd_ub")]
)
#>             rd     rd_lb     rd_ub
#> wald 0.2554475 0.1869705 0.3239244
#> hksj 0.2554475 0.1207656 0.3901293
```

## Refinements

- **Bounded intervals** (`ci_type = "logit"`). Proportion intervals are
  formed on the logit scale and risk-difference intervals by Newcombe’s
  MOVER method, so they stay within $`[0, 1]`$ and $`[-1, 1]`$ even for
  extreme proportions.
- **MID uncertainty** (`mid_sd`). If the threshold is itself estimated,
  supplying its SD propagates that uncertainty into the effect-measure
  variances, with the correct between-arm correlation through the shared
  threshold.
- **Alternative distributions** (`dist`). The change scores can be
  modeled as lognormal or Student-$`t`$ instead of Normal, as a
  sensitivity analysis for skewed or heavy-tailed data (variances are
  obtained numerically).
- **Boundary handling.** A MID far from the observed means can make a
  responder probability equal to exactly 0 or 1, which would make log
  ratios, logits and inverse-variance weights non-finite. respondeR
  reports the proportions and the risk difference unclamped, but clamps
  the probabilities that feed ratios, logs and variances away from 0 and
  1 by a tiny amount, so a sensitivity sweep over the MID returns finite
  (if wide) results instead of failing.

``` r

responder_analysis(sample_responder_data, mid = 1, method = "weighted",
                   ci_type = "logit", mid_sd = 0.2)[, c("rd", "rd_lb", "rd_ub")]
#>         rd     rd_lb     rd_ub
#> 1 0.253741 0.1915687 0.3159133
```

## Assumptions and limitations

- **Normality of change scores.** The cut-point probabilities assume the
  patient-level change is Normal within each arm. Skewed outcomes can
  bias the responder proportions; try `dist = "lognormal"`/`"t"` as a
  sensitivity check.
- **Summary-statistic input.** Only means, SDs and sample sizes are
  used; the method cannot recover information lost in aggregation.
- **Choice of MID.** Results depend on the threshold. Report the MID,
  and consider the threshold-free CLES alongside.
- **Normal-approximation intervals.** Wald intervals can fall outside
  valid bounds for extreme proportions or tiny samples; prefer
  `ci_type = "logit"` there.

## Choosing a method

| If you want… | Use |
|----|----|
| A defensible default that respects each study’s scale | `individual` (fixed or random) |
| The paper’s pool-then-dichotomize estimator | `weighted` |
| A robustness or sensitivity summary | `median` / `unweighted` (point estimates) |
| A cross-check via a different bridge to risks | `smd` |
| To avoid choosing a threshold altogether | [`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md) |
| Relative rather than absolute effects | the `rr` / `or` columns; `nnt` for impact |
| Between-study heterogeneity quantified | `pooling = "random"` |

## References

Sofi-Mahmudi, A. (2024). Identifying an optimal strategy for converting
pain as a continuous outcome to a responder analysis \[Master’s thesis,
McMaster University\]. MacSphere. <https://hdl.handle.net/11375/30210>

Thorlund, K., Walter, S. D., Johnston, B. C., Furukawa, T. A., & Guyatt,
G. H. (2011). Pooling health-related quality of life outcomes in
meta-analysis: a tutorial and review of methods for enhancing
interpretability. *Research Synthesis Methods*, 2(3), 188 to 203.
<doi:10.1002/jrsm.46>

Altman, D. G. (1998). Confidence intervals for the number needed to
treat. *BMJ*, 317(7168), 1309 to 1312.

Anzures-Cabrera, J., Sarpatwari, A., & Higgins, J. P. T. (2011).
Expressing findings from meta-analyses of continuous outcomes in terms
of risks. *Statistics in Medicine*, 30(25), 2867 to 2880.
<doi:10.1002/sim.4298>

Chinn, S. (2000). A simple method for converting an odds ratio to effect
size for use in meta-analysis. *Statistics in Medicine*, 19(22), 3127 to
3131.

McGraw, K. O., & Wong, S. P. (1992). A common language effect size
statistic. *Psychological Bulletin*, 111(2), 361 to 365.

Rover, C., Knapp, G., & Friede, T. (2015). Hartung-Knapp-Sidik-Jonkman
approach and its modification for random-effects meta-analysis with few
studies. *BMC Medical Research Methodology*, 15, 99.
<doi:10.1186/s12874-015-0091-1>
