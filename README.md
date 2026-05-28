# AIDAHO IDS THAS 2026

Take Home Assignment (THAS) for the course **Introduction to Data Science with R & RStudio** at the **AIDAHO – AI & Data Science Certificate Hohenheim**.

This repository contains all scripts, data, reports, and deployment files required to reproduce the analysis and web applications for the THAS 2026 assignment.

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
├── 00_docs/                  # Assignment sheets and documentation
│
├── 01_data/                  # Generated datasets and intermediate outputs
│   ├── sample_intervals.csv
│   ├── sample_stratified.csv
│   └── ...
│
├── 02_code/
│   └── R/                    # R scripts for Tasks 2–7
│       ├── functions/        # Helper functions
│       └── ...
│
├── 03_report/
│   ├── graphs/               # Figures and HTML outputs for the report
│   ├── *.pdf                 # Final written report
│   └── ...
│
├── assets/
│   ├── config/               # NGINX configuration
│   ├── shiny/                # Shiny application
│   ├── logs/                 # Shiny logs
│   └── site-content/         # Static HTML dashboard files
│
├── renv/                     # renv project environment
├── renv.lock                 # Locked package versions
├── docker-compose.yaml       # Docker Compose configuration
├── Dockerfile                # Docker image for the Shiny app
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

This restores all required package versions automatically from `renv.lock`.

---

## Running the Analysis

The scripts are organized by THAS task and can generally be executed independently.

A recommended execution order is:

### Task 2 – API Exploration

Run the scripts related to querying and exploring the AIS database.

---

### Task 3 – Sampling

Generate AIS samples:

```r
source("02_code/R/ais_dynamic_sample_points.R")
source("02_code/R/ais_dynamic_sample_stratified.R")
```

Outputs are saved to:

```text
01_data/
```

---

### Task 4 – Vessel Behaviour & Maps

Generate leaflet dashboards and vessel path analyses:

```r
source("02_code/R/sample_dashboard.R")
source("02_code/R/ais_dynamic_individual_paths.R")
```

Outputs are saved to:

```text
03_report/graphs/
```

---

### Task 5 – Traffic Density

Run river and traffic density analyses:

```r
source("02_code/R/ais_traffic_density.R")
```

---

### Task 6 – Static Dashboard

The static dashboard is served via **NGINX** and Docker.

Accessible via:

```text
http://193.197.229.211/sample_points.html
```

---

### Task 7 – Shiny Application

The interactive AIS dashboard is deployed using **Shiny Server + Docker + NGINX reverse proxy**.

Accessible via:

```text
http://193.197.229.211/ais_app
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

## Data Source

The analysis uses **Automatic Identification System (AIS)** data provided through the AIDAHO infrastructure.

Data access is performed through the **PostgREST API** endpoint:

```text
https://aidaho-edu.uni-hohenheim.de/aisdb/
```

Queries are restricted to filtered subsets to avoid unnecessary load on the shared database infrastructure.

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
* Generated report figures are additionally stored in:

```text
03_report/graphs/
```

as required by the THAS guidelines.
