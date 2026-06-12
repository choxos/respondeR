# Load required libraries
library(shiny)
library(shinydashboard)
library(DT)

# Sample data
sample_data <- read.csv(textConnection("study,change_e,sd_e,n_e,change_c,sd_c,n_c
Study 1,0.9581395,1.257593,43,0.217777778,1.195501,45
Study 2,0.7920863,1.281364,139,0.003448276,1.324629,145
Study 3,1.0230769,1.341201,156,-0.041975309,1.263178,162"))

# UI
ui <- dashboardPage(
        dashboardHeader(title = "Responder Analysis App"),
        dashboardSidebar(
                sidebarMenu(
                        menuItem("Responder Analysis", tabName = "analysis", icon = icon("calculator")),
                        menuItem("About", tabName = "about", icon = icon("info-circle"))
                )
        ),
        dashboardBody(
                tabItems(
                        # Responder Analysis tab
                        tabItem(tabName = "analysis",
                                fluidRow(
                                        box(
                                                title = "Data Input",
                                                width = 12,
                                                downloadButton("download_template", "Download Template"),
                                                fileInput("upload_file", "Upload Data File", accept = c(".csv", ".xlsx")),
                                                actionButton("load_sample", "Load Sample Data", class = "btn-info"),
                                                numericInput("mid_input", "Enter MID:", value = 1, step = 0.1),
                                                actionButton("calculate", "Calculate", class = "btn-primary")
                                        )
                                ),
                                fluidRow(
                                        box(
                                                title = "Results and Downloads",
                                                width = 12,
                                                uiOutput("results_and_downloads")
                                        )
                                )
                        ),
                        
                        # About tab
                        tabItem(tabName = "about",
                                fluidRow(
                                        box(
                                                title = "About the Creator",
                                                width = 12,
                                                p("Creator: Ahmad Sofi-Mahmudi"),
                                                p("Master's student in Health Research Methodology"),
                                                p("McMaster University"),
                                                br(),
                                                p("Social Media:"),
                                                tags$div(
                                                        tags$a("Blog", href = "https://choxos.com", target = "_blank"),
                                                        tags$span(" | "),
                                                        tags$a("GitHub", href = "https://github.com/choxos", target = "_blank"),
                                                        tags$span(" | "),
                                                        tags$a("Twitter", href = "https://twitter.com/ASofiMahmudi", target = "_blank"),
                                                        tags$span(" | "),
                                                        tags$a("LinkedIn", href = "https://www.linkedin.com/in/asofimahmudi/", target = "_blank")
                                                )
                                        )
                                )
                        )
                )
        )
)

# Server
server <- function(input, output, session) {
        
        # Reactive values to store data and results
        rv <- reactiveValues(
                data = NULL,
                results = NULL,
                mid = 1.0
        )
        
        # Download template
        output$download_template <- downloadHandler(
                filename = function() {
                        "responder_analysis_template.csv"
                },
                content = function(file) {
                        write.csv(data.frame(
                                study = c("Study 1", "Study 2", "Study 3"),
                                change_e = c(NA, NA, NA),
                                sd_e = c(NA, NA, NA),
                                n_e = c(NA, NA, NA),
                                change_c = c(NA, NA, NA),
                                sd_c = c(NA, NA, NA),
                                n_c = c(NA, NA, NA)
                        ), file, row.names = FALSE)
                }
        )
        
        # Load sample data
        observeEvent(input$load_sample, {
                rv$data <- sample_data
                showNotification("Sample data loaded successfully", type = "message")
        })
        
        # Upload data file
        observeEvent(input$upload_file, {
                req(input$upload_file)
                tryCatch({
                        rv$data <- read.csv(input$upload_file$datapath, check.names = FALSE)
                        
                        # Check if all required columns are present
                        required_columns <- c("study", "change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c")
                        missing_columns <- setdiff(required_columns, names(rv$data))
                        
                        if (length(missing_columns) > 0) {
                                showNotification(paste("Missing columns:", paste(missing_columns, collapse = ", ")), type = "error")
                                rv$data <- NULL
                        } else {
                                # Convert numeric columns to numeric type
                                numeric_columns <- c("change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c")
                                rv$data[numeric_columns] <- lapply(rv$data[numeric_columns], as.numeric)
                                showNotification("Data loaded successfully", type = "message")
                        }
                }, error = function(e) {
                        showNotification(paste("Error reading file:", e$message), type = "error")
                        rv$data <- NULL
                })
        })
        
        # Update MID value when input changes
        observe({
                rv$mid <- input$mid_input
        })
        
        # Calculate button
        observeEvent(input$calculate, {
                req(rv$data)
                
                tryCatch({
                        # Perform calculations for each method
                        # Median
                        pc_median = (1-pnorm((rv$mid-median(rv$data$change_c))/median(rv$data$sd_c)))*100
                        pe_median = (1-pnorm((rv$mid-median(rv$data$change_e))/median(rv$data$sd_e)))*100
                        rd_median = pe_median - pc_median
                        var_rd_median = (((pe_median/100)*(1-(pe_median/100)))/sum(rv$data$n_e)) + (((pc_median/100)*(1-(pc_median/100)))/sum(rv$data$n_c))
                        ci_rd_median = rd_median + c(-1, 1) * qnorm(0.975) * sqrt(var_rd_median)
                        
                        # Unweighted average
                        pe_unweighted_mean = (1-pnorm((rv$mid-mean(rv$data$change_e))/mean(rv$data$sd_e)))*100
                        rd_unweighted_mean = pe_unweighted_mean - pc_median
                        var_rd_unweighted_mean = (((pe_unweighted_mean/100)*(1-(pe_unweighted_mean/100)))/sum(rv$data$n_e)) + (((pc_median/100)*(1-(pc_median/100)))/sum(rv$data$n_c))
                        ci_rd_unweighted_mean = rd_unweighted_mean + c(-1, 1) * qnorm(0.975) * sqrt(var_rd_unweighted_mean)
                        
                        # Weighted average
                        weighted_avg_mean_e = respondeR::iv_meta(rv$data$change_e, rv$data$sd_e, rv$data$n_e)
                        weighted_avg_sd_e = respondeR::iv_meta(rv$data$sd_e, rv$data$sd_e, rv$data$n_e)
                        pe_weighted_mean = (1-pnorm((rv$mid-weighted_avg_mean_e)/weighted_avg_sd_e))*100
                        rd_weighted_mean = pe_weighted_mean - pc_median
                        var_rd_weighted_mean = (((pe_weighted_mean/100)*(1-(pe_weighted_mean/100)))/sum(rv$data$n_e)) + (((pc_median/100)*(1-(pc_median/100)))/sum(rv$data$n_c))
                        ci_rd_weighted_mean = rd_weighted_mean + c(-1, 1) * qnorm(0.975) * sqrt(var_rd_weighted_mean)
                        
                        # Individual method
                        rv$data$pe = (1-pnorm((rv$mid-rv$data$change_e)/rv$data$sd_e))*100
                        rv$data$pc = (1-pnorm((rv$mid-rv$data$change_c)/rv$data$sd_c))*100
                        summary_ind = data.frame(pe = rv$data$pe, pc = rv$data$pc, n_e = rv$data$n_e, n_c = rv$data$n_c)
                        summary_ind$RD = summary_ind$pe - summary_ind$pc
                        summary_ind$SE = sqrt(((summary_ind$pe*(100-summary_ind$pe)/summary_ind$n_e) +
                                                       (summary_ind$pc*(100-summary_ind$pc)/summary_ind$n_c)))
                        rd_ind_result = respondeR::iv_meta(mean = summary_ind$RD, se = summary_ind$SE)
                        rd_ind = rd_ind_result[1]
                        ci_rd_ind = rd_ind_result[2:3]
                        
                        # Create a single dataframe with all results
                        rv$results = data.frame(
                                Method = c("Median", "Unweighted Mean", "Weighted Mean", "Individual"),
                                PE = c(pe_median, pe_unweighted_mean, pe_weighted_mean, NA),
                                PC = c(pc_median, pc_median, pc_median, NA),
                                RD = c(rd_median, rd_unweighted_mean, rd_weighted_mean, rd_ind),
                                CI_Lower = c(ci_rd_median[1], ci_rd_unweighted_mean[1], ci_rd_weighted_mean[1], ci_rd_ind[1]),
                                CI_Upper = c(ci_rd_median[2], ci_rd_unweighted_mean[2], ci_rd_weighted_mean[2], ci_rd_ind[2])
                        )
                        
                        # Round all numeric columns to 2 decimal places
                        rv$results[, 2:6] <- round(rv$results[, 2:6], 2)
                        
                        # Add formatted RD column
                        rv$results$RD_with_CI <- sprintf("%.2f (%.2f-%.2f)", 
                                                         rv$results$RD, 
                                                         rv$results$CI_Lower, 
                                                         rv$results$CI_Upper)
                        
                        # Store individual study results
                        rv$individual_results <- rv$data[, c("study", "pe", "pc")]
                        rv$individual_results$RD <- rv$individual_results$pe - rv$individual_results$pc
                        rv$individual_results <- data.frame(
                                Study = rv$individual_results$study,
                                PE = round(rv$individual_results$pe, 2),
                                PC = round(rv$individual_results$pc, 2),
                                RD = round(rv$individual_results$RD, 2)
                        )
                        
                        showNotification("Calculations completed successfully", type = "message")
                }, error = function(e) {
                        showNotification(paste("Error in calculations:", e$message), type = "error")
                        rv$results <- NULL
                        rv$individual_results <- NULL
                })
        })
        
        # Render results table
        output$results_table <- DT::renderDT({
                req(rv$results)
                DT::datatable(rv$results[, c("Method", "PE", "PC", "RD_with_CI")], 
                              options = list(pageLength = 5, dom = 't'),
                              rownames = FALSE)
        })
        
        # Render individual results table
        output$individual_results_table <- DT::renderDT({
                req(rv$individual_results)
                DT::datatable(rv$individual_results, 
                              options = list(pageLength = 10, dom = 't'),
                              rownames = FALSE)
        })
        
        # Download results
        output$download_results <- downloadHandler(
                filename = function() {
                        "responder_analysis_results.csv"
                },
                content = function(file) {
                        write.csv(rv$results, file, row.names = FALSE)
                }
        )
        
        # Download individual results
        output$download_individual_results <- downloadHandler(
                filename = function() {
                        "individual_study_results.csv"
                },
                content = function(file) {
                        write.csv(rv$individual_results, file, row.names = FALSE)
                }
        )
        
        # Render results and download buttons
        output$results_and_downloads <- renderUI({
                req(rv$results, rv$individual_results)
                tagList(
                        h4("Aggregated Results"),
                        DT::DTOutput("results_table"),
                        br(),
                        downloadButton("download_results", "Download Aggregated Results"),
                        br(), br(),
                        h4("Individual Study Results"),
                        DT::DTOutput("individual_results_table"),
                        br(),
                        downloadButton("download_individual_results", "Download Individual Results")
                )
        })
}

# Run the application 
shinyApp(ui = ui, server = server)