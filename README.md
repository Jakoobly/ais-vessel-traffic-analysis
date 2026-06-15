# AIDAHO_IDS_THAS_2026

Take Home Assignment (THAS) for the course **Introduction to Data Science with R & RStudio** at the **AIDAHO – AI & Data Science Certificate Hohenheim**, University of Hohenheim.

This repository contains all code, generated datasets, figures, reports, helper functions, and deployment files required to reproduce the analyses and web applications developed for the THAS 2026 assignment.

---

## Team Members

| Name           | Student ID |
| -------------- | ---------- |
| Jakob Zipperer | 1103276    |
| Roque Hauser   | 1091043    |

---

## Repository Structure

```text
AIDAHO_IDS_THAS_2026/
│
├── 00_docs/                         # Assignment sheets and supporting documentation
│
├── 01_data/                         # Generated datasets and intermediate outputs
│   └── task_*/
│
├── 02_code/
│   └── R/
│       ├── functions/              # Helper functions
│       ├── task_2/                 # API exploration
│       ├── task_3/                 # Sampling strategies
│       ├── task_4/                 # Vessel behaviour analysis
│       ├── task_5/                 # Traffic density analysis
│       ├── task_6/                 # Static dashboard
│       └── task_7/                 # Shiny app preparation
│
├── 03_report/
│   ├── graphs/                     # Figures used in the report
│   └── task_*/                     # Task-specific outputs
│
├── assets/
│   ├── config/                     # NGINX configuration
│   ├── shiny/                      # Shiny application files
│   ├── logs/                       # Server logs
│   └── site-content/               # Static HTML content
│
├── renv/                           # Reproducible R environment
├── renv.lock                       # Locked package versions
├── docker-compose.yaml             # Docker deployment
├── Dockerfile                      # Shiny Docker image
└── README.md
```

---

## Reproducibility

This project uses **renv** for reproducible package management.

To restore the required R environment:

```r
install.packages("renv")
renv::restore()
```

All required package versions will automatically be restored from `renv.lock`.

The code was tested from a **fresh R session** to ensure reproducibility.

---

## Required Software

The following software is required:

* **R** (latest stable version recommended)
* **RStudio**
* **Git**
* **Docker**
* **Docker Compose**

---

## Recommended Execution Order

The scripts are organized according to the THAS tasks and can generally be executed independently. However, the following order is recommended for full reproducibility.

### Task 2 – API Exploration

```r
source("task2_overview.R")
```

---

### Task 3 – Sampling

Generate AIS samples:

```r
source("02_code/R/task_3/ais_dynamic_sample_points.R")
source("02_code/R/task_3/ais_dynamic_sample_stratified.R")
```

---

### Task 4 – Vessel Behaviour

Generate vessel-path analyses and interactive leaflet maps:

```r
source("02_code/R/task_4/sample_dashboard.R")
source("02_code/R/task_4/ais_dynamic_individual_paths.R")
```

---

### Task 5 – AIS Traffic Density Analysis

Run the traffic density analysis for German rivers:

```r
source("02_code/R/task_5/task5_traffic_density.R")
```

---

### Task 6 – Static Dashboard

Generate the static HTML dashboard:

```r
source("02_code/R/task_6/sample_html_dashboard.R")
```


```text
http://193.197.229.211:7080/sample_points.html
```

---

### Task 7 – Shiny Application

Prepare the data used by the Shiny application:

```r
source("02_code/R/task_7/task7_prepare_shiny_data.R")
```

Shiny application URL:

```text
http://193.197.229.211:7080/ais_app/
```
[![Project Demo](https://img.shields.io/badge/Project-Demo-2c3e50?style=for-the-badge)](#demo) [![Shiny App](https://img.shields.io/badge/Interactive-Shiny%20App-27ae60?style=for-the-badge)](http://193.197.229.211:7080/ais_app/) Static dashboard URL: [![Deployment](https://img.shields.io/badge/Deployment-Live-f39c12?style=for-the-badge)](http://193.197.229.211:7080/)

---

## Docker Deployment

This repository uses **Docker Compose** for deployment.

### Start containers

```bash
docker compose up -d
```

### Rebuild containers

```bash
docker compose up -d --build
```

### Stop containers

```bash
docker compose down
```

---

## Report

The final written report is located in:

```text
03_report/
```

All figures used in the report are additionally stored in:

```text
03_report/graphs/
```

---

## AI Usage Statement

Generative AI tools (e.g., ChatGPT) were used for:

* debugging and troubleshooting,
* code writing,
* code explanations,
* code refactoring,
* documentation improvements,
* language refinement.

All generated outputs were critically reviewed, adapted, tested, and validated by the authors.

---

## Notes

* All scripts were tested before submission.
* Random sampling procedures use fixed seeds for reproducibility where applicable.
* The repository follows the folder structure required by the THAS guidelines.

## Demo

Short demonstration of the deployed dashboard and Shiny application.

<p align="center">
  <img src="00_docs/Assets/shiny_demo.gif" width="850">
</p>