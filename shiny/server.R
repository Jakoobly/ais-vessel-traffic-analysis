server <- function(input, output, session) {
  traffic_data <- eventReactive(input$update, {
    req(input$river, input$ship_types)
    
    filter_traffic(
      data = traffic_density_data,
      river = input$river,
      ship_types = input$ship_types
    )
  }, ignoreInit = FALSE)
  
  output$traffic_plot <- renderPlot({
    plot_data <- traffic_data()
    
    validate(
      need(nrow(plot_data) > 0, "No records found for the selected filters.")
    )
    
    plot_traffic_density(
      data = plot_data,
      river = input$river,
      ship_types = input$ship_types
    )
  })
  
  output$traffic_status <- renderText({
    plot_data <- traffic_data()
    
    if (nrow(plot_data) == 0) {
      "No records found for the selected filters. Try another river or ship type."
    } else {
      paste0(
        "Displayed ", sum(plot_data$n_records),
        " AIS records across ", nrow(plot_data),
        " distance bins."
      )
    }
  })
}