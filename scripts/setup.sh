#!/usr/bin/env bash
# One-time setup: download map, preprocess for OSRM, pull the Ollama model.
set -euo pipefail
cd "$(dirname "$0")/.."
source .env

mkdir -p osrm-data
if [ ! -f osrm-data/map.osm.pbf ]; then
  echo ">> Downloading map data..."
  curl -L --fail -o osrm-data/map.osm.pbf "$OSM_URL"
fi

IMG=ghcr.io/project-osrm/osrm-backend:latest
if [ ! -f osrm-data/map.osrm.mldgr ]; then
  echo ">> Preprocessing (needs ~8 GB RAM, takes 10-30 min)..."
  docker run --rm -v "$PWD/osrm-data:/data" $IMG osrm-extract -p /opt/car.lua /data/map.osm.pbf
  docker run --rm -v "$PWD/osrm-data:/data" $IMG osrm-partition /data/map.osrm
  docker run --rm -v "$PWD/osrm-data:/data" $IMG osrm-customize /data/map.osrm
fi

echo ">> Starting services and pulling Ollama model..."
docker compose up -d --build
docker compose exec ollama ollama pull "$OLLAMA_MODEL"
echo ">> Done. Open http://localhost:8080"
