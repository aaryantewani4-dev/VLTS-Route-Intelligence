PRAGMA foreign_keys = OFF;

-- ========================================================
-- 1. ROLES
-- ========================================================
INSERT OR IGNORE INTO roles (id, name, description) VALUES
(1, 'Admin', 'Manage users, godowns, settings and full access'),
(2, 'Official / Planner', 'All routes, recommendations, analytics and reports'),
(3, 'Monitoring Officer', 'Trip analysis, deviations and trip monitoring'),
(4, 'Godown Manager', 'Only trips and godowns linked to their own godown'),
(5, 'FCI Personnel', 'Read-only, limited to FCI godowns'),
(6, 'Transporter', 'Only their own vehicles and trips');

-- ========================================================
-- 2. USERS
-- ========================================================
INSERT OR IGNORE INTO users (id, name, email, phone, password_hash, role_id, is_active, last_login, created_at, updated_at) VALUES
(1, 'Rajesh Patel', 'officer@gscscl.gov.in', '9825012345', '$2b$12$e8YQjGZ5K7QY0Yw1M2N3O4P5Q6R7S8T9U0V1W2X3Y4Z5A6B7C8D9E', 2, 1, '2026-11-25T08:00:00Z', '2026-11-20T00:00:00Z', '2026-11-25T08:00:00Z'),
(2, 'Pooja Shah', 'admin@gscscl.gov.in', '9825067890', '$2b$12$e8YQjGZ5K7QY0Yw1M2N3O4P5Q6R7S8T9U0V1W2X3Y4Z5A6B7C8D9E', 1, 1, '2026-11-25T09:00:00Z', '2026-11-20T00:00:00Z', '2026-11-25T09:00:00Z');

-- ========================================================
-- 3. GODOWNS (FCI Origins & GSCSCL Destinations)
-- ========================================================
INSERT OR IGNORE INTO godowns (
    id, code, name, type, status, address, taluka, district, state, pincode,
    latitude, longitude, storage_capacity_mt, loading_bays, commodities,
    opening_time, closing_time, manager_name, manager_phone
) VALUES
(1, 'FCI-SAB-01', 'FCI Sabarmati Railhead Depot', 'FCI', 'active', 'Near Railway Yard, Sabarmati', 'Sabarmati', 'Ahmedabad', 'Gujarat', '380005', 23.0827, 72.5831, 35000, 8, 'Wheat, Rice', '08:00', '20:00', 'V. K. Sharma', '9879011111'),
(2, 'FCI-GDM-02', 'FCI Gandhidham Silo Depot', 'FCI', 'active', 'Port Area, Gandhidham', 'Gandhidham', 'Kutch', 'Gujarat', '370201', 23.0753, 70.1337, 50000, 12, 'Wheat', '08:00', '20:00', 'A. K. Mehta', '9879022222'),
(3, 'GSC-RAJ-01', 'GSCSCL Rajkot District Godown', 'GSCSCL', 'active', 'Aji GIDC Phase II', 'Rajkot', 'Rajkot', 'Gujarat', '360003', 22.3039, 70.8022, 10000, 4, 'Wheat, Rice, Sugar', '09:00', '18:00', 'Hiren Joshi', '9879033333'),
(4, 'GSC-SUR-02', 'GSCSCL Surat Central Godown', 'GSCSCL', 'active', 'Udhna Main Road, Surat', 'Udhna', 'Surat', 'Gujarat', '394210', 21.1702, 72.8311, 12000, 6, 'Rice, Wheat', '09:00', '18:00', 'Manish Dave', '9879044444'),
(5, 'GSC-VAD-03', 'GSCSCL Vadodara Taluka Godown', 'GSCSCL', 'active', 'Makarpura GIDC', 'Vadodara', 'Vadodara', 'Gujarat', '390010', 22.3072, 73.1812, 8000, 4, 'Wheat, Rice', '09:00', '18:00', 'C. M. Rathod', '9879055555'),
(6, 'GSC-MEH-04', 'GSCSCL Mehsana District Godown', 'GSCSCL', 'active', 'State Highway, Nagalpur', 'Mehsana', 'Mehsana', 'Gujarat', '384002', 23.5880, 72.3693, 7500, 3, 'Wheat, Rice', '09:00', '18:00', 'P. R. Solanki', '9879066666');

-- ========================================================
-- 4. ORIGIN-DESTINATION (O-D) PAIRS
-- ========================================================
INSERT OR IGNORE INTO od_pairs (id, origin_godown_id, destination_godown_id, standard_distance_km, is_active) VALUES
(1, 1, 3, 218.0, 1),
(2, 1, 4, 265.0, 1),
(3, 1, 5, 115.0, 1),
(4, 2, 3, 195.0, 1);

-- ========================================================
-- 5. TRANSPORTERS & VEHICLES
-- ========================================================
INSERT OR IGNORE INTO transporters (id, name, contact_phone, contact_email, status) VALUES
(1, 'Gujarat State Logistics Fleet', '9825100001', 'dispatch@gslogistics.in', 'active'),
(2, 'Western Agro Carriers', '9825100002', 'westernagro@gmail.com', 'active');

