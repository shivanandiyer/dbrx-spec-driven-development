-- ============================================
-- Quarantine Logic Validation Tests
-- ============================================

-- TEST 1: Verify quarantine record count
SELECT 
  'TEST 1: Quarantine Record Count' AS test_name,
  COUNT(*) AS actual_count,
  CASE WHEN COUNT(*) >= 13 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.quarantined_orders;

-- TEST 2: Verify all quarantined records have a reason
SELECT 
  'TEST 2: Quarantine Reason Present' AS test_name,
  COUNT(*) AS total_quarantined,
  SUM(CASE WHEN quarantine_reason IS NULL OR quarantine_reason = '' THEN 1 ELSE 0 END) AS missing_reason,
  CASE WHEN SUM(CASE WHEN quarantine_reason IS NULL OR quarantine_reason = '' THEN 1 ELSE 0 END) = 0 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.quarantined_orders;

-- TEST 3: Verify null order_id records captured
SELECT 
  'TEST 3: Null Order ID Captured' AS test_name,
  COUNT(*) AS null_count,
  CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.quarantined_orders
WHERE quarantine_reason LIKE '%Null order_id%';

-- TEST 4: Verify invalid statuses captured
SELECT 
  'TEST 4: Invalid Status Captured' AS test_name,
  COUNT(*) AS invalid_count,
  CASE WHEN COUNT(*) >= 2 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.quarantined_orders
WHERE quarantine_reason LIKE '%Invalid order_status%';

-- TEST 5: Verify excessive discounts captured
SELECT 
  'TEST 5: Excessive Discount Captured' AS test_name,
  COUNT(*) AS excessive_count,
  CASE WHEN COUNT(*) >= 2 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_silver.quarantined_orders
WHERE quarantine_reason LIKE '%Discount exceeds gross revenue%';

-- TEST 6: Quarantine reason distribution
SELECT 
  quarantine_reason,
  COUNT(*) AS record_count
FROM poc_spd.tiny_revenue_silver.quarantined_orders
GROUP BY quarantine_reason
ORDER BY COUNT(*) DESC;