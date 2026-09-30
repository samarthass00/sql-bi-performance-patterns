-- SQL Server / Azure SQL version of Pattern 3 (reference; not executed in CI).
WITH src AS (
    SELECT CAST(modified_at AS DATE) AS business_date, COUNT(*) AS row_count, ROUND(SUM(amount), 2) AS amount
    FROM src.orders GROUP BY CAST(modified_at AS DATE)
),
tgt AS (
    SELECT CAST(modified_at AS DATE) AS business_date, COUNT(*) AS row_count, ROUND(SUM(amount), 2) AS amount
    FROM dbo.dw_orders GROUP BY CAST(modified_at AS DATE)
)
SELECT COALESCE(s.business_date, t.business_date) AS business_date,
       s.row_count AS source_rows, t.row_count AS target_rows,
       s.amount AS source_amount, t.amount AS target_amount,
       ISNULL(s.amount, 0) - ISNULL(t.amount, 0) AS amount_diff
FROM src AS s
FULL OUTER JOIN tgt AS t ON t.business_date = s.business_date
WHERE ISNULL(s.row_count, -1) <> ISNULL(t.row_count, -1)
   OR ISNULL(s.amount, -1)    <> ISNULL(t.amount, -1)
ORDER BY business_date;
