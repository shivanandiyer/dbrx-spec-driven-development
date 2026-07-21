# DBRX Spec-Driven Development PoC

This repository contains a small Databricks proof of concept for spec-driven development. The generated data product, **Tiny Order Revenue**, starts from a written specification and produces a runnable Lakehouse pipeline with synthetic data, bronze/silver/gold transformations, SQL tests, and generated documentation.

The implementation is intentionally small so it can run comfortably in Databricks Free Edition.

## What This Builds

Tiny Order Revenue is an analytics data product for daily order revenue by sales channel. It demonstrates:

- Deterministic synthetic order generation
- Intentional bad records for data-quality validation
- A medallion-style Databricks pipeline
- Bronze ingestion with metadata
- Silver validation, deduplication, and quarantine handling
- Gold daily revenue aggregation
- SQL validation tests and generated documentation

## Repository Layout

```text
.
└── dbrx-spec-driven-dev-poc/
    ├── manifest.mf
    └── tiny-order-revenue-pipeline_71e5174e/
        ├── transformations/
        │   ├── 01_generate_synthetic_orders.py
        │   ├── 10_bronze.sql
        │   ├── 20_silver.sql
        │   └── 30_gold.sql
        └── tiny-order-revenue-poc/
            ├── docs/tiny_revenue/
            │   ├── README.md
            │   ├── SCHEMA.md
            │   └── USAGE_EXAMPLES.md
            ├── specs/
            │   └── tiny-order-revenue-poc.md
            └── tests/tiny_revenue/
                ├── test_bronze_layer.sql
                ├── test_silver_layer.sql
                ├── test_quarantine_logic.sql
                ├── test_gold_layer.sql
                └── test_runner.py
```

## Target Databricks Objects

The PoC targets Unity Catalog object names under the `poc_spd` catalog:

| Layer | Object |
| --- | --- |
| Staging | `poc_spd.default.synthetic_orders_staging` |
| Bronze | `poc_spd.tiny_revenue_bronze.orders_bronze` |
| Silver | `poc_spd.tiny_revenue_silver.orders` |
| Silver quarantine | `poc_spd.tiny_revenue_silver.quarantined_orders` |
| Gold | `poc_spd.tiny_revenue_gold.daily_revenue` |

The generated Lakeflow pipeline is named `tiny-order-revenue-pipeline`.

## Data Flow

1. `01_generate_synthetic_orders.py` creates deterministic synthetic order data using random seed `42` and a fixed reference date of `2026-06-21`.
2. `10_bronze.sql` ingests all source rows into bronze and adds ingestion metadata.
3. `20_silver.sql` creates curated valid orders and a quarantine view with failure reasons.
4. `30_gold.sql` aggregates completed orders into daily revenue by sales channel.

The generator produces 100 valid records plus intentional invalid records, including duplicate order IDs, malformed IDs, invalid statuses, invalid sales channels, invalid quantities, invalid prices, and discounts greater than gross revenue.

## Prerequisites

- Databricks workspace, preferably Databricks Free Edition for this PoC
- Unity Catalog catalog named `poc_spd`
- Permission to create schemas, tables, materialized views, and a Lakeflow Spark Declarative Pipeline
- Serverless or compatible compute for pipeline execution

If you use a catalog other than `poc_spd`, update the object names in the transformation SQL and tests before running the pipeline.

## Running The PoC

1. Upload or sync the contents of `dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/` to your Databricks workspace.
2. Run `transformations/01_generate_synthetic_orders.py` to create the staging table.
3. Create or refresh the Lakeflow pipeline using the SQL files in `transformations/` in this order:
   - `10_bronze.sql`
   - `20_silver.sql`
   - `30_gold.sql`
4. Trigger the pipeline manually.
5. Run the SQL tests in `tiny-order-revenue-poc/tests/tiny_revenue/` to validate the bronze, silver, quarantine, and gold outputs.

## Testing

The test suite is SQL-based and intended to run in Databricks against the generated Unity Catalog objects. The included runner executes each SQL test file with Spark:

```python
test_files = [
    "test_bronze_layer.sql",
    "test_silver_layer.sql",
    "test_quarantine_logic.sql",
    "test_gold_layer.sql",
]
```

Run the tests after refreshing the pipeline so that the expected bronze, silver, quarantine, and gold objects exist.

## Documentation

Detailed generated documentation lives under `dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/tiny-order-revenue-poc/docs/tiny_revenue/`:

- `README.md`: data product overview and pipeline details
- `SCHEMA.md`: table and column definitions
- `USAGE_EXAMPLES.md`: sample analytics queries

The original implementation spec is available at `dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/tiny-order-revenue-poc/specs/tiny-order-revenue-poc.md`.

## Notes

- The data is synthetic only and contains no PII.
- Execution is manual; jobs, schedules, dashboards, and cross-workspace deployment are out of scope for this PoC.
- The current generated docs reference a specific Databricks pipeline ID, which may differ in another workspace.
