-- Pattern 2: Slowly Changing Dimension Type 2.
-- Inputs : stg_customer (current snapshot), dim_customer (history with valid_from / valid_to / is_current)
-- Effect : changed customers get their current row closed and a new current row; new customers are inserted.
--          Tracked attributes: segment, region. load_date is supplied as a parameter ($load_date).

-- 1. Close current rows whose tracked attributes changed.
UPDATE dim_customer AS d
SET valid_to = CAST($load_date AS DATE) - 1, is_current = FALSE
FROM stg_customer AS s
WHERE d.customer_id = s.customer_id
  AND d.is_current
  AND (d.segment IS DISTINCT FROM s.segment OR d.region IS DISTINCT FROM s.region);

-- 2. Insert a new current version for changed and brand-new customers.
INSERT INTO dim_customer (customer_key, customer_id, segment, region, valid_from, valid_to, is_current)
SELECT
    (SELECT coalesce(max(customer_key), 0) FROM dim_customer) + row_number() OVER (ORDER BY s.customer_id),
    s.customer_id, s.segment, s.region,
    CAST($load_date AS DATE), DATE '9999-12-31', TRUE
FROM stg_customer AS s
LEFT JOIN dim_customer AS d
       ON d.customer_id = s.customer_id AND d.is_current
WHERE d.customer_id IS NULL;
