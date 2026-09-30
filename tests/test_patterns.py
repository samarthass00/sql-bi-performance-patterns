from decimal import Decimal

from conftest import SQL_DIR, run_sql


def test_incremental_merge_updates_inserts_and_ignores_old_rows(con):
    con.execute("""
        INSERT INTO stg_orders VALUES
            (2, 100, 'delivered', 75.00, '2025-03-01 08:00'),   -- update
            (2, 100, 'returned',  75.00, '2025-02-28 08:00'),   -- older duplicate, must lose
            (4, 300, 'open',      99.99, '2025-03-02 08:00'),   -- insert
            (3, 200, 'stale',     20.00, '2025-01-01 08:00');   -- before watermark, ignored
    """)
    run_sql(con, "01_incremental_merge.sql")
    rows = dict(con.execute("SELECT order_id, status FROM dw_orders").fetchall())
    assert rows == {1: "open", 2: "delivered", 3: "open", 4: "open"}
    assert str(con.execute("SELECT last_loaded_at FROM etl_watermark").fetchone()[0]) == "2025-03-02 08:00:00"


def test_incremental_merge_is_idempotent(con):
    con.execute("INSERT INTO stg_orders VALUES (5, 400, 'open', 10.00, '2025-04-01 08:00')")
    run_sql(con, "01_incremental_merge.sql")
    run_sql(con, "01_incremental_merge.sql")
    assert con.execute("SELECT count(*) FROM dw_orders WHERE order_id = 5").fetchone()[0] == 1


def test_scd2_keeps_history_and_one_current_row(con):
    con.execute("""
        CREATE TABLE dim_customer (customer_key INT, customer_id INT, segment VARCHAR, region VARCHAR,
                                   valid_from DATE, valid_to DATE, is_current BOOLEAN);
        INSERT INTO dim_customer VALUES (1, 100, 'SMB', 'West', '2024-01-01', '9999-12-31', true),
                                        (2, 200, 'Enterprise', 'East', '2024-01-01', '9999-12-31', true);
        CREATE TABLE stg_customer (customer_id INT, segment VARCHAR, region VARCHAR);
        INSERT INTO stg_customer VALUES (100, 'Mid-Market', 'West'),  -- changed
                                        (200, 'Enterprise', 'East'),  -- unchanged
                                        (300, 'SMB', 'South');        -- new
    """)
    run_sql(con, "02_scd_type2.sql", load_date="2025-02-01")
    hist = con.execute("SELECT segment, valid_to, is_current FROM dim_customer WHERE customer_id = 100 ORDER BY valid_from").fetchall()
    assert [(h[0], h[2]) for h in hist] == [("SMB", False), ("Mid-Market", True)]
    assert str(hist[0][1]) == "2025-01-31"
    per_customer = con.execute("SELECT customer_id, count(*) FILTER (WHERE is_current) FROM dim_customer GROUP BY 1").fetchall()
    assert all(n == 1 for _, n in per_customer) and len(per_customer) == 3
    keys = [k for (k,) in con.execute("SELECT customer_key FROM dim_customer").fetchall()]
    assert len(keys) == len(set(keys))


def test_reconciliation_flags_only_mismatched_dates(con):
    con.execute("CREATE TABLE src_orders AS SELECT * FROM dw_orders")
    con.execute("INSERT INTO src_orders VALUES (9, 100, 'open', 5.00, '2025-01-20 15:00')")  # missing in target
    diffs = con.execute((SQL_DIR / "03_reconciliation.sql").read_text()).fetchall()
    assert len(diffs) == 1
    business_date, src_rows, tgt_rows, *_ , amount_diff = diffs[0]
    assert str(business_date) == "2025-01-20" and (src_rows, tgt_rows) == (2, 1) and amount_diff == Decimal("5.00")


def test_window_function_views(con):
    con.execute("INSERT INTO dw_orders VALUES (6, 100, 'open', 30.00, '2025-04-15 09:00'), (7, 100, 'open', 80.00, '2025-04-16 09:00')")
    run_sql(con, "04_window_functions.sql")
    running = con.execute("SELECT running_amount FROM v_customer_monthly WHERE customer_id = 100 ORDER BY month_start").fetchall()
    assert [float(r[0]) for r in running] == [50.0, 125.0, 235.0]
    top2 = {o for (o,) in con.execute("SELECT order_id FROM v_top2_orders WHERE customer_id = 100").fetchall()}
    assert top2 == {7, 2}
    streaks = con.execute("SELECT months FROM v_active_streaks WHERE customer_id = 100 ORDER BY streak_start").fetchall()
    assert [s[0] for s in streaks] == [2, 1]   # Jan-Feb, then a gap, then Apr
