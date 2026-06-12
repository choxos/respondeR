#' Launch the Responder Analysis Shiny application
#'
#' Starts the bundled Shiny application, a point-and-click front end to
#' [responder_analysis()]: upload data (or load the example), set the MID and
#' direction of benefit, and view, plot and download the results.
#'
#' @param ... Additional arguments passed to [shiny::runApp()].
#'
#' @return Called for its side effect of launching the app; invisibly returns
#'   the value of [shiny::runApp()].
#'
#' @examplesIf interactive()
#' launch_responder_analysis()
#' @export
launch_responder_analysis <- function(...) {
  app_dir <- system.file("shiny-apps", "ResponderAnalysisApp",
    package = "ResponderAnalysisApp"
  )
  if (app_dir == "") {
    stop(
      "Could not find the Shiny app directory. Try re-installing ",
      "`ResponderAnalysisApp`.",
      call. = FALSE
    )
  }
  for (pkg in c("shinydashboard", "DT")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Package `", pkg, "` is required to run the app. Install it with ",
        "install.packages(\"", pkg, "\").",
        call. = FALSE
      )
    }
  }
  shiny::runApp(app_dir, ...)
}
