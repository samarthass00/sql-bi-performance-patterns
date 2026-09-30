from pathlib import Path

import duckdb
import pytest

SQL_DIR = Path(__file__).resolve().parents[1] / "duckdb"


def run_sql(con: duckdb.DuckDBPyConnection, name: str, **params: str) -> None:
    """Execute a pattern file, substituting $name parameters with quoted literals."""
    sql = (SQL_DIR / name).read_text(encoding="utf-8")
    for key, value in params.items():
        sql = sql.replace(f"${key}", "'" + value.replace("'", "''") + "'")
    con.execute(sql)


@pytest.fixture
def con():
    c = duckdb.connect()
    c.execute("""
        CREATE TABLE dw_orders (order_id INT PRIMARY KEY, customer_id INT, status VARCHAR, amount DECIMAL(12,2), modified_at TIMESTAMP);
        CREATE TABLE stg_orders AS SELECT * FROM dw_orders WHERE false;
        CREATE TABLE etl_watermark (table_name VARCHAR, last_loaded_at TIMESTAMP);
        INSERT INTO dw_orders VALUES
            (1, 100, 'open',    50.00, '2025-01-05 09:00'),
            (2, 100, 'shipped', 75.00, '2025-02-10 10:00'),
            (3, 200, 'open',    20.00, '2025-01-20 11:00');
        INSERT INTO etl_watermark VALUES ('dw_orders', '2025-02-10 10:00');
    """)
    yield c
    c.close()
