# Food Truck Router

## Requirements
Docker Desktop (Windows/Mac) or Docker Engine + Compose (Linux). ~8 GB RAM free for the one-time map preprocessing, ~10 GB disk.

## Run
    make setup        # first time only (or: ./scripts/setup.sh)
    make up           # every later time
Open http://localhost:8080

## Customize
- Godowns: edit api/godowns.json, then `docker compose restart api`
- Region: change OSM_URL in .env (Geofabrik link), delete osrm-data/*, re-run setup
- Model: change OLLAMA_MODEL in .env
- Scoring weights: `score()` in api/main.py
