ui <- tagList(
  tags$head(
    tags$title("AIS River Traffic Density"),
    tags$style(HTML("
      :root {
        --bg: #eef3f8;
        --card: rgba(255, 255, 255, 0.94);
        --text: #172033;
        --muted: #5f6f89;
        --blue: #2f80ed;
        --green: #12b886;
        --border: rgba(23, 32, 51, 0.10);
        --shadow: 0 24px 70px rgba(20, 35, 70, 0.16);
      }

      body {
        background:
          radial-gradient(circle at top left, rgba(47, 128, 237, 0.20), transparent 32rem),
          radial-gradient(circle at top right, rgba(18, 184, 134, 0.16), transparent 30rem),
          var(--bg);
        color: var(--text);
        font-family: Arial, Helvetica, sans-serif;
      }

      .app-shell {
        max-width: 1280px;
        margin: 0 auto;
        padding: 28px 24px 40px;
      }

      .hero {
        display: grid;
        grid-template-columns: 1.6fr 1fr;
        gap: 18px;
        align-items: stretch;
        margin-bottom: 18px;
      }

      .hero-card, .control-card, .plot-card, .metric-card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 24px;
        box-shadow: var(--shadow);
      }

      .hero-card {
        padding: 30px;
        overflow: hidden;
        position: relative;
      }

      .hero-card::after {
        content: '';
        position: absolute;
        right: -80px;
        top: -80px;
        width: 230px;
        height: 230px;
        border-radius: 999px;
        background: rgba(47, 128, 237, 0.14);
      }

      .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 7px 12px;
        border-radius: 999px;
        background: rgba(47, 128, 237, 0.12);
        color: #1f5fbf;
        font-weight: 700;
        font-size: 12px;
        letter-spacing: 0.04em;
        text-transform: uppercase;
      }

      h1 {
        margin: 18px 0 10px;
        font-size: clamp(30px, 4vw, 52px);
        line-height: 1.02;
        font-weight: 800;
        letter-spacing: -0.04em;
      }

      .hero-text {
        max-width: 720px;
        color: var(--muted);
        font-size: 16px;
        line-height: 1.6;
      }

      .metrics {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 14px;
      }

      .metric-card {
        padding: 20px;
      }

      .metric-value {
        font-size: 28px;
        font-weight: 800;
        color: var(--text);
      }

      .metric-label {
        margin-top: 4px;
        color: var(--muted);
        font-size: 13px;
      }

      .content-grid {
        display: grid;
        grid-template-columns: 340px minmax(0, 1fr);
        gap: 18px;
      }

      .control-card, .plot-card {
        padding: 22px;
      }

      .control-title {
        margin: 0 0 8px;
        font-size: 20px;
        font-weight: 800;
      }

      .control-subtitle {
        margin-bottom: 18px;
        color: var(--muted);
        line-height: 1.45;
      }

      label.control-label {
        color: var(--text);
        font-weight: 750;
      }

      .form-control, .selectize-input {
        border-radius: 14px !important;
        border-color: #d8e2ef !important;
        box-shadow: none !important;
        min-height: 42px;
      }

      .btn-primary {
        border: 0;
        border-radius: 16px;
        padding: 12px 16px;
        font-weight: 800;
        background: linear-gradient(135deg, var(--blue), var(--green));
        box-shadow: 0 14px 28px rgba(47, 128, 237, 0.25);
      }

      .btn-primary:hover, .btn-primary:focus {
        filter: brightness(0.98);
        transform: translateY(-1px);
      }

      .hint-box {
        margin-top: 16px;
        padding: 13px 14px;
        border-radius: 16px;
        background: #f6f9fd;
        color: var(--muted);
        border: 1px solid #e6edf6;
        font-size: 13px;
        line-height: 1.45;
      }

      .plot-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 14px;
        margin-bottom: 8px;
      }

      .plot-title {
        margin: 0;
        font-size: 22px;
        font-weight: 800;
      }

      .status-pill {
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(18, 184, 134, 0.12);
        color: #087f5b;
        font-weight: 750;
        font-size: 13px;
        white-space: nowrap;
      }

      .empty-state {
        padding: 90px 20px;
        text-align: center;
        color: var(--muted);
        border: 1px dashed #cbd7e6;
        border-radius: 20px;
        background: #f8fbff;
      }

      @media (max-width: 960px) {
        .hero, .content-grid, .metrics {
          grid-template-columns: 1fr;
        }
      }
    "))
  ),
  div(
    class = "app-shell",
    div(
      class = "hero",
      div(
        class = "hero-card",
        div(class = "eyebrow", "THAS 2026 · Shiny Dashboard"),
        h1("AIS River Traffic Density"),
        p(
          class = "hero-text",
          "Explore preprocessed AIS traffic density on German rivers for 2022-04-23. Select a river and one or more ship types, then refresh the chart."
        )
      ),
      div(
        class = "metrics",
        div(class = "metric-card", div(class = "metric-value", textOutput("total_records", inline = TRUE)), div(class = "metric-label", "AIS records in prepared data")),
        div(class = "metric-card", div(class = "metric-value", textOutput("total_rivers", inline = TRUE)), div(class = "metric-label", "available rivers")),
        div(class = "metric-card", div(class = "metric-value", textOutput("total_ship_types", inline = TRUE)), div(class = "metric-label", "ship type values"))
      )
    ),
    div(
      class = "content-grid",
      div(
        class = "control-card",
        h2(class = "control-title", "Filters"),
        div(class = "control-subtitle", "Explore vessel traffic patterns by selecting a river and vessel categories. Update the visualization to analyze traffic density."),
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
          options = list(plugins = list("remove_button"), placeholder = "Choose ship types")
        ),
        actionButton(
          inputId = "update",
          label = "Refresh plot",
          class = "btn-primary",
          width = "100%"
        ),
        div(class = "hint-box", "Optimized for responsiveness using preprocessed traffic data.")
      ),
      div(
        class = "plot-card",
        div(
          class = "plot-header",
          h2(class = "plot-title", "Traffic density plot"),
          div(class = "status-pill", textOutput("traffic_status", inline = TRUE))
        ),
        conditionalPanel(
          condition = "input.update == 0",
          div(class = "empty-state", h3("Ready when you are"), p("Select filters on the left and click Refresh plot."))
        ),
        conditionalPanel(
          condition = "input.update > 0",
          plotOutput("traffic_plot", height = "560px")
        )
      )
    )
  )
)
