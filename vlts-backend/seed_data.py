
import sqlite3
from pathlib import Path


# -------------------------------------------------
# FILE PATHS
# -------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

DATABASE_PATH = BASE_DIR / "vlts.db"
SEED_FILE_PATH = BASE_DIR / "database" / "seed_data.sql"


# -------------------------------------------------
# TABLES TO VERIFY
# -------------------------------------------------

TABLES = [
    "roles",
    "users",
    "godowns",
    "od_pairs",
    "transporters",
    "vehicles",
    "model_runs",
    "routes",
    "trips",
    "recommendations",
    "trip_analysis",
    "deviation_segments",
    "performance_metrics"
]


# -------------------------------------------------
# SEED DATABASE
# -------------------------------------------------

def seed_database():

    if not DATABASE_PATH.exists():
        print("ERROR: Database file not found.")
        print("Please run init_db.py first.")
        return

    if not SEED_FILE_PATH.exists():
        print("ERROR: seed_data.sql file not found.")
        return

    conn = None

    try:
        # Connect to SQLite database
        conn = sqlite3.connect(DATABASE_PATH)

        # Enable foreign key validation
        conn.execute("PRAGMA foreign_keys = ON")

        # Read original SQL file
        with open(SEED_FILE_PATH, "r", encoding="utf-8") as file:
            sql_query = file.read()

        # -------------------------------------------------
        # Correct trip commodity capitalization in memory.
        # The original seed_data.sql remains unchanged.
        # -------------------------------------------------

        trips_start = sql_query.find("-- 8. TRIPS")
        recommendations_start = sql_query.find("-- 9. RECOMMENDATIONS")

        if trips_start == -1 or recommendations_start == -1:
            raise ValueError("Could not locate TRIPS section in seed_data.sql.")

        trips_section = sql_query[
            trips_start:recommendations_start
        ]

        trips_section = trips_section.replace("'Wheat'", "'wheat'")
        trips_section = trips_section.replace("'Rice'", "'rice'")

        sql_query = (
            sql_query[:trips_start]
            + trips_section
            + sql_query[recommendations_start:]
        )

        # -------------------------------------------------
        # Execute entire SQL file as one transaction
        # -------------------------------------------------

        conn.executescript(
            "BEGIN;\n" + sql_query + "\nCOMMIT;"
        )

        # Check foreign key integrity
        foreign_key_errors = conn.execute(
            "PRAGMA foreign_key_check"
        ).fetchall()

        if foreign_key_errors:
            raise RuntimeError(
                f"Foreign key errors found: {foreign_key_errors}"
            )

        print("\nData inserted successfully!")

        # -------------------------------------------------
        # DISPLAY RECORD COUNTS
        # -------------------------------------------------

        print("\n========== DATABASE RECORD COUNTS ==========")

        for table in TABLES:
            count = conn.execute(
                f"SELECT COUNT(*) FROM {table}"
            ).fetchone()[0]

            print(f"{table}: {count} records")

        # Database integrity check
        integrity = conn.execute(
            "PRAGMA integrity_check"
        ).fetchone()[0]

        print("\nDatabase integrity:", integrity)
        print("Foreign key check: Passed")

    except Exception as error:

        if conn is not None and conn.in_transaction:
            conn.rollback()

        print("\nERROR WHILE INSERTING DATA:")
        print(error)
        print("Transaction rolled back.")

    finally:
        if conn is not None:
            conn.close()


# -------------------------------------------------
# MAIN
# -------------------------------------------------

if __name__ == "__main__":
    seed_database()
