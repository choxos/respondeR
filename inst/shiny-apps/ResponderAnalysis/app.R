# ResponderAnalysis -- Shiny front end to the respondeR package.
# A thin UI layer: all statistics are computed by the package's exported,
# unit-tested functions (responder_analysis, responder_rd_individual,
# responder_cles). See ?respondeR::responder_analysis.

library(shiny)
library(shinydashboard)
library(DT)

# The bundled example dataset (falls back to a literal copy if the package is
# not attached, e.g. during ad-hoc sourcing).
sample_data <- tryCatch(
  get("sample_responder_data", envir = asNamespace("respondeR")),
  error = function(e) {
    data.frame(
      study = c("Study 1", "Study 2", "Study 3"),
      change_e = c(0.9581395, 0.7920863, 1.0230769),
      sd_e = c(1.257593, 1.281364, 1.341201),
      n_e = c(43L, 139L, 156L),
      change_c = c(0.217777778, 0.003448276, -0.041975309),
      sd_c = c(1.195501, 1.324629, 1.263178),
      n_c = c(45L, 145L, 162L)
    )
  }
)

ra <- function(name) getExportedValue("respondeR", name)

# ── UI ──
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "ResponderAnalysis"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Analysis", tabName = "analysis", icon = icon("chart-area")),
      menuItem("Methodology", tabName = "methods", icon = icon("book")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    )
  ),
  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper { background:#f4f6fb; }
      .box { border-top-color:#2D4BD8; }
      .small-note { color:#6b7280; font-size:12px; }
      .resp-title { font-weight:600; color:#1A1A2E; margin:0; }
    "))),
    tabItems(
      tabItem(
        tabName = "analysis",
        fluidRow(
          box(
            title = "Data", width = 4, status = "primary",
            fileInput("upload", "Upload CSV or Excel", accept = c(".csv", ".xlsx", ".xls")),
            actionButton("load_sample", "Load example data", icon = icon("table"), class = "btn-info btn-sm"),
            downloadButton("download_template", "Template", class = "btn-default btn-sm"),
            tags$hr(),
            numericInput("mid", "Minimal important difference (MID)", value = 1, step = 0.1),
            radioButtons("direction", "Which direction is a response?",
              c("Higher change is better" = "higher", "Lower change is better" = "lower")
            ),
            actionButton("calculate", "Run analysis", icon = icon("play"), class = "btn-primary")
          ),
          box(
            title = "Options", width = 4, status = "primary", collapsible = TRUE,
            checkboxGroupInput("methods", "Pooling methods",
              choices = c(
                "Individual" = "individual", "Weighted mean" = "weighted",
                "Unweighted mean" = "unweighted", "Median" = "median", "SMD (Cox)" = "smd"
              ),
              selected = c("individual", "weighted", "unweighted", "median")
            ),
            radioButtons("pooling", "Effects model (individual / SMD)",
              c("Fixed" = "fixed", "Random" = "random"), inline = TRUE
            ),
            radioButtons("ci_type", "Interval type",
              c("Wald" = "wald", "Logit" = "logit"), inline = TRUE
            )
          ),
          box(
            title = "Advanced", width = 4, status = "primary", collapsible = TRUE, collapsed = TRUE,
            radioButtons("se_method", "Individual SE", c("Binomial" = "binomial", "Delta" = "delta"), inline = TRUE),
            selectInput("dist", "Change-score distribution",
              c("Normal" = "normal", "Student-t" = "t", "Lognormal" = "lognormal")
            ),
            conditionalPanel("input.dist == 't'", numericInput("df", "t degrees of freedom", value = 10, min = 3)),
            numericInput("mid_sd", "SD of the MID (0 = known exactly)", value = 0, min = 0, step = 0.1),
            sliderInput("conf_level", "Confidence level", min = 0.80, max = 0.99, value = 0.95, step = 0.01)
          )
        ),
        fluidRow(
          box(
            title = "Pooled effect measures", width = 12, status = "primary",
            div(class = "small-note", "Responder proportions (PE, PC) and between-arm contrasts; percentages for PE/PC/RD, ratios for RR/OR."),
            DT::DTOutput("results_table"),
            br(),
            downloadButton("download_results", "Download results (CSV)", class = "btn-sm")
          )
        ),
        fluidRow(
          box(
            title = "Per-study risk differences (forest plot)", width = 7, status = "primary",
            plotOutput("forest", height = "360px")
          ),
          box(
            title = "Common-language effect size", width = 5, status = "primary",
            div(class = "small-note", "Threshold-free: P(a treated patient responds better than a control)."),
            uiOutput("cles_box"),
            tags$hr(),
            DT::DTOutput("perstudy_table")
          )
        )
      ),
      tabItem(
        tabName = "methods",
        box(width = 12, title = "Methodology", status = "primary", uiOutput("methodology"))
      ),
      tabItem(
        tabName = "about",
        box(
          width = 12, title = "About", status = "primary",
          p(strong("ResponderAnalysis"), " is the Shiny front end to the ", strong("respondeR"), " R package."),
          p("Author: Ahmad Sofi-Mahmudi"),
          tags$div(
            tags$a("GitHub", href = "https://github.com/choxos/respondeR", target = "_blank"), " | ",
            tags$a("Documentation", href = "https://choxos.github.io/respondeR", target = "_blank")
          ),
          tags$hr(),
          p(class = "small-note", "Method: Anzures-Cabrera J, Sarpatwari A, Higgins JPT (2011). Expressing findings from meta-analyses of continuous outcomes in terms of risks. Statistics in Medicine, 30(25), 2867-2880.")
        )
      )
    )
  )
)

# ── Server ──
server <- function(input, output, session) {
  rv <- reactiveValues(data = NULL, results = NULL, perstudy = NULL, cles = NULL)

  read_uploaded <- function(path, name) {
    ext <- tolower(tools::file_ext(name))
    if (ext %in% c("xlsx", "xls")) {
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Install the 'readxl' package to upload Excel files.")
      }
      as.data.frame(readxl::read_excel(path))
    } else {
      utils::read.csv(path, check.names = TRUE)
    }
  }

  observeEvent(input$load_sample, {
    rv$data <- sample_data
    showNotification("Example data loaded.", type = "message")
  })

  observeEvent(input$upload, {
    req(input$upload)
    tryCatch(
      {
        rv$data <- read_uploaded(input$upload$datapath, input$upload$name)
        showNotification("Data uploaded.", type = "message")
      },
      error = function(e) {
        showNotification(paste("Upload failed:", conditionMessage(e)), type = "error")
        rv$data <- NULL
      }
    )
  })

  observeEvent(input$calculate, {
    req(rv$data)
    methods <- input$methods
    if (length(methods) == 0) {
      showNotification("Select at least one method.", type = "warning")
      return()
    }
    tryCatch(
      {
        df_arg <- if (input$dist == "t") input$df else NULL
        rv$results <- ra("responder_analysis")(
          rv$data,
          mid = input$mid, direction = input$direction, method = methods,
          se_method = input$se_method, pooling = input$pooling,
          dist = input$dist, df = df_arg,
          mid_sd = input$mid_sd, ci_type = input$ci_type, conf_level = input$conf_level
        )
        rv$perstudy <- ra("responder_rd_individual")(
          rv$data,
          mid = input$mid, direction = input$direction,
          se_method = input$se_method, conf_level = input$conf_level,
          dist = input$dist, df = df_arg, mid_sd = input$mid_sd
        )
        rv$cles <- ra("responder_cles")(
          rv$data,
          direction = input$direction, pooling = input$pooling, conf_level = input$conf_level
        )
        showNotification("Analysis complete.", type = "message")
      },
      error = function(e) {
        showNotification(paste("Analysis error:", conditionMessage(e)), type = "error")
        rv$results <- NULL
        rv$perstudy <- NULL
        rv$cles <- NULL
      }
    )
  })

  display_table <- reactive({
    req(rv$results)
    res <- rv$results
    fmt <- ra("format_responder_results")(res)
    fmt$NNT <- ifelse(is.na(res$nnt) | !is.finite(res$nnt), "-", formatC(res$nnt, format = "f", digits = 1))
    fmt$`I-squared` <- ifelse(is.na(res$i2), "-", sprintf("%.0f%%", 100 * res$i2))
    fmt
  })

  output$results_table <- DT::renderDT({
    DT::datatable(display_table(),
      rownames = FALSE, options = list(dom = "t", ordering = FALSE)
    )
  })

  output$forest <- renderPlot({
    req(rv$perstudy, rv$results)
    ps <- rv$perstudy
    pooled <- rv$results[rv$results$method == "individual", ]
    has_pooled <- nrow(pooled) == 1
    labels <- c(as.character(ps$study), if (has_pooled) "Pooled (individual)")
    est <- c(ps$rd, if (has_pooled) pooled$rd) * 100
    lo <- c(ps$ci_lb, if (has_pooled) pooled$rd_lb) * 100
    hi <- c(ps$ci_ub, if (has_pooled) pooled$rd_ub) * 100
    n <- length(est)
    ypos <- rev(seq_len(n))

    op <- par(mar = c(4, 8.5, 1, 1))
    on.exit(par(op))
    xlim <- range(c(lo, hi, 0), na.rm = TRUE)
    plot(NA,
      xlim = xlim, ylim = c(0.5, n + 0.5), yaxt = "n",
      xlab = "Risk difference (%)", ylab = "", bty = "n"
    )
    abline(v = 0, col = "#9ca3af", lty = 2)
    is_pool <- labels == "Pooled (individual)"
    cols <- ifelse(is_pool, "#2D4BD8", "#1A1A2E")
    segments(lo, ypos, hi, ypos, col = cols, lwd = 2)
    points(est, ypos,
      pch = ifelse(is_pool, 18, 15), col = cols,
      cex = ifelse(is_pool, 2.2, 1.5)
    )
    axis(2, at = ypos, labels = labels, las = 1, tick = FALSE)
  })

  output$cles_box <- renderUI({
    req(rv$cles)
    cl <- rv$cles
    tagList(
      tags$h2(class = "resp-title", sprintf("%.1f%%", 100 * cl$cles)),
      tags$p(class = "small-note", sprintf(
        "%d%% CI: %.1f%% to %.1f%%%s",
        round(100 * input$conf_level), 100 * cl$cles_lb, 100 * cl$cles_ub,
        if (!is.na(cl$i2)) sprintf("  |  I-squared = %.0f%%", 100 * cl$i2) else ""
      ))
    )
  })

  output$perstudy_table <- DT::renderDT({
    req(rv$perstudy)
    ps <- rv$perstudy
    out <- data.frame(
      Study = ps$study,
      PE = sprintf("%.1f", 100 * ps$p_e),
      PC = sprintf("%.1f", 100 * ps$p_c),
      RD = sprintf("%.1f (%.1f, %.1f)", 100 * ps$rd, 100 * ps$ci_lb, 100 * ps$ci_ub)
    )
    DT::datatable(out, rownames = FALSE, options = list(dom = "t", ordering = FALSE))
  })

  output$methodology <- renderUI({
    tagList(
      p("Responder analysis converts continuous trial outcomes (mean change, SD and sample size per arm) into the proportion of patients who cross a minimal important difference (MID) threshold, assuming the change scores are Normally distributed, and contrasts the arms as a risk difference (RD), risk ratio (RR), odds ratio (OR) or number needed to treat (NNT)."),
      tags$ul(
        tags$li(strong("Individual:"), " dichotomise each study then pool the per-study effects (fixed or random effects)."),
        tags$li(strong("Weighted mean:"), " inverse-variance pooled mean with a within-study pooled SD, then dichotomise."),
        tags$li(strong("Unweighted / Median:"), " dichotomise the mean / median of the study summaries (no variance model)."),
        tags$li(strong("SMD (Cox):"), " pool the standardised mean difference and bridge to an odds ratio via the logistic link."),
        tags$li(strong("CLES:"), " threshold-free probability that a treated patient responds better than a control.")
      ),
      p(class = "small-note", "Reference: Anzures-Cabrera, Sarpatwari & Higgins (2011), Statistics in Medicine 30(25):2867-2880.")
    )
  })

  output$download_template <- downloadHandler(
    filename = function() "responder_template.csv",
    content = function(file) {
      utils::write.csv(
        data.frame(
          study = character(), change_e = numeric(), sd_e = numeric(), n_e = integer(),
          change_c = numeric(), sd_c = numeric(), n_c = integer()
        ),
        file,
        row.names = FALSE
      )
    }
  )

  output$download_results <- downloadHandler(
    filename = function() "responder_results.csv",
    content = function(file) {
      req(rv$results)
      utils::write.csv(rv$results, file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)
