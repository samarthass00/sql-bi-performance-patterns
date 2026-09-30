-- Pattern 4: window functions commonly needed behind BI measures.
-- 4a. Running total and 3-month moving average per customer.
-- 4b. Top 2 orders per customer (top-N per group).
-- 4c. Gaps and islands: consecutive active months per customer.

-- 4a
CREATE OR REPLACE VIEW v_customer_monthly AS
WITH monthly AS (
    SELECT customer_id, date_trunc('month', modified_at)::DATE AS month_start, sum(amount) AS amount
    FROM dw_orders GROUP BY ALL
)
SELECT *,
       sum(amount) OVER (PARTITION BY customer_id ORDER BY month_start
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_amount,
       round(avg(amount) OVER (PARTITION BY customer_id ORDER BY month_start
                               ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly;

-- 4b
CREATE OR REPLACE VIEW v_top2_orders AS
SELECT customer_id, order_id, amount
FROM dw_orders
QUALIFY dense_rank() OVER (PARTITION BY customer_id ORDER BY amount DESC) <= 2;

-- 4c
CREATE OR REPLACE VIEW v_active_streaks AS
WITH m AS (
    SELECT DISTINCT customer_id, date_trunc('month', modified_at)::DATE AS month_start FROM dw_orders
),
g AS (
    SELECT *, date_diff('month', DATE '2000-01-01', month_start)
              - row_number() OVER (PARTITION BY customer_id ORDER BY month_start) AS island
    FROM m
)
SELECT customer_id, min(month_start) AS streak_start, max(month_start) AS streak_end, count(*) AS months
FROM g GROUP BY customer_id, island;
