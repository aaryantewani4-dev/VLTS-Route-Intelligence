import json, os
from collections import defaultdict
from pathlib import Path

import httpx
from fastapi import FastAPI, HTTPException

OSRM = os.getenv("OSRM_URL", "http://osrm:5000")
OLLAMA = os.getenv("OLLAMA_URL", "http://ollama:11434")
MODEL = os.getenv("OLLAMA_MODEL", "llama3.2:3b")

GODOWNS = {g["id"]: g for g in json.loads((Path(__file__).parent / "godowns.json").read_text())}
CACHE: dict = {}

app = FastAPI(title="Food Truck Router")


@app.get("/api/godowns")
def godowns():
    return list(GODOWNS.values())


def top_roads(steps, n=3):
    d = defaultdict(float)
    for s in steps:
        if s.get("name"):
            d[s["name"]] += s["distance"]
    return [k for k, _ in sorted(d.items(), key=lambda x: -x[1])[:n]]


def score(minutes, km):
    # lower is better; tune weights as you learn from real trips
    return round(minutes + 0.05 * km, 2)


async def make_brief(routes, a, b):
    facts = [
        {"name": r["label"], "minutes": r["minutes"], "km": r["km"], "main_roads": r["main_roads"]}
        for r in routes
    ]
    prompt = (
        f"Write a 3-sentence dispatch brief for a food truck driver going from {a} to {b}. "
        "Use ONLY the numbers and roads in this JSON. Recommend the first route, "
        f"and say how it differs from the others.\n{json.dumps(facts)}"
    )
    try:
        async with httpx.AsyncClient(timeout=60) as c:
            r = await c.post(f"{OLLAMA}/api/generate", json={
                "model": MODEL, "prompt": prompt, "stream": False,
                "options": {"temperature": 0.2},
            })
            return r.json().get("response", "").strip()
    except Exception:
        return None  # dashboard still works without the AI brief


@app.get("/api/route")
async def route(from_id: str, to_id: str, brief: bool = True):
    if from_id not in GODOWNS or to_id not in GODOWNS or from_id == to_id:
        raise HTTPException(400, "Invalid godown ids")
    key = (from_id, to_id)
    if key in CACHE and (CACHE[key]["brief"] or not brief):
        return CACHE[key]

    a, b = GODOWNS[from_id], GODOWNS[to_id]
    url = f"{OSRM}/route/v1/driving/{a['lon']},{a['lat']};{b['lon']},{b['lat']}"
    params = {"alternatives": "3", "overview": "full", "geometries": "geojson", "steps": "true"}
    try:
        async with httpx.AsyncClient(timeout=30) as c:
            data = (await c.get(url, params=params)).json()
    except Exception:
        raise HTTPException(503, "Routing engine not reachable")
    if data.get("code") != "Ok":
        raise HTTPException(404, f"No route: {data.get('code')}")

    routes = []
    for r in data["routes"]:
        minutes, km = round(r["duration"] / 60, 1), round(r["distance"] / 1000, 1)
        routes.append({
            "minutes": minutes, "km": km, "score": score(minutes, km),
            "main_roads": top_roads(s for l in r["legs"] for s in l["steps"]),
            "geometry": r["geometry"],
        })
    routes.sort(key=lambda x: x["score"])
    for i, r in enumerate(routes):
        r["label"] = f"Route {chr(65 + i)}"
        r["best"] = i == 0

    result = {"from": a["name"], "to": b["name"], "routes": routes,
              "brief": await make_brief(routes, a["name"], b["name"]) if brief else None}
    CACHE[key] = result
    return result
