
import sqlite3
import json
from pathlib import Path


# -------------------------------------------------
# DATABASE PATH
# -------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent
DATABASE_PATH = BASE_DIR / "vlts.db"


# -------------------------------------------------
# QUERIES TO DISPLAY INSERTED DATA
# -------------------------------------------------

TABLE_QUERIES = {
    "roles": """
        SELECT id, name, description
        FROM roles
        ORDER BY id
    """,

    "users": """
        SELECT id, name, email, phone, role_id,
               is_active, godown_id, transporter_id
        FROM users
        ORDER BY id
    """,

    "godowns": """
        SELECT id, code, name, type, status,
               district, latitude, longitude
        FROM godowns
        ORDER BY id
    """,

    "od_pairs": """
        SELECT id, origin_godown_id, destination_godown_id,
               standard_distance_km, is_active
        FROM od_pairs
        ORDER BY id
    """,

    "transporters": """
        SELECT id, name, contact_phone, contact_email, status
        FROM transporters
        ORDER BY id
    """,

    "vehicles": """
        SELECT id, registration_no, transporter_id,
               vehicle_type, capacity_tonnes, axles, gps_device_id
        FROM vehicles
        ORDER BY id
    """,

    "model_runs": """
        SELECT id, version, trained_at, data_from,
               data_to, train_count, status
        FROM model_runs
        ORDER BY id
    """,

    "routes": """
        SELECT id, od_pair_id, name, type, distance_km,
               is_preferred, source_run_id
        FROM routes
        ORDER BY id
    """,

    "trips": """
        SELECT id, vehicle_id, origin_godown_id,
               destination_godown_id, od_pair_id,
               start_time, end_time, status, commodity,
               load_tonnes, verified_weight, data_source
        FROM trips
        ORDER BY id
    """,

    "recommendations": """
        SELECT id, od_pair_id, requested_by, requested_at,
               vehicle_type, recommended_route_id,
               predicted_distance_km, predicted_duration_min,
               explanation_text, latency_ms, model_run_id
        FROM recommendations
        ORDER BY id
    """,

    "trip_analysis": """
        SELECT id, trip_id, recommendation_id,
               actual_distance_km, recommended_distance_km,
               actual_duration_min, extra_km, extra_time_min,
               overlap_pct, deviation_pct, efficiency,
               anomaly_flag, anomaly_reason
        FROM trip_analysis
        ORDER BY id
    """,

    "deviation_segments": """
        SELECT id, trip_analysis_id, geometry_geojson, length_km
        FROM deviation_segments
        ORDER BY id
    """,

    "performance_metrics": """
        SELECT id, period_start, period_end, od_pair_id,
               baseline_avg_distance_km,
               recommended_avg_distance_km,
               baseline_avg_duration_min,
               recommended_avg_duration_min,
               deviation_reduction_pct,
               efficiency_gain_pct, accuracy,
               avg_latency_ms, model_run_id
        FROM performance_metrics
        ORDER BY id
    """
}


# -------------------------------------------------
# VERIFY DATABASE
# -------------------------------------------------

def verify_database():

    if not DATABASE_PATH.exists():
        print("ERROR: Database file not found!")
        print(f"Expected location: {DATABASE_PATH}")
        return

    conn = None

    try:
        conn = sqlite3.connect(DATABASE_PATH)
        conn.row_factory = sqlite3.Row

        # Enable foreign key checking
        conn.execute("PRAGMA foreign_keys = ON")

        print("=" * 60)
        print("       VLTS ROUTE INTELLIGENCE DATABASE VERIFICATION")
        print("=" * 60)

        # -------------------------------------------------
        # 1. DATABASE INTEGRITY
        # -------------------------------------------------

        print("\n1. DATABASE INTEGRITY")

        integrity = conn.execute(
            "PRAGMA integrity_check"
        ).fetchone()[0]

        print(f"Integrity Status: {integrity}")

        # -------------------------------------------------
        # 2. FOREIGN KEY CHECK
        # -------------------------------------------------

        print("\n2. FOREIGN KEY VERIFICATION")

        fk_errors = conn.execute(
            "PRAGMA foreign_key_check"
        ).fetchall()

        if fk_errors:
            print("Foreign Key Check: FAILED")

            for error in fk_errors:
                print(tuple(error))
        else:
            print("Foreign Key Check: PASSED")

        # -------------------------------------------------
        # 3. TOTAL TABLES
        # -------------------------------------------------

        print("\n3. DATABASE TABLES")

        tables = conn.execute("""
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE 'sqlite_%'
            ORDER BY name
        """).fetchall()

        print(f"Total Tables: {len(tables)}")

        existing_tables = {row["name"] for row in tables}

        # -------------------------------------------------
        # 4. RECORD COUNTS
        # -------------------------------------------------

        print("\n4. RECORD COUNTS")

        print("-" * 40)

        missing_tables = []

        for table in TABLE_QUERIES:

            if table not in existing_tables:
                print(f"{table}: TABLE NOT FOUND")
                missing_tables.append(table)
                continue

            count = conn.execute(
                f'SELECT COUNT(*) FROM "{table}"'
            ).fetchone()[0]

            print(f"{table}: {count} records")

        print("-" * 40)

        # -------------------------------------------------
        # 5. DISPLAY INSERTED DATA
        # -------------------------------------------------

        print("\n5. INSERTED DATA DETAILS")

        for table, query in TABLE_QUERIES.items():

            if table not in existing_tables:
                continue

            print("\n" + "=" * 60)
            print(f"TABLE: {table.upper()}")
            print("=" * 60)

            rows = conn.execute(query).fetchall()

            if not rows:
                print("No records found.")
                continue

            records = [dict(row) for row in rows]

            print(json.dumps(
                records,
                indent=4,
                ensure_ascii=False
            ))

        # -------------------------------------------------
        # 6. FINAL SUMMARY
        # -------------------------------------------------

        print("\n" + "=" * 60)
        print("                  FINAL SUMMARY")
        print("=" * 60)

        if integrity == "ok":
            print("Database Integrity: PASSED")
        else:
            print("Database Integrity: FAILED")

        if fk_errors:
            print("Foreign Key Validation: FAILED")
        else:
            print("Foreign Key Validation: PASSED")

        if missing_tables:
            print("Missing Tables:", ", ".join(missing_tables))
        else:
            print("All 13 seeded tables are present.")

        print("\nVerification completed.")

    except sqlite3.Error as error:
        print(f"\nDATABASE ERROR: {error}")

    except Exception as error:
        print(f"\nUNEXPECTED ERROR: {error}")

    finally:
        if conn is not None:
            conn.close()


# -------------------------------------------------
# MAIN
# -------------------------------------------------

if __name__ == "__main__":
    verify_database()
