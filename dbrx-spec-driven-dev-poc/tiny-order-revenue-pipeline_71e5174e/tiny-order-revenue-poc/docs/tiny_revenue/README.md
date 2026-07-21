# Tiny Order Revenue Data Product

## Overview
The Tiny Order Revenue data product provides curated, validated order and revenue analytics built on the Databricks Lakehouse Platform using Lakeflow Spark Declarative Pipelines.

## Purpose
Deliver trusted, production-ready daily revenue metrics aggregated by sales channel with comprehensive data quality controls and quarantine handling.

## Pipeline Details
* **Pipeline ID**: 2e29f306-ee49-4ffa-b7ba-89ea811a50af
* **Pipeline Name**: tiny-order-revenue-pipeline
* **Target Catalog**: poc_spd
* **Execution Mode**: Triggered (Manual)
* **Compute**: Serverless with Photon enabled

## Architecture

### Medallion Layers

#### Bronze Layer (`tiny_revenue_bronze`)
* **orders_bronze**: Raw order records with ingestion metadata
  * Captures all source data without validation
  * Adds ingestion timestamp, source system tag, and record hash
  * Total records: 115 (includes both valid and invalid)

#### Silver Layer (`tiny_revenue_silver`)
* **orders**: Valid, deduplicated orders ready for analytics
  * Deduplication using ROW_NUMBER by order_id and source_updated_at
  * Comprehensive validation rules applied
  * Total records: 100 validated orders
  
* **quarantined_orders**: Invalid records with detailed quarantine reasons
  * Captures data quality issues with specific failure reasons
  * Enables monitoring and remediation workflows
  * Total records: 13 quarantined with reasons

#### Gold Layer (`tiny_revenue_gold`)
* **daily_revenue**: Daily revenue aggregated by sales channel
  * Includes only COMPLETED orders
  * Metrics: order count, units sold, gross revenue, net revenue
  * Total records: 39 daily aggregations across channels

## Data Quality Rules

### Validation Constraints
* **Order ID**: Must match pattern `ORD-\d{5}`
* **Order Status**: Must be in ('COMPLETED', 'CANCELLED', 'PENDING')
* **Sales Channel**: Must be in ('ONLINE', 'STORE')
* **Quantity**: Must be > 0
* **Unit Price**: Must be > 0
* **Discount Amount**: Must be >= 0 and <= (quantity * unit_price)

### Quarantine Reasons Captured
* Null order_id
* Malformed order_id format
* Invalid order_status values
* Invalid sales_channel values
* Zero or negative quantities
* Negative unit prices
* Discounts exceeding gross revenue

## Table Metadata Tags
Gold layer tables are tagged with:
* `data_product`: tiny_order_revenue
* `layer`: gold
* `classification`: internal
* `contains_pii`: false

## Usage
See [USAGE_EXAMPLES.md](./USAGE_EXAMPLES.md) for query examples.

## Testing
Validation tests available in `/tiny-order-revenue-poc/tests/tiny_revenue/`:
* test_bronze_layer.sql
* test_silver_layer.sql
* test_quarantine_logic.sql
* test_gold_layer.sql

## Schema Documentation
See [SCHEMA.md](./SCHEMA.md) for detailed schema definitions.

## Contact
**Owner**: shivanand.iyer@gmail.com  
**Created**: 2026-07-21