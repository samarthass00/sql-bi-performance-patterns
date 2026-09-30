-- Pattern 1: watermark-based incremental load with MERGE (upsert).
-- Inputs : stg_orders (new extract), dw_orders (target), etl_watermark (last loaded timestamp per table)
-- Effect : only rows changed since the last run are merged; the watermark then advances.

MERGE INTO dw_orders AS t
USING (
    SELECT *
    FROM stg_orders
    WHERE modified_at > (SELECT last_loaded_at FROM etl_watermark WHERE table_name = 'dw_orders')
    QUALIFY row_number() OVER (PARTITION BY order_id ORDER BY modified_at DESC) = 1   -- latest version only
) AS s
ON t.order_id = s.order_id
WHEN MATCHED AND s.modified_at > t.modified_at THEN
    UPDATE SET status = s.status, amount = s.amount, modified_at = s.modified_at
WHEN NOT MATCHED THEN
    INSERT (order_id, customer_id, status, amount, modified_at)
    VALUES (s.order_id, s.customer_id, s.status, s.amount, s.modified_at);

UPDATE etl_watermark
SET last_loaded_at = (SELECT max(modified_at) FROM dw_orders)
WHERE table_name = 'dw_orders';