INSERT OR IGNORE INTO vehicles (id, registration_no, transporter_id, vehicle_type, capacity_tonnes, axles, gps_device_id) VALUES
(1, 'GJ-01-AB-1234', 1, '10-wheeler', 16.0, 3, 'AIS140-DEV-8801'),
(2, 'GJ-05-CD-5678', 1, '12-wheeler', 21.0, 4, 'AIS140-DEV-8802'),
(3, 'GJ-03-EF-9012', 2, '10-wheeler', 15.0, 3, 'AIS140-DEV-8803');

-- ========================================================
-- 6. MODEL RUNS
-- ========================================================
INSERT OR IGNORE INTO model_runs (id, version, trained_at, data_from, data_to, train_count, status) VALUES
(1, 'v1.0.0-osrm-xgb', '2026-11-20T12:00:00Z', '2026-01-01', '2026-11-15', 1250, 'success');

-- ========================================================
-- 7. ROUTES
-- ========================================================
INSERT OR IGNORE INTO routes (id, od_pair_id, name, type, geometry_geojson, distance_km, is_preferred, version, source_run_id) VALUES
(1, 1, 'Primary NH47 Highway Corridor', 'recommended',
'{"type":"LineString","coordinates":[[72.5831,23.0827],[72.3621,22.9512],[71.8105,22.5641],[71.2982,22.4215],[70.8022,22.3039]]}',
218.4, 1, 1, 1),
(2, 2, 'NE1 Expressway & NH48 Corridor', 'recommended',
'{"type":"LineString","coordinates":[[72.5831,23.0827],[72.7500,22.7500],[73.1812,22.3072],[72.9900,21.7000],[72.8311,21.1702]]}',
265.2, 1, 1, 1);

-- ========================================================
-- 8. TRIPS
-- ========================================================
INSERT OR IGNORE INTO trips (
    id, vehicle_id, origin_godown_id, destination_godown_id, od_pair_id,
    start_time, end_time, status, commodity, load_tonnes, verified_weight, data_source
) VALUES
(1, 1, 1, 3, 1, '2026-11-25T06:00:00Z', '2026-11-25T10:45:00Z', 'completed', 'Wheat', 15.5, 15.48, 'synthetic'),
(2, 2, 1, 4, 2, '2026-11-25T07:15:00Z', NULL, 'ongoing', 'Rice', 20.0, NULL, 'synthetic');

-- ========================================================
-- 9. RECOMMENDATIONS
-- ========================================================
INSERT OR IGNORE INTO recommendations (
    id, od_pair_id, requested_by, requested_at, vehicle_type, recommended_route_id,
    predicted_distance_km, predicted_duration_min, explanation_text, latency_ms, model_run_id
) VALUES
(1, 1, 1, '2026-11-25T05:50:00Z', '10-wheeler', 1, 218.4, 285.0, 'Optimal route via NH47 avoiding Bagodara bottleneck.', 62, 1),
(2, 2, 1, '2026-11-25T07:00:00Z', '12-wheeler', 2, 265.2, 330.0, 'Fastest freight corridor via NE1 and NH48.', 74, 1);

-- ========================================================
-- 10. TRIP ANALYSIS (Actual vs Recommended Comparison)
-- ========================================================
INSERT OR IGNORE INTO trip_analysis (
    id, trip_id, recommendation_id, actual_distance_km, recommended_distance_km,
    actual_duration_min, extra_km, extra_time_min, overlap_pct, deviation_pct,
    efficiency, anomaly_flag, anomaly_reason
) VALUES
(1, 1, 1, 222.0, 218.4, 285.0, 3.6, 10.0, 98.2, 1.8, 0.98, 0, NULL),
(2, 2, 2, 290.0, 265.2, 410.0, 24.8, 80.0, 78.5, 21.5, 0.79, 1, 'Vehicle deviated from NH48 corridor into unapproved bypass near Bharuch');

-- ========================================================
-- 11. DEVIATION SEGMENTS (GeoJSON detour line)
-- ========================================================
INSERT OR IGNORE INTO deviation_segments (id, trip_analysis_id, geometry_geojson, length_km) VALUES
(1, 2, '{"type":"LineString","coordinates":[[73.1812,22.3072],[73.1200,21.7500],[73.2800,21.6800],[73.1500,21.5500],[72.9900,21.7000]]}', 24.8);

-- ========================================================
-- 12. PERFORMANCE METRICS (Expected Outcome 8 - KPIs)
-- ========================================================
INSERT OR IGNORE INTO performance_metrics (
    id, period_start, period_end, od_pair_id, baseline_avg_distance_km,
    recommended_avg_distance_km, baseline_avg_duration_min, recommended_avg_duration_min,
    deviation_reduction_pct, efficiency_gain_pct, accuracy, avg_latency_ms, model_run_id
) VALUES
(1, '2026-11-01', '2026-11-25', NULL, 248.5, 228.1, 340.0, 295.0, 32.4, 14.8, 0.94, 68.0, 1);