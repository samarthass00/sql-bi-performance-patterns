-- SQL Server / Azure SQL version of Pattern 4 (reference; not executed in CI).
-- 4a running total and 3-month moving average
WITH monthly AS (
    SELECT customer_id, DATEFROMPARTS(YEAR(modified_at), MONTH(modified_at), 1) AS month_start, SUM(amount) AS amount
    FROM dbo.dw_orders
    GROUP BY customer_id, DATEFROMPARTS(YEAR(modified_at), MONTH(modified_at), 1)
)
SELECT *,
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY month_start ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_amount,
       AVG(amount) OVER (PARTITION BY customer_id ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3m
FROM monthly;

-- 4b top 2 per customer (no QUALIFY in T-SQL)
SELECT customer_id, order_id, amount
FROM (SELECT *, DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY amount DESC) AS rk FROM dbo.dw_orders) AS x
WHERE rk <= 2;

-- 4c gaps and islands
WITH m AS (
    SELECT DISTINCT customer_id, DATEFROMPARTS(YEAR(modified_at), MONTH(modified_at), 1) AS month_start FROM dbo.dw_orders
),
g AS (
    SELECT *, DATEDIFF(MONTH, '2000-01-01', month_start)
              - ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY month_start) AS island
    FROM m
)
SELECT customer_id, MIN(month_start) AS streak_start, MAX(month_start) AS streak_end, COUNT(*) AS months
FROM g GROUP BY customer_id, island;
