# AGENTS.md — THAS 2026 Working Instructions

## Project Context
This repository belongs to the **AIDAHO IDS THAS 2026** take-home assignment (**thas2026**). Always treat this repository as a graded university submission. The primary goal is a correct, reproducible, well-documented, and user-friendly solution that follows the official assignment sheet and the **General Assignment Guidelines**.

## Mandatory Source Priority
When working on this project, always consider the uploaded project documents first, especially:

1. `Assignment_Guidelines.pdf` — highest priority for code quality, report quality, graph quality, upload rules, AI documentation, and grading expectations.
2. `thas2026.pdf` — highest priority for the concrete assignment tasks, repository structure, required scripts, data outputs, dashboards, Shiny app, deadline, and minimum passing requirements.
3. `DockerCompose.pdf`, `SSH Login on Windows.pdf`, and `Docker_Shiny_Deployment_Guide.docx` — use these for deployment, SSH, Docker, Docker Compose, nginx, and Shiny/server setup.

If there is a conflict between general advice and these files, follow the uploaded assignment files.

## Repository and Submission Rules
- Repository name: `AIDAHO_IDS_THAS_2026` or equivalent to the required assignment name.
- Default branch must be `main`; only `main` is relevant for grading.
- Required structure:

```text
AIDAHO_IDS_THAS_2026/
├── 00_docs/
├── 01_data/
├── 02_code/
│   └── R/
├── 03_report/
│   └── graphs/
├── shiny/
├── README.md
└── AGENTS.md
```

- Store the assignment sheet in `00_docs/`.
- Store generated datasets in `01_data/`.
- Store all R scripts in `02_code/R/` unless the assignment explicitly says otherwise.
- Store the final report PDF in `03_report/`.
- Store every graph used in the report separately in `03_report/graphs/`.
- The report must be submitted as `.pdf`; `.docx` is not acceptable.
- The report must include all team members with matriculation numbers and the GitLab repository reference.
- The deployed web service URL must be included in both the report and the README.

## General Working Style
Always work in a way that is:

- **Assignment-driven**: solve exactly what the tasks ask for.
- **Guideline-compliant**: follow the official assignment guidelines before optimizing anything else.
- **Reproducible**: scripts must run again and recreate the reported outputs.
- **User-friendly**: code should be easy for another student or grader to run.
- **Efficient**: avoid expensive or unfiltered API/database calls.
- **Concise but complete**: explanations should be clear enough for a fellow student, not overly long.

## Code Rules
- All code must be syntactically correct and executable.
- Do not provide code that has not been sanity-checked.
- Use meaningful variable and function names.
- Add short, helpful comments where they improve readability.
- Avoid unnecessary repetition; use helper functions where useful.
- Keep function definitions separate if this improves clarity, for example in `02_code/R/functions/`.
- Do not split code into too many tiny files if this reduces usability.
- All required packages must be listed clearly, preferably near the top of each script and in the README.
- If randomness is used, always set a seed and explain why reproducibility matters.
- The only expected user adjustment should be a path or working directory variable.
- The code must generate exactly the figures, tables, and datasets used in the report.

## API and Data Query Rules
- Use the PostgREST endpoint carefully: `https://aidaho-edu.uni-hohenheim.de/aisdb/`.
- Never send unfiltered or weakly filtered requests to large dynamic AIS tables.
- Always restrict `ais_dynamic` queries by at least one of the following:
  - time interval,
  - vessel identifier (`mmsi`),
  - aggregation,
  - selected columns,
  - limit.
- Prefer database-side filtering and aggregation over downloading large datasets into R.
- Use `select`, filters, `limit`, and PostgREST aggregations where possible.
- Document query logic in the report, not only final numbers.
- Respect server limits and avoid queries likely to overload the shared infrastructure.

## Report Rules
- Write the report in English.
- Write it like a short paper, not like a task-by-task code diary.
- Assume the reader is an interested fellow student.
- Keep the main report concise and within the official page limit.
- Use a consistent layout and a professional serif font.
- Include a title page with names, study program, and student IDs.
- Cite all external sources properly.
- Include a short AI-use statement at the end of the report, maximum five lines.
- Interpret results, do not only describe code output.
- Use only necessary decimal places; usually four decimal places are enough.

## Graph and Table Rules
- Every graph and table must be numbered and named.
- Every graph and table must have a meaningful caption and short description.
- Graphs must be readable when printed on A4.
- Legends must not hide important data.
- Axis labels must be clear and not overlap.
- Resolution must be high enough for the PDF.
- Every graph shown in the report must also be saved separately in `03_report/graphs/`.
- Use clear visual encodings and explain how colours or scales should be interpreted.

## Docker, nginx, and Shiny Rules
- Use the provided Docker/nginx/Shiny documents as the reference for deployment.
- Test Docker Compose locally before deploying to the server.
- Use `docker compose up -d` or the command supported by the server setup.
- Use `docker compose down` to stop and clean up containers when needed.
- Configure nginx as a reverse proxy for the Shiny app.
- Static dashboard target: `/sample_points.html`.
- Shiny app target: `/ais_app`.
- The web service must be accessible during grading.
- Include screenshots or links in the report showing that the deployed dashboard/app works.

## THAS 2026 Task Awareness
Always keep the task structure in mind:

- **Task 1**: Git repository, folder structure, assignment sheet, report and graph locations.
- **Task 2**: AIS/PostgREST overview, resources, summary statistics, filtered queries.
- **Task 3**: interval sample and stratified sample, saved CSV files, sampling discussion, comparison plots.
- **Task 4**: leaflet sample dashboard and individual vessel paths, data quality, lock detection, visualisation.
- **Task 5**: German river traffic density using rnaturalearth and H3.
- **Task 6**: static HTML dashboard served through Docker/nginx.
- **Task 7**: Shiny app deployed through Docker/nginx under `/ais_app`.

## Minimum Passing Requirements
Before final submission, verify that the repository contains at least:

- final written report as `.pdf`,
- required GitLab repository structure,
- executable R scripts for at least two of the three major analytical 20-point tasks,
- at least one generated sample dataset,
- evidence that the static dashboard or Shiny component was attempted,
- README with repository structure, run instructions, and web app URL,
- AI-use documentation in the report.

## ChatGPT Behaviour for This Repository
When ChatGPT assists with this project, it should:

1. First check the assignment files and guidelines when relevant.
2. Prefer solutions that maximize grading compliance over elegant but risky alternatives.
3. Give copy-paste-ready code when asked for code.
4. Explain commands step by step when dealing with Git, SSH, Docker, nginx, or deployment.
5. Warn when a query could overload the AIS database.
6. Keep wording suitable for a university submission in English.
7. Avoid inventing results. If values are unknown, provide code to compute them.
8. Make clear what still needs to be verified locally or on the server.
9. Keep README, report text, comments, captions, and AI-use statements aligned with the official guidelines.
10. Never ignore the uploaded files, especially `Assignment_Guidelines.pdf`.
