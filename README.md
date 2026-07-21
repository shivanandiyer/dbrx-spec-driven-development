# DBRX Spec-Driven Development PoC

This repository is a proof of concept for **spec-driven development** on Databricks: a written specification is handed to **Genie Code**, which reads it, plans an implementation, and then generates and runs a working Lakehouse data product — no hand-written pipeline code required.

The generated data product, **Tiny Order Revenue**, is a small medallion pipeline (synthetic data → bronze → silver → gold) with data-quality quarantine handling, SQL tests, and generated documentation. It's intentionally small so it runs comfortably in Databricks Free Edition.

## How This Works

1. The spec at [`specs/tiny-order-revenue-poc.md`](dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/tiny-order-revenue-poc/specs/tiny-order-revenue-poc.md) defines the goal, scope, business rules, target Unity Catalog objects, quality checks, tests, and documentation Genie Code must produce.
2. The spec includes explicit **Genie Code instructions** (an approval-gated two-phase process): first inspect the workspace and propose a plan, wait for approval, then build — generating synthetic data, creating the Lakeflow pipeline, running it, running tests, and producing a final report.
3. Everything under `dbrx-spec-driven-dev-poc/` in this repo is the **output** of that process from a prior run — the generated pipeline code, tests, and docs — kept here as a reference/example artifact.

## Running The PoC

Execute the spec file at [`specs/tiny-order-revenue-poc.md`](dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/tiny-order-revenue-poc/specs/tiny-order-revenue-poc.md) in Genie Code against a Databricks workspace. Genie Code will:

- Inspect the workspace and Unity Catalog access, then present a plan for approval.
- Once approved, generate deterministic synthetic order data, create the bronze/silver/gold tables and Lakeflow pipeline, run it, run the SQL tests, and produce a final report.

This single step is what generates and tests the pipeline end to end — no manual notebook or SQL upload steps are needed.

## What Gets Built

Tiny Order Revenue is an analytics data product for daily order revenue by sales channel:

- Deterministic synthetic order generation (seeded, reproducible)
- Intentional bad records for data-quality validation
- A medallion-style Databricks pipeline (bronze → silver → gold)
- Bronze ingestion with metadata (ingestion timestamp, source system, record hash)
- Silver validation, deduplication, and quarantine handling
- Gold daily revenue aggregation by sales channel
- SQL validation tests and generated documentation

### Target Unity Catalog Objects

| Layer | Object |
| --- | --- |
| Bronze | `poc_spd.tiny_revenue_bronze.orders_bronze` |
| Silver | `poc_spd.tiny_revenue_silver.orders` |
| Silver quarantine | `poc_spd.tiny_revenue_silver.quarantined_orders` |
| Gold | `poc_spd.tiny_revenue_gold.daily_revenue` |

The Lakeflow pipeline is named `tiny-order-revenue-pipeline`.

### Business Rules

- An order only contributes to revenue when `order_status = 'COMPLETED'`.
- `gross_revenue = quantity * unit_price`
- `net_revenue = gross_revenue - discount_amount`
- Daily revenue is net revenue summed by `order_date` and `sales_channel`.

## Prerequisites

- A Databricks workspace, preferably Databricks Free Edition
- A Unity Catalog catalog named `poc_spd` (Genie Code will ask before substituting another catalog)
- Permission to create schemas, tables, and a Lakeflow Spark Declarative Pipeline
- Serverless or compatible compute for pipeline execution

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
            ├── specs/
            │   └── tiny-order-revenue-poc.md
            ├── docs/tiny_revenue/
            │   ├── README.md
            │   ├── SCHEMA.md
            │   └── USAGE_EXAMPLES.md
            └── tests/tiny_revenue/
                ├── test_bronze_layer.sql
                ├── test_silver_layer.sql
                ├── test_quarantine_logic.sql
                ├── test_gold_layer.sql
                └── test_runner.py
```

This layout is the output of a prior Genie Code run — the `specs/` file is the source of truth; everything else here was generated from it.

## Generated Documentation (Reference)

Detailed generated documentation from the prior run lives under `dbrx-spec-driven-dev-poc/tiny-order-revenue-pipeline_71e5174e/tiny-order-revenue-poc/docs/tiny_revenue/`:

- `README.md`: data product overview and pipeline details
- `SCHEMA.md`: table and column definitions
- `USAGE_EXAMPLES.md`: sample analytics queries

## Notes

- All data is synthetic only and contains no PII.
- Execution is manual; jobs, schedules, dashboards, and cross-workspace deployment are out of scope for this PoC.
- The generated docs in this repo reference a specific Databricks pipeline ID from a prior run, which will differ when Genie Code regenerates the PoC in another workspace.
