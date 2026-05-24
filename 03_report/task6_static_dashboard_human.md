# Task 6 Static HTML Dashboard

Source file: `01_data/sample_intervals.csv`
Number of valid AIS observations shown: 9331

The Task 4.1 leaflet logic was reused to create a static AIS sample dashboard. Vessel speed is shown with the same capped colour scale as in Task 4.1, and marker clustering is used to keep the map responsive.

The self-contained HTML file is written to `assets/site-content/sample_points.html`. This folder is mounted into the NGINX document root by `docker-compose.yaml`, so the dashboard is served at `/sample_points.html`.

Expected deployed URL: `https://<your-server>/sample_points.html`

Docker test commands:

```bash
docker compose up -d
docker compose ps
docker compose logs nginx
docker compose down
```
