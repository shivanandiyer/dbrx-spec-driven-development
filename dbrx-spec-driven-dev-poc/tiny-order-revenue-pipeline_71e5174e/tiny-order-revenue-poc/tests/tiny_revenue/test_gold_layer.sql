-- ============================================
-- Gold Layer Validation Tests
-- ============================================

-- TEST 1: Verify only COMPLETED orders included
SELECT 
  'TEST 1: Only Completed Orders' AS test_name,
  SUM(completed_order_count) AS gold_count,
  (SELECT COUNT(*) FROM poc_spd.tiny_revenue_silver.orders WHERE order_status = 'COMPLETED') AS silver_count,
  CASE WHEN SUM(completed_order_count) = (SELECT COUNT(*) FROM poc_spd.tiny_revenue_silver.orders WHERE order_status = 'COMPLETED') 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_gold.daily_revenue;

-- TEST 2: Verify net revenue calculation
SELECT 
  'TEST 2: Net Revenue Calculation' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN ABS(net_revenue - (gross_revenue - discount_amount)) < 0.01 THEN 1 ELSE 0 END) AS correct_calculations,
  CASE WHEN COUNT(*) = SUM(CASE WHEN ABS(net_revenue - (gross_revenue - discount_amount)) < 0.01 THEN 1 ELSE 0 END) 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_gold.daily_revenue;

-- TEST 3: Verify no negative values
SELECT 
  'TEST 3: No Negative Values' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN completed_order_count < 0 OR units_sold < 0 OR gross_revenue < 0 OR net_revenue < 0 THEN 1 ELSE 0 END) AS negative_values,
  CASE WHEN SUM(CASE WHEN completed_order_count < 0 OR units_sold < 0 OR gross_revenue < 0 OR net_revenue < 0 THEN 1 ELSE 0 END) = 0 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_gold.daily_revenue;

-- TEST 4: Revenue summary by channel
SELECT 
  'SUMMARY: Revenue by Channel' AS test_name,
  sales_channel,
  COUNT(*) AS days_with_orders,
  SUM(completed_order_count) AS total_orders,
  SUM(units_sold) AS total_units,
  CAST(SUM(gross_revenue) AS DECIMAL(18,2)) AS total_gross,
  CAST(SUM(net_revenue) AS DECIMAL(18,2)) AS total_net
FROM poc_spd.tiny_revenue_gold.daily_revenue
GROUP BY sales_channel;