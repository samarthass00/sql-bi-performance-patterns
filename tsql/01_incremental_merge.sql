-- SQL Server / Azure SQL version of Pattern 1 (reference; not executed in CI).
DECLARE @last DATETIME2 = (SELECT last_loaded_at FROM dbo.etl_watermark WHERE table_name = 'dw_orders');

WITH latest AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY modified_at DESC) AS rn
    FROM stg.orders
    WHERE modified_at > @last
)
MERGE dbo.dw_orders WITH (HOLDLOCK) AS t
USING (SELECT order_id, customer_id, status, amount, modified_at FROM latest WHERE rn = 1) AS s
    ON t.order_id = s.order_id
WHEN MATCHED AND s.modified_at > t.modified_at THEN
    UPDATE SET t.status = s.status, t.amount = s.amount, t.modified_at = s.modified_at
WHEN NOT MATCHED BY TARGET THEN
    INSERT (order_id, customer_id, status, amount, modified_at)
    VALUES (s.order_id, s.customer_id, s.status, s.amount, s.modified_at);

UPDATE dbo.etl_watermark
SET last_loaded_at = (SELECT MAX(modified_at) FROM dbo.dw_orders)
WHERE table_name = 'dw_orders';

-- Supporting index so the watermark filter seeks instead of scanning:
-- CREATE INDEX IX_stg_orders_modified_at ON stg.orders (modified_at) INCLUDE (order_id, customer_id, status, amount);
