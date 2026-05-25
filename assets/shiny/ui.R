ui <- navbarPage(
  title = "AIS River Traffic Density",
  tabPanel(
    "Traffic density",
    sidebarLayout(
      sidebarPanel(
        width = 3,
        p("Interactive Task 7 app based on preprocessed Task 5 data."),
        selectInput(
          inputId = "river",
          label = "River",
          choices = available_rivers,
          selected = if ("Rhine" %in% available_rivers) "Rhine" else available_rivers[1]
        ),
        selectizeInput(
          inputId = "ship_types",
          label = "Ship types",
          choices = available_ship_types,
          selected = default_ship_types,
          multiple = TRUE,
          options = list(plugins = list("remove_button"))
        ),
        actionButton(
          inputId = "update",
          label = "Refresh plot",
          class = "btn-primary",
          width = "100%"
        ),
        br(), br(),
        helpText("The app reads a prepared CSV and does not query the API during interaction.")
      ),
      mainPanel(
        width = 9,
        conditionalPanel(
          condition = "input.update == 0",
          br(),
          h4("Select a river and ship types, then click Refresh plot.")
        ),
        conditionalPanel(
          condition = "input.update > 0",
          plotOutput("traffic_plot", height = "520px"),
          br(),
          textOutput("traffic_status")
        )
      )
    )
  )
)
