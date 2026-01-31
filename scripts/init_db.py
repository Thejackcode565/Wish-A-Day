#!/usr/bin/env python3
"""Database initialization script for Wishaday."""

import sys
from pathlib import Path

# Add the project root to the Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from app.database import init_db, engine, Base
from app.models import Wish, WishImage


def main():
    """Initialize the database tables."""
    print("Initializing database...")
    
    # Create all tables
    init_db()
    
    # Print table info
    print("\nDatabase tables created:")
    for table in Base.metadata.tables:
        print(f"  - {table}")
    
    # Verify connection
    from sqlalchemy import text
    with engine.connect() as conn:
        result = conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'"))
        tables = [row[0] for row in result.fetchall()]
        print(f"\nExisting tables: {tables}")
    
    print("\nDatabase initialization complete!")


if __name__ == "__main__":
    main()