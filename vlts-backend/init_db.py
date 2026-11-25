import sqlite3
from pathlib import Path

# Get the vlts-backend directory
BASE_DIR = Path(__file__).resolve().parent

# Define database and schema paths
DB_PATH = BASE_DIR / "vlts.db"
SCHEMA_PATH = BASE_DIR / "database" / "vlts_schema.sql"


def initialize_database():

    # Check whether SQL schema exists
    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(
            f"SQL schema not found: {SCHEMA_PATH}"
        )

    # Connect to SQLite database
    conn = sqlite3.connect(DB_PATH)

    try:
        # Enable foreign key constraints
        conn.execute("PRAGMA foreign_keys = ON")

        # Read SQL schema
        with open(SCHEMA_PATH, "r", encoding="utf-8") as file:
            sql_script = file.read()

        # Execute the complete SQL script
        conn.executescript(sql_script)

        print("Database initialized successfully!")

        # Fetch all created tables
        cursor = conn.execute("""
            SELECT name
            FROM sqlite_master
            WHERE type = 'table'
            AND name NOT LIKE 'sqlite_%'
            ORDER BY name
        """)

        tables = cursor.fetchall()

        print("\n========== DATABASE TABLES ==========")

        for index, table in enumerate(tables, start=1):
            print(f"{index}. {table[0]}")

        print("\n======================================")
        print(f"Total tables created: {len(tables)}")

    finally:
        conn.close()


if __name__ == "__main__":
    initialize_database()
