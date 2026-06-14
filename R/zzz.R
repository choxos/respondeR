.onAttach <- function(libname, pkgname) {
  version <- utils::packageVersion(pkgname)
  packageStartupMessage(sprintf(
    paste0(
      "respondeR %s: impute responder proportions from continuous outcomes.\n",
      "Analyze arm summaries with responder_analysis(); launch the app with launch_responder_analysis().\n",
      "Docs: https://choxos.github.io/respondeR/ | GitHub: https://github.com/choxos/respondeR"
    ),
    version
  ))
  invisible()
}
