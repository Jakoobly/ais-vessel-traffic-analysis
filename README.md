# AIDAHO IDS THAS 2026

Take Home Assignment (THAS) for the course **Introduction to Data Science with R & RStudio** at the **AIDAHO – AI & Data Science Certificate Hohenheim**.

This repository contains all scripts, generated data, reports, helper functions, and deployment files required to reproduce the analysis and web applications developed for the THAS 2026 assignment.

---

## Team Members

**Jakob Zipperer**
Matrikelnummer: **1103276**

**Roque Hauser**
Matrikelnummer: **1091043**

---

## Repository Structure

```text
AIDAHO_IDS_THAS_2026/
│
├── 00_docs/                          # Assignment sheets and documentation
│
├── 01_data/                          # Generated datasets and intermediate outputs
│   ├── task_*/
│   │   ├── output_*
│   │   └── output_*
│
├── 02_code/
│   └── R/
│       ├── functions/               # Helper functions
│       ├── task_2/                  # Task 2 scripts
│       ├── task_3/                  # Task 3 scripts
│       ├── task_4/                  # Task 4 scripts
│       ├── task_5/                  # Task 5 scripts
│       ├── task_6/                  # Task 6 scripts
│       └── task_7/                  # Task 7 scripts
│
├── 03_report/
│   ├── graphs/                      # Figures and exported plots
│   │
│   ├── task_*/
│   │   ├── optional_outputs
│   │   ├── task*_ai_summary.json
│   │   └── task*_human_summary.md
│
├── assets/
│   ├── config/                      # NGINX configuration
│   ├── shiny/                       # Shiny application
│   ├── logs/                        # Shiny server logs
│   └── site-content/               # Static HTML dashboard deployment
│       └── sample_points.html
│
├── renv/                            # Reproducible R environment
├── renv.lock                        # Locked package versions
├── docker-compose.yaml             # Docker Compose configuration
├── Dockerfile                      # Docker image for Shiny deployment
└── README.md
```

---

## Reproducibility

This project uses **renv** to ensure reproducible package management and a consistent R environment.

### Restore the R environment

Open the project in **RStudio** and run:

```r
install.packages("renv")
renv::restore()
```

All required package versions will be restored automatically from `renv.lock`.

The scripts use project-root detection and were tested from a fresh R session to ensure reproducibility.

---

## Running the Analysis

The scripts are organised by THAS task and can generally be executed independently.

A recommended execution order is shown below.

---

### Task 2 – API Exploration

Run the scripts related to querying and exploring the AIS database.

---

### Task 3 – Sampling

Generate AIS samples:

```r
source("02_code/R/task_3/ais_dynamic_sample_points.R")
source("02_code/R/task_3/ais_dynamic_sample_stratified.R")
```

Outputs are saved to:

```text
01_data/task_3/
```

---

### Task 4 – Vessel Behaviour & Maps

Generate leaflet dashboards and vessel path analyses:

```r
source("02_code/R/task_4/sample_dashboard.R")
source("02_code/R/task_4/ais_dynamic_individual_paths.R")
```

Outputs are saved to:

```text
03_report/graphs/
```

---

### Task 5 – Traffic Density Analysis

Run the river traffic-density analysis:

```r
source("02_code/R/task_5/task5_traffic_density.R")
```

Outputs are saved to:

```text
01_data/task_5/
03_report/task_5/
03_report/graphs/
```

Task 5 generates:

* German river geometries
* River traffic-density calculations
* Rhine traffic-density plots
* Ship-type distributions
* AI-readable and human-readable summaries

---

### Task 6 – Static Dashboard

Generate the static HTML dashboard:

```r
source("02_code/R/task_6/sample_html_dashboard.R")
```

Outputs are saved to:

```text
03_report/task_6/
assets/site-content/
```

The deployed dashboard is accessible via:

```text
http://193.197.229.211:7080/sample_points.html
```

---

### Task 7 – Shiny Application Preparation

Prepare the traffic-density dataset for the Shiny app:

```r
source("02_code/R/task_7/task7_prepare_shiny_data.R")
```

Outputs are saved to:

```text
01_data/task_7/
03_report/task_7/
```

The generated CSV is used by the Shiny application to avoid expensive API requests during user interaction.

---

## Shiny Application

The interactive AIS dashboard is deployed using **Shiny Server**, **Docker**, and **NGINX reverse proxy**.

Access:

```text
http://193.197.229.211:7080/ais_app/
```

---

## Docker Deployment

This repository uses **Docker Compose** for deployment.

### Start containers

```bash
docker compose up -d
```

### Stop containers

```bash
docker compose down
```

### Rebuild containers

```bash
docker compose up -d --build
```

---

## Required Software

The following software is required:

* R (recommended: latest stable version)
* RStudio
* Docker
* Docker Compose
* Git

---

## AI Usage Statement

Generative AI tools (e.g., ChatGPT) were used for:

* debugging and troubleshooting,
* code generation,
* code explanations,
* code refactoring,
* improving documentation and wording.

All generated outputs were critically reviewed, adapted, tested, and validated by the authors.

---

## Notes

* All scripts were tested from a fresh R session before submission.
* Random processes use fixed seeds where necessary to ensure reproducibility.
* Generated figures are stored in:

```text
03_report/graphs/
```

as required by the THAS guidelines.
