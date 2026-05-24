server <- function(input, output, session) {
  traffic_data <- eventReactive(input$update, {
    req(input$river, input$ship_types)
    filter_traffic(
      data = traffic_density_data,
      river = input$river,
      ship_types = input$ship_types
    )
  })

  output$traffic_plot <- renderPlot({
    req(traffic_data())
    validate(need(nrow(traffic_data()) > 0, "No records found for the selected filters."))
    plot_traffic_density(
      data = traffic_data(),
      river = input$river,
      ship_types = input$ship_types
    )
  })

  output$traffic_status <- renderText({
    req(traffic_data())
    if (nrow(traffic_data()) == 0) {
      "No records found for the selected filters. Try another river or ship type."
    } else {
      paste0(
        "Displayed ", sum(traffic_data()$n_records),
        " AIS records across ", nrow(traffic_data()),
        " distance bins."
      )
    }
  })
}
