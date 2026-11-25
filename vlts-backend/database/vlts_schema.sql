-- =====================================================================
-- VLTS Route Intelligence: SQLite schema (Draft v1)
-- Creates all tables, empty. Safe to run more than once (IF NOT EXISTS).
--
-- How to run:
--   sqlite3 vlts.db < vlts_schema.sql
--   (or open vlts.db in DB Browser for SQLite and run this script)
--
-- Conventions
--   * Timestamps: ISO 8601 UTC text, e.g. 2026-11-25T09:30:00Z
--   * Booleans: 0 / 1
--   * Geometry: GeoJSON text ([longitude, latitude] order)
--   * JSON fields: text; the backend validates them
--   * updated_at is set by the backend on every update
-- =====================================================================

PRAGMA foreign_keys = ON;      -- must be set on every new connection
PRAGMA journal_mode = WAL;     -- persistent; lets reads and writes overlap


-- =====================================================================
-- 1. USERS, AUTHENTICATION, AUTHORIZATION
-- =====================================================================

CREATE TABLE IF NOT EXISTS roles (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL UNIQUE,
    description  TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 2. GODOWNS, TRANSPORTERS (needed by users, so created first)
-- =====================================================================

CREATE TABLE IF NOT EXISTS godowns (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    code                  TEXT NOT NULL UNIQUE,
    name                  TEXT NOT NULL,
    type                  TEXT NOT NULL CHECK (type IN ('FCI','GSCSCL')),
    status                TEXT NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active','inactive')),
    address               TEXT,
    taluka                TEXT,
    district              TEXT,
    state                 TEXT,
    pincode               TEXT,
    latitude              REAL CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    longitude             REAL CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    geofence_geojson      TEXT,
    geofence_radius_m     REAL,
    storage_capacity_mt   REAL,
    loading_bays          INTEGER,
    commodities           TEXT,
    opening_time          TEXT,
    closing_time          TEXT,
    weekly_off            TEXT,
    avg_loading_time_min  REAL,
    manager_name          TEXT,
    manager_phone         TEXT,
    manager_email         TEXT,
    nearest_highway       TEXT,
    truck_restrictions    TEXT,
    notes                 TEXT,
    is_deleted            INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS transporters (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT NOT NULL,
    contact_phone  TEXT,
    contact_email  TEXT,
    status         TEXT NOT NULL DEFAULT 'active'
                       CHECK (status IN ('active','inactive')),
    is_deleted     INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 1 (cont). USERS AND SECURITY TABLES
-- =====================================================================

CREATE TABLE IF NOT EXISTS users (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    name             TEXT NOT NULL,
    email            TEXT NOT NULL UNIQUE,
    phone            TEXT,
    password_hash    TEXT NOT NULL,
    role_id          INTEGER NOT NULL REFERENCES roles(id),
    godown_id        INTEGER REFERENCES godowns(id),
    transporter_id   INTEGER REFERENCES transporters(id),
    is_active        INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    last_login       TEXT,
    is_deleted       INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL,
    expires_at  TEXT NOT NULL,
    revoked     INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0,1)),
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,
    entity      TEXT,
    entity_id   INTEGER,
    timestamp   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    ip          TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 3. ORIGIN-DESTINATION PAIRS
-- =====================================================================

CREATE TABLE IF NOT EXISTS od_pairs (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    origin_godown_id       INTEGER NOT NULL REFERENCES godowns(id),
    destination_godown_id  INTEGER NOT NULL REFERENCES godowns(id),
    standard_distance_km   REAL,
    is_active              INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    is_deleted             INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    CHECK (origin_godown_id <> destination_godown_id),
    UNIQUE (origin_godown_id, destination_godown_id)
);


-- =====================================================================
-- 4. VEHICLES AND TRIPS (RAW DATA)
-- =====================================================================

CREATE TABLE IF NOT EXISTS vehicles (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    registration_no  TEXT NOT NULL UNIQUE,
    transporter_id   INTEGER REFERENCES transporters(id),
    vehicle_type     TEXT,
    capacity_tonnes  REAL,
    axles            INTEGER,
    gps_device_id    TEXT,
    is_deleted       INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS trips (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id             INTEGER NOT NULL REFERENCES vehicles(id),
    origin_godown_id       INTEGER NOT NULL REFERENCES godowns(id),
    destination_godown_id  INTEGER NOT NULL REFERENCES godowns(id),
    od_pair_id             INTEGER REFERENCES od_pairs(id),
    start_time             TEXT,
    end_time               TEXT,
    status                 TEXT NOT NULL DEFAULT 'ongoing'
                               CHECK (status IN ('ongoing','completed','cancelled')),
    commodity              TEXT CHECK (commodity IS NULL OR commodity IN ('rice','wheat')),
    load_tonnes            REAL,
    verified_weight        REAL,
    epod_time              TEXT,
    data_source            TEXT NOT NULL DEFAULT 'real'
                               CHECK (data_source IN ('real','synthetic')),
    is_deleted             INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at             TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS gps_points (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id     INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    timestamp   TEXT NOT NULL,
    lat         REAL NOT NULL CHECK (lat BETWEEN -90  AND 90),
    lon         REAL NOT NULL CHECK (lon BETWEEN -180 AND 180),
    speed       REAL,
    heading     REAL,
    is_outlier  INTEGER NOT NULL DEFAULT 0 CHECK (is_outlier IN (0,1)),
    is_stopped  INTEGER NOT NULL DEFAULT 0 CHECK (is_stopped IN (0,1)),
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS trip_stops (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id       INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    start_time    TEXT,
    end_time      TEXT,
    duration_min  REAL,
    lat           REAL CHECK (lat IS NULL OR lat BETWEEN -90  AND 90),
    lon           REAL CHECK (lon IS NULL OR lon BETWEEN -180 AND 180),
    stop_type     TEXT NOT NULL DEFAULT 'unknown'
                      CHECK (stop_type IN ('rest','loading','breakdown','unknown')),
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS geofence_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id     INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    godown_id   INTEGER NOT NULL REFERENCES godowns(id),
    event       TEXT NOT NULL
                    CHECK (event IN ('enter','exit','trip_start','trip_end')),
    timestamp   TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 5. MODEL TRACKING (created before routes / recommendations)
-- =====================================================================

CREATE TABLE IF NOT EXISTS model_runs (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    version        TEXT NOT NULL,
    trained_at     TEXT,
    data_from      TEXT,
    data_to        TEXT,
    train_count    INTEGER,
    metrics_json   TEXT,
    status         TEXT NOT NULL DEFAULT 'running'
                       CHECK (status IN ('running','success','failed')),
    artifact_path  TEXT,
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 6. ROUTE DATA (DERIVED)
-- =====================================================================

CREATE TABLE IF NOT EXISTS routes (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    od_pair_id        INTEGER NOT NULL REFERENCES od_pairs(id),
    name              TEXT,
    type              TEXT NOT NULL DEFAULT 'historical'
                          CHECK (type IN ('historical','recommended','alternative')),
    geometry_geojson  TEXT,
    distance_km       REAL,
    is_preferred      INTEGER NOT NULL DEFAULT 0 CHECK (is_preferred IN (0,1)),
    version           INTEGER NOT NULL DEFAULT 1,
    source_run_id     INTEGER REFERENCES model_runs(id),
    is_deleted        INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS route_stats (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id           INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    period_start       TEXT,
    period_end         TEXT,
    trip_count         INTEGER,
    avg_speed          REAL,
    avg_duration_min   REAL,
    std_duration_min   REAL,
    avg_distance_km    REAL,
    avg_stops          REAL,
    stops_per_day      REAL,
    avg_delay_min      REAL,
    avg_deviation_pct  REAL,
    efficiency         REAL,
    reliability_score  REAL CHECK (reliability_score IS NULL OR reliability_score BETWEEN 0 AND 1),
    created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS route_segments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id    INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    sequence    INTEGER NOT NULL,
    road_name   TEXT,
    road_type   TEXT CHECK (road_type IS NULL OR road_type IN ('NH','SH','district','village')),
    surface     TEXT,
    condition   TEXT CHECK (condition IS NULL OR condition IN ('good','fair','poor')),
    lanes       INTEGER,
    length_km   REAL,
    toll_flag   INTEGER NOT NULL DEFAULT 0 CHECK (toll_flag IN (0,1)),
    risk_score  REAL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (route_id, sequence)
);

CREATE TABLE IF NOT EXISTS route_weather_stats (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id           INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    weather_condition  TEXT NOT NULL
                           CHECK (weather_condition IN ('clear','rain','fog','heat')),
    trip_count         INTEGER,
    avg_speed          REAL,
    avg_duration_min   REAL,
    avg_delay_min      REAL,
    avg_stops          REAL,
    summary_text       TEXT,
    created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS route_time_stats (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id          INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    hour_of_day       INTEGER NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
    day_of_week       INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    avg_speed         REAL,
    avg_duration_min  REAL,
    traffic_index     REAL,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS tolls (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    name                  TEXT NOT NULL,
    latitude              REAL CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    longitude             REAL CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    cost_by_vehicle_type  TEXT,   -- JSON text, e.g. {"10-wheeler": 350}
    created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS route_tolls (
    route_id    INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    toll_id     INTEGER NOT NULL REFERENCES tolls(id)  ON DELETE CASCADE,
    sequence    INTEGER,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (route_id, toll_id)
);

CREATE TABLE IF NOT EXISTS route_reports (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    route_id       INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    report_text    TEXT NOT NULL,
    model_name     TEXT,
    generated_at   TEXT,
    source_run_id  INTEGER REFERENCES model_runs(id),
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 7. RECOMMENDATIONS, ANALYSIS, METRICS, WEATHER
-- =====================================================================

CREATE TABLE IF NOT EXISTS recommendations (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    od_pair_id              INTEGER NOT NULL REFERENCES od_pairs(id),
    requested_by            INTEGER REFERENCES users(id) ON DELETE SET NULL,
    requested_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    vehicle_type            TEXT,
    recommended_route_id    INTEGER REFERENCES routes(id),
    predicted_distance_km   REAL,
    predicted_duration_min  REAL,
    alternatives_json       TEXT,   -- JSON text: other candidates with scores
    explanation_text        TEXT,
    latency_ms              INTEGER,
    model_run_id            INTEGER REFERENCES model_runs(id),
    created_at              TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at              TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS trip_analysis (
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id                  INTEGER NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    recommendation_id        INTEGER REFERENCES recommendations(id),
    actual_distance_km       REAL,
    recommended_distance_km  REAL,
    actual_duration_min      REAL,
    extra_km                 REAL,
    extra_time_min           REAL,
    overlap_pct              REAL,
    deviation_pct            REAL,
    efficiency               REAL,
    anomaly_flag             INTEGER NOT NULL DEFAULT 0 CHECK (anomaly_flag IN (0,1)),
    anomaly_reason           TEXT,
    deviation_reason         TEXT,
    created_at               TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at               TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS deviation_segments (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_analysis_id  INTEGER NOT NULL REFERENCES trip_analysis(id) ON DELETE CASCADE,
    geometry_geojson  TEXT,
    length_km         REAL,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS performance_metrics (
    id                            INTEGER PRIMARY KEY AUTOINCREMENT,
    period_start                  TEXT,
    period_end                    TEXT,
    od_pair_id                    INTEGER REFERENCES od_pairs(id),   -- NULL = overall
    baseline_avg_distance_km      REAL,
    recommended_avg_distance_km   REAL,
    baseline_avg_duration_min     REAL,
    recommended_avg_duration_min  REAL,
    deviation_reduction_pct       REAL,
    efficiency_gain_pct           REAL,
    accuracy                      REAL,
    avg_latency_ms                REAL,
    model_run_id                  INTEGER REFERENCES model_runs(id),
    created_at                    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at                    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS weather_observations (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp      TEXT NOT NULL,
    lat            REAL CHECK (lat IS NULL OR lat BETWEEN -90  AND 90),
    lon            REAL CHECK (lon IS NULL OR lon BETWEEN -180 AND 180),
    condition      TEXT CHECK (condition IS NULL OR condition IN ('clear','rain','fog','heat')),
    rainfall_mm    REAL,
    temperature_c  REAL,
    visibility_m   REAL,
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);


-- =====================================================================
-- 8. INDEXES (speed up the queries the dashboard will run most)
-- =====================================================================

-- GPS points: the biggest table, always read per trip in time order
CREATE INDEX IF NOT EXISTS idx_gps_points_trip_time ON gps_points (trip_id, timestamp);

-- Trips
CREATE INDEX IF NOT EXISTS idx_trips_od_start        ON trips (od_pair_id, start_time);
CREATE INDEX IF NOT EXISTS idx_trips_vehicle         ON trips (vehicle_id);
CREATE INDEX IF NOT EXISTS idx_trips_origin_dest     ON trips (origin_godown_id, destination_godown_id);
CREATE INDEX IF NOT EXISTS idx_trips_status          ON trips (status);
CREATE INDEX IF NOT EXISTS idx_trip_stops_trip       ON trip_stops (trip_id);
CREATE INDEX IF NOT EXISTS idx_geofence_events_trip  ON geofence_events (trip_id);

-- Users and security
CREATE INDEX IF NOT EXISTS idx_users_role            ON users (role_id);
CREATE INDEX IF NOT EXISTS idx_users_godown          ON users (godown_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user   ON refresh_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_time   ON audit_log (user_id, timestamp);

-- Vehicles
CREATE INDEX IF NOT EXISTS idx_vehicles_transporter  ON vehicles (transporter_id);

-- Routes and route statistics
CREATE INDEX IF NOT EXISTS idx_routes_od             ON routes (od_pair_id);
CREATE INDEX IF NOT EXISTS idx_route_stats_route     ON route_stats (route_id);
CREATE INDEX IF NOT EXISTS idx_route_segments_route  ON route_segments (route_id, sequence);
CREATE INDEX IF NOT EXISTS idx_route_weather_route   ON route_weather_stats (route_id);
CREATE INDEX IF NOT EXISTS idx_route_time_route      ON route_time_stats (route_id, day_of_week, hour_of_day);
CREATE INDEX IF NOT EXISTS idx_route_reports_route   ON route_reports (route_id);

-- Recommendations and analysis
CREATE INDEX IF NOT EXISTS idx_recommendations_od    ON recommendations (od_pair_id, requested_at);
CREATE INDEX IF NOT EXISTS idx_trip_analysis_trip    ON trip_analysis (trip_id);
CREATE INDEX IF NOT EXISTS idx_deviation_segments_ta ON deviation_segments (trip_analysis_id);
CREATE INDEX IF NOT EXISTS idx_perf_metrics_od       ON performance_metrics (od_pair_id, period_start);
CREATE INDEX IF NOT EXISTS idx_weather_obs_time      ON weather_observations (timestamp);


-- =====================================================================
-- OPTIONAL: default roles (left commented out so every table stays empty)
-- Remove the comment markers to insert the six roles from the schema doc.
-- =====================================================================
-- INSERT OR IGNORE INTO roles (name, description) VALUES
--   ('Admin',              'Manage users, godowns, settings and model retraining'),
--   ('Official',           'View all routes, recommendations, analytics and reports'),
--   ('Monitoring Officer', 'View trip analysis, deviations and trip monitoring'),
--   ('Godown Manager',     'View only trips and godowns linked to their own godown'),
--   ('FCI Personnel',      'Read-only, limited to their own godowns'),
--   ('Transporter',        'View only their own vehicles and trips');
