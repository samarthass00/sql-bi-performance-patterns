-- Pattern 3: source-to-warehouse reconciliation by business date.
-- Returns only the dates where row counts or amounts disagree, so an empty result means "reconciled".
WITH src AS (
    SELECT CAST(modified_at AS DATE) AS business_date, count(*) AS row_count, round(sum(amount), 2) AS amount
    FROM src_orders GROUP BY 1
),
tgt AS (
    SELECT CAST(modified_at AS DATE) AS business_date, count(*) AS row_count, round(sum(amount), 2) AS amount
    FROM dw_orders GROUP BY 1
)
SELECT
    coalesce(src.business_date, tgt.business_date) AS business_date,
    src.row_count AS source_rows,  tgt.row_count AS target_rows,
    src.amount    AS source_amount, tgt.amount   AS target_amount,
    coalesce(src.amount, 0) - coalesce(tgt.amount, 0) AS amount_diff
FROM src
FULL OUTER JOIN tgt USING (business_date)
WHERE src.row_count IS DISTINCT FROM tgt.row_count
   OR src.amount    IS DISTINCT FROM tgt.amount
ORDER BY business_date;
