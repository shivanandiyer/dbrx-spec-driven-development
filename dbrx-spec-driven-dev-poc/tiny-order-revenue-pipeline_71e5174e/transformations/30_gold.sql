-- Gold Layer: Daily Revenue Aggregation by Sales Channel

CREATE OR REFRESH MATERIALIZED VIEW poc_spd.tiny_revenue_gold.daily_revenue
COMMENT "Gold layer: Daily revenue aggregated by sales channel"
TBLPROPERTIES (
  'data_product' = 'tiny_order_revenue',
  'layer' = 'gold',
  'classification' = 'internal',
  'contains_pii' = 'false'
)
AS
SELECT
  DATE(order_timestamp) AS order_date,
  sales_channel,
  COUNT(DISTINCT order_id) AS completed_order_count,
  SUM(quantity) AS units_sold,
  CAST(SUM(quantity * unit_price) AS DECIMAL(18,2)) AS gross_revenue,
  CAST(SUM(discount_amount) AS DECIMAL(18,2)) AS discount_amount,
  CAST(SUM(quantity * unit_price) - SUM(discount_amount) AS DECIMAL(18,2)) AS net_revenue,
  current_timestamp() AS product_updated_at
FROM poc_spd.tiny_revenue_silver.orders
WHERE order_status = 'COMPLETED'
GROUP BY DATE(order_timestamp), sales_channel;