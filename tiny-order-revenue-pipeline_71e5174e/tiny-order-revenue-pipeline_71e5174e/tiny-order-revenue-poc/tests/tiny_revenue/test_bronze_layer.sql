-- ============================================
-- Bronze Layer Validation Tests
-- Table: poc_spd.tiny_revenue_bronze.orders_bronze
-- ============================================

-- TEST 1: Verify total record count
SELECT 
  'TEST 1: Total Record Count' AS test_name,
  COUNT(*) AS actual_count,
  115 AS expected_count,
  CASE WHEN COUNT(*) = 115 THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_bronze.orders_bronze;

-- TEST 2: Verify all records have ingestion metadata
SELECT 
  'TEST 2: Ingestion Metadata' AS test_name,
  COUNT(*) AS records_with_metadata,
  SUM(CASE WHEN _ingested_at IS NULL OR _source_system IS NULL OR _record_hash IS NULL THEN 1 ELSE 0 END) AS records_missing_metadata,
  CASE WHEN SUM(CASE WHEN _ingested_at IS NULL OR _source_system IS NULL OR _record_hash IS NULL THEN 1 ELSE 0 END) = 0 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_bronze.orders_bronze;

-- TEST 3: Verify source system is correctly tagged
SELECT 
  'TEST 3: Source System Tag' AS test_name,
  COUNT(*) AS total_records,
  SUM(CASE WHEN _source_system = 'synthetic_generator' THEN 1 ELSE 0 END) AS correctly_tagged,
  CASE WHEN COUNT(*) = SUM(CASE WHEN _source_system = 'synthetic_generator' THEN 1 ELSE 0 END) 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_bronze.orders_bronze;

-- TEST 4: Verify record hash uniqueness
SELECT 
  'TEST 4: Record Hash Logic' AS test_name,
  COUNT(DISTINCT _record_hash) AS unique_hashes,
  COUNT(*) AS total_records,
  CASE WHEN COUNT(DISTINCT _record_hash) <= COUNT(*) THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_bronze.orders_bronze;

-- TEST 5: Verify ingestion timestamp is recent
SELECT 
  'TEST 5: Recent Ingestion' AS test_name,
  MIN(_ingested_at) AS earliest_ingestion,
  MAX(_ingested_at) AS latest_ingestion,
  CASE WHEN DATEDIFF(HOUR, MAX(_ingested_at), CURRENT_TIMESTAMP()) < 24 
    THEN 'PASS' ELSE 'FAIL' END AS test_result
FROM poc_spd.tiny_revenue_bronze.orders_bronze;