-- SQL Server / Azure SQL version of Pattern 2 (reference; not executed in CI).
-- dim_customer.customer_key is an IDENTITY column.
DECLARE @load_date DATE = CAST(GETDATE() AS DATE);

BEGIN TRANSACTION;

UPDATE d
SET d.valid_to = DATEADD(DAY, -1, @load_date), d.is_current = 0
FROM dbo.dim_customer AS d
JOIN stg.customer AS s ON s.customer_id = d.customer_id
WHERE d.is_current = 1
  AND (ISNULL(d.segment, '') <> ISNULL(s.segment, '') OR ISNULL(d.region, '') <> ISNULL(s.region, ''));

INSERT INTO dbo.dim_customer (customer_id, segment, region, valid_from, valid_to, is_current)
SELECT s.customer_id, s.segment, s.region, @load_date, '9999-12-31', 1
FROM stg.customer AS s
LEFT JOIN dbo.dim_customer AS d ON d.customer_id = s.customer_id AND d.is_current = 1
WHERE d.customer_id IS NULL;

COMMIT TRANSACTION;
