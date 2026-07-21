-- Bronze Layer: Ingest all source order records with metadata

CREATE OR REFRESH STREAMING TABLE poc_spd.tiny_revenue_bronze.orders_bronze
COMMENT "Bronze layer: All source order records with ingestion metadata"
AS SELECT
  order_id,
  order_timestamp,
  order_status,
  sales_channel,
  quantity,
  unit_price,
  discount_amount,
  source_updated_at,
  current_timestamp() AS _ingested_at,
  'synthetic_generator' AS _source_system,
  sha2(concat_ws('||', 
    coalesce(order_id, 'NULL'),
    coalesce(cast(order_timestamp as string), 'NULL'),
    coalesce(order_status, 'NULL'),
    coalesce(sales_channel, 'NULL'),
    coalesce(cast(quantity as string), 'NULL'),
    coalesce(cast(unit_price as string), 'NULL'),
    coalesce(cast(discount_amount as string), 'NULL')
  ), 256) AS _record_hash
FROM STREAM(poc_spd.default.synthetic_orders_staging);