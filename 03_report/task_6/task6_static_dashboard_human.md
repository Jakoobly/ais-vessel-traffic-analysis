# Task 6 Static HTML Dashboard

- Created at: 2026-06-04 16:45:46.940073
- Source file: `01_data/task_3/sample_intervals.csv`
- Number of valid AIS observations shown: 9361

## Implementation notes

- The Task 4.1 leaflet logic was reused to create a static AIS sample dashboard.
- Vessel speed is shown with the same capped colour scale as in Task 4.1.
- Marker clustering is used so that the map remains responsive in the browser.
- The self-contained HTML file is written to `assets/site-content/sample_points.html`.
- This folder is mounted into the NGINX document root by `docker-compose.yaml`, so the dashboard is served at `/sample_points.html`.

## Output files

- `assets/site-content/sample_points.html`
- `03_report/task_6/sample_points.html`
- `03_report/graphs/sample_points.html`
- `03_report/task_6/task6_static_dashboard_ai.json`
- `03_report/task_6/task6_static_dashboard_human.md`

## Expected URLs

- Local Docker test: `http://localhost/sample_points.html`
- Server deployment: `https://<your-server>/sample_points.html`

## Docker test commands

```bash
docker compose up -d
docker compose ps
docker compose logs nginx --tail=50
docker compose down
```
