-- ============================================
-- Silver Layer Validation Tests
-- Table: poc_spd.tiny_revenue_silver.orders
-- ============================================

-- TEST 1: Verify valid orders count
SELECT 
  'TEST 1: Valid Orders Count' AS test_name,
  COUNT(*) AS actual_count,
  100 AS expected_count,
  CASE WHEN COUNT(*) = 100 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.orders;

-- TEST 2: Verify no duplicates
SELECT 
  'TEST 2: No Duplicates' AS test_name,
  COUNT(*) AS total_records,
  COUNT(DISTINCT order_id) AS unique_order_ids,
  CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.orders;

-- TEST 3: Verify order ID format
SELECT 
  'TEST 3: Order ID Format' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN order_id RLIKE '^ORD-[0-9]{5}$' THEN 1 ELSE 0 END) AS valid_format,
  CASE WHEN COUNT(*) = SUM(CASE WHEN order_id RLIKE '^ORD-[0-9]{5}$' THEN 1 ELSE 0 END) 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.orders;

-- TEST 4: Verify all order statuses are valid
SELECT 
  'TEST 4: Valid Order Status' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN order_status IN ('COMPLETED', 'CANCELLED', 'PENDING') THEN 1 ELSE 0 END) AS valid_status,
  CASE WHEN COUNT(*) = SUM(CASE WHEN order_status IN ('COMPLETED', 'CANCELLED', 'PENDING') THEN 1 ELSE 0 END) 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.orders;

-- TEST 5: Verify discount constraints
SELECT 
  'TEST 5: Discount Constraints' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN discount_amount >= 0 AND discount_amount <= (quantity * unit_price) THEN 1 ELSE 0 END) AS valid_discount,
  CASE WHEN COUNT(*) = SUM(CASE WHEN discount_amount >= 0 AND discount_amount <= (quantity * unit_price) THEN 1 ELSE 0 END) 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.orders;