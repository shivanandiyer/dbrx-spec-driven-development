# Usage Examples

## Basic Queries

### 1. View Latest Daily Revenue

SELECT 
  order_date,
  sales_channel,
  completed_order_count,
  net_revenue
FROM poc_spd.tiny_revenue_gold.daily_revenue
ORDER BY order_date DESC, sales_channel
LIMIT 10;

### 2. Total Revenue by Channel

SELECT 
  sales_channel,
  SUM(completed_order_count) AS total_orders,
  SUM(units_sold) AS total_units,
  CAST(SUM(net_revenue) AS DECIMAL(18,2)) AS total_revenue
FROM poc_spd.tiny_revenue_gold.daily_revenue
GROUP BY sales_channel;

### 3. Daily Revenue Trends

SELECT 
  order_date,
  SUM(net_revenue) AS daily_total_revenue,
  SUM(completed_order_count) AS daily_order_count,
  CAST(SUM(net_revenue) / SUM(completed_order_count) AS DECIMAL(18,2)) AS avg_order_value
FROM poc_spd.tiny_revenue_gold.daily_revenue
GROUP BY order_date
ORDER BY order_date DESC;

### 4. Monitor Quarantined Records

SELECT 
  quarantine_reason,
  COUNT(*) AS record_count,
  MIN(order_timestamp) AS earliest_order,
  MAX(order_timestamp) AS latest_order
FROM poc_spd.tiny_revenue_silver.quarantined_orders
GROUP BY quarantine_reason
ORDER BY COUNT(*) DESC;

### 5. Data Quality Dashboard

SELECT 
  'Total Bronze' AS metric,
  COUNT(*) AS value
FROM poc_spd.tiny_revenue_bronze.orders_bronze

UNION ALL

SELECT 
  'Valid Silver' AS metric,
  COUNT(*) AS value
FROM poc_spd.tiny_revenue_silver.orders

UNION ALL

SELECT 
  'Quarantined' AS metric,
  COUNT(*) AS value
FROM poc_spd.tiny_revenue_silver.quarantined_orders

UNION ALL

SELECT 
  'Gold Aggregations' AS metric,
  COUNT(*) AS value
FROM poc_spd.tiny_revenue_gold.daily_revenue;

### 6. Top Revenue Days

SELECT 
  order_date,
  SUM(net_revenue) AS total_revenue,
  SUM(completed_order_count) AS total_orders
FROM poc_spd.tiny_revenue_gold.daily_revenue
GROUP BY order_date
ORDER BY SUM(net_revenue) DESC
LIMIT 5;