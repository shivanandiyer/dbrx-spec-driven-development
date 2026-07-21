-- Silver Layer: Validation, Deduplication, and Quarantine

-- Curated orders: Valid and deduplicated
CREATE OR REFRESH MATERIALIZED VIEW poc_spd.tiny_revenue_silver.orders
COMMENT "Silver layer: Valid, deduplicated orders"
AS
WITH ranked_orders AS (
  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY source_updated_at DESC) AS rn
  FROM poc_spd.tiny_revenue_bronze.orders_bronze
  WHERE order_id IS NOT NULL
    AND order_id RLIKE '^ORD-[0-9]{5}$'
    AND order_status IN ('COMPLETED', 'CANCELLED', 'PENDING')
    AND sales_channel IN ('ONLINE', 'STORE')
    AND quantity > 0
    AND unit_price > 0
    AND discount_amount >= 0
    AND discount_amount <= (quantity * unit_price)
)
SELECT
  order_id,
  order_timestamp,
  order_status,
  sales_channel,
  quantity,
  unit_price,
  discount_amount,
  source_updated_at,
  current_timestamp() AS _processed_at
FROM ranked_orders
WHERE rn = 1;

-- Quarantined orders: Invalid records with reasons
CREATE OR REFRESH MATERIALIZED VIEW poc_spd.tiny_revenue_silver.quarantined_orders
COMMENT "Silver layer: Invalid orders with quarantine reasons"
AS
SELECT 
  order_id,
  order_timestamp,
  order_status,
  sales_channel,
  quantity,
  unit_price,
  discount_amount,
  source_updated_at,
  CONCAT_WS('; ',
    CASE WHEN order_id IS NULL THEN 'Null order_id' END,
    CASE WHEN order_id IS NOT NULL AND NOT order_id RLIKE '^ORD-[0-9]{5}$' THEN 'Malformed order_id' END,
    CASE WHEN order_status NOT IN ('COMPLETED', 'CANCELLED', 'PENDING') THEN 'Invalid order_status' END,
    CASE WHEN sales_channel NOT IN ('ONLINE', 'STORE') THEN 'Invalid sales_channel' END,
    CASE WHEN quantity <= 0 THEN 'Invalid quantity' END,
    CASE WHEN unit_price <= 0 THEN 'Invalid unit_price' END,
    CASE WHEN discount_amount < 0 THEN 'Negative discount' END,
    CASE WHEN discount_amount > (quantity * unit_price) THEN 'Discount exceeds gross revenue' END
  ) AS quarantine_reason,
  current_timestamp() AS _quarantined_at
FROM poc_spd.tiny_revenue_bronze.orders_bronze
WHERE order_id IS NULL
  OR NOT order_id RLIKE '^ORD-[0-9]{5}$'
  OR order_status NOT IN ('COMPLETED', 'CANCELLED', 'PENDING')
  OR sales_channel NOT IN ('ONLINE', 'STORE')
  OR quantity <= 0
  OR unit_price <= 0
  OR discount_amount < 0
  OR discount_amount > (quantity * unit_price);