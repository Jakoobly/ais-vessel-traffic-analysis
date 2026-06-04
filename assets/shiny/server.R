server <- function(input, output, session) {
  output$total_records <- renderText(format_big_number(total_records))
  output$total_rivers <- renderText(format_big_number(total_rivers))
  output$total_ship_types <- renderText(format_big_number(total_ship_types))

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
      "No matching records"
    } else {
      paste0(
        format_big_number(sum(plot_data$n_records)),
        " records · ",
        format_big_number(nrow(plot_data)),
        " bins"
      )
    }
  })
}
