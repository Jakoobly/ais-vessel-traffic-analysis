ui <- navbarPage(
  title = "AIS Explorer",
  
  tabPanel(
    "Traffic distribution",
    sidebarLayout(
      sidebarPanel(
        width = 3,
        
        # -------------------------------------------------------
        # Option A: selectInput for river, selectizeInput for ship_type
        # Option B: selectInput for hour, selectInput for collection_type,
        #           selectizeInput for ship_type
        # Both options: actionButton to trigger the plot update
        # TODO: add your input controls here
        # -------------------------------------------------------
        
        actionButton(
          inputId = "update",
          label   = "Update",
          class   = "btn-primary",
          width   = "100%"
        )
      ),
      mainPanel(
        width = 9,
        
        # shown until the button is clicked for the first time
        conditionalPanel(
          condition = "input.update == 0",
          br(),
          h4("The app is running but you might have to modify it. Hit *Update* to continue!")
        ),
        
        # shown after the button has been clicked at least once
        conditionalPanel(
          condition = "input.update > 0",
          plotOutput("traffic_plot", height = "500px"),
          br(),
          textOutput("traffic_status")
        )
      )
    )
  )
)