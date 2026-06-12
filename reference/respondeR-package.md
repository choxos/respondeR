# respondeR: Responder Analysis for Continuous Outcomes

Express meta-analyses of continuous trial outcomes in terms of responder
risks, following the interpretability tutorial of Thorlund, Walter,
Johnston, Furukawa and Guyatt (2011)
[doi:10.1002/jrsm.46](https://doi.org/10.1002/jrsm.46) . Given the mean
change, standard deviation and sample size per arm across studies,
respondeR estimates the proportion of patients who cross a minimal
important difference (MID) threshold under a parametric model for the
change scores, and contrasts the arms as a risk difference, risk ratio,
odds ratio or number needed to treat. It provides median,
unweighted-mean, weighted-mean and per-study (fixed- or random-effects)
pooling, the standardised-mean-difference to odds-ratio bridge of
Anzures-Cabrera, Sarpatwari and Higgins (2011)
[doi:10.1002/sim.4298](https://doi.org/10.1002/sim.4298) , a
threshold-free common-language effect size, and a point-and-click
'Shiny' application.

## Details

The package converts continuous trial outcomes (mean change, standard
deviation and sample size per arm, across studies) into the proportion
of "responders" – patients whose change crosses a minimal important
difference (MID) threshold – under a Normal model for the change scores,
and expresses the between-arm contrast as a risk difference (RD). Four
pooling strategies are provided (median, unweighted mean, weighted mean
and individual), following the interpretability methods reviewed by
Thorlund and colleagues (2011) and the cut-point ("dichotomisation") and
standardised-mean-difference approaches of Anzures-Cabrera, Sarpatwari
and Higgins (2011).

The statistical engine lives in exported, side-effect-free functions
([`responder_analysis()`](https://choxos.github.io/respondeR/reference/responder_analysis.md),
[`responder_proportions()`](https://choxos.github.io/respondeR/reference/responder_proportions.md),
[`responder_rd_individual()`](https://choxos.github.io/respondeR/reference/responder_rd_individual.md),
[`responder_cles()`](https://choxos.github.io/respondeR/reference/responder_cles.md))
so that results are reproducible and unit tested independently of the
bundled Shiny application
([`launch_responder_analysis()`](https://choxos.github.io/respondeR/reference/launch_responder_analysis.md)).

## References

Thorlund K, Walter SD, Johnston BC, Furukawa TA, Guyatt GH (2011).
Pooling health-related quality of life outcomes in meta-analysis – a
tutorial and review of methods for enhancing interpretability. *Research
Synthesis Methods*, 2(3), 188-203.
[doi:10.1002/jrsm.46](https://doi.org/10.1002/jrsm.46)

Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings
from meta-analyses of continuous outcomes in terms of risks. *Statistics
in Medicine*, 30(25), 2867-2880.
[doi:10.1002/sim.4298](https://doi.org/10.1002/sim.4298)

## See also

Useful links:

- <https://github.com/choxos/respondeR>

- <https://choxos.github.io/respondeR/>

- Report bugs at <https://github.com/choxos/respondeR/issues>

## Author

**Maintainer**: Ahmad Sofi-Mahmudi <a.sofimahmudi@gmail.com>
([ORCID](https://orcid.org/0000-0001-6829-0823))

Authors:

- Ahmad Sofi-Mahmudi <a.sofimahmudi@gmail.com>
  ([ORCID](https://orcid.org/0000-0001-6829-0823))
