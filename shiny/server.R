server <- function(input, output, session) {
  
  # -------------------------------------------------------
  # Fetch data when the update button is clicked
  # TODO: add the required input IDs to req()
  # TODO: pass the correct arguments to fetch_traffic()
  # -------------------------------------------------------
  traffic_data <- eventReactive(input$update, {
    req()
    fetch_traffic()
  })
  
  # -------------------------------------------------------
  # Render the plot
  # TODO: pass the correct arguments to plot_traffic()
  # -------------------------------------------------------
  output$traffic_plot <- renderPlot({
    req(traffic_data())
    plot_traffic()
  })
  
  # -------------------------------------------------------
  # Show a message when no data is returned
  # -------------------------------------------------------
  output$traffic_status <- renderText({
    req(traffic_data())
    if (nrow(traffic_data()) == 0) {
      "No records found for the selected filters. Try adjusting your selection."
    }
  })
  
}