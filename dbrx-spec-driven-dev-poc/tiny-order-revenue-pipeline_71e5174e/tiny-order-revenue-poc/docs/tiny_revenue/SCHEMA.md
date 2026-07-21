# Schema Documentation

## Bronze Layer

### poc_spd.tiny_revenue_bronze.orders_bronze
Raw order records with ingestion metadata

| Column | Type | Description | Nullable |
|--------|------|-------------|----------|
| order_id | STRING | Order identifier | Yes |
| order_timestamp | TIMESTAMP | Order creation timestamp | Yes |
| order_status | STRING | Order status (COMPLETED, CANCELLED, PENDING, or invalid) | Yes |
| sales_channel | STRING | Sales channel (ONLINE, STORE, or invalid) | Yes |
| quantity | BIGINT | Order quantity | Yes |
| unit_price | DOUBLE | Unit price per item | Yes |
| discount_amount | DOUBLE | Total discount applied | Yes |
| source_updated_at | TIMESTAMP | Source system last update timestamp | Yes |
| _ingested_at | TIMESTAMP | Pipeline ingestion timestamp | No |
| _source_system | STRING | Source system identifier | No |
| _record_hash | STRING | SHA256 hash of record content | No |

## Silver Layer

### poc_spd.tiny_revenue_silver.orders
Valid, deduplicated orders

| Column | Type | Description | Nullable |
|--------|------|-------------|----------|
| order_id | STRING | Order identifier (format: ORD-\d{5}) | No |
| order_timestamp | TIMESTAMP | Order creation timestamp | No |
| order_status | STRING | Order status (COMPLETED, CANCELLED, PENDING) | No |
| sales_channel | STRING | Sales channel (ONLINE, STORE) | No |
| quantity | BIGINT | Order quantity (> 0) | No |
| unit_price | DOUBLE | Unit price per item (> 0) | No |
| discount_amount | DOUBLE | Total discount (0 to gross_revenue) | No |
| source_updated_at | TIMESTAMP | Source system last update timestamp | No |
| _processed_at | TIMESTAMP | Silver layer processing timestamp | No |

### poc_spd.tiny_revenue_silver.quarantined_orders
Invalid records with quarantine reasons

| Column | Type | Description | Nullable |
|--------|------|-------------|----------|
| order_id | STRING | Order identifier (may be null or invalid) | Yes |
| order_timestamp | TIMESTAMP | Order creation timestamp | Yes |
| order_status | STRING | Order status | Yes |
| sales_channel | STRING | Sales channel | Yes |
| quantity | BIGINT | Order quantity | Yes |
| unit_price | DOUBLE | Unit price per item | Yes |
| discount_amount | DOUBLE | Total discount applied | Yes |
| source_updated_at | TIMESTAMP | Source system last update timestamp | Yes |
| quarantine_reason | STRING | Detailed failure reason(s) | No |
| _quarantined_at | TIMESTAMP | Quarantine timestamp | No |

## Gold Layer

### poc_spd.tiny_revenue_gold.daily_revenue
Daily revenue aggregated by sales channel

| Column | Type | Description | Nullable |
|--------|------|-------------|----------|
| order_date | DATE | Order date | No |
| sales_channel | STRING | Sales channel (ONLINE, STORE) | No |
| completed_order_count | BIGINT | Count of COMPLETED orders | No |
| units_sold | BIGINT | Total quantity sold | No |
| gross_revenue | DECIMAL(18,2) | Sum of (quantity * unit_price) | No |
| discount_amount | DECIMAL(18,2) | Sum of discounts applied | No |
| net_revenue | DECIMAL(18,2) | Gross revenue - discount amount | No |
| product_updated_at | TIMESTAMP | Gold layer update timestamp | No |