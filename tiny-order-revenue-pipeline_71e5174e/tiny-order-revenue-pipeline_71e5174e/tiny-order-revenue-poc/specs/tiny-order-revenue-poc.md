# Tiny Order Revenue Data Product
## Spec-Driven Development Proof of Concept

**Platform:** Databricks Free Edition  
**Implementation assistant:** Genie Code  
**Purpose:** Learn spec-driven development with a small, runnable Lakeflow pipeline  
**Data classification:** Synthetic data only  
**Execution mode:** Manual  
**Catalog:** `poc_spd`  
**Version:** 1.0  

---

## 1. Goal

Build a small analytics data product called **Tiny Order Revenue**.

The product must demonstrate that Genie Code can interpret a written
specification and create:

- Synthetic data
- A small Lakeflow pipeline
- Bronze, silver, and gold tables
- Data-quality checks
- SQL tests
- Basic documentation

Keep the implementation intentionally small so it runs comfortably in
Databricks Free Edition.

---

## 2. Scope

### In scope

- One synthetic orders source dataset
- One bronze table
- One silver table
- One gold table
- One Lakeflow Spark Declarative Pipeline
- Basic data quality and quarantine handling
- Three SQL test files
- One validation SQL file
- A small README

### Out of scope

- Multiple source systems
- Multiple pipelines
- External data sources
- Streaming
- Jobs or schedules
- Asset Bundles
- Dashboards
- Complex security models
- Real customer data
- PII
- Cross-workspace deployment

---

## 3. Approval Gate

Before creating any files, tables, schemas, or pipeline assets:

1. Inspect the workspace and repository context.
2. Confirm whether the `poc_spd` catalog is available.
3. Confirm whether a Lakeflow Spark Declarative Pipeline can be created.
4. Confirm that there is no conflicting active pipeline of the same type.
5. Produce:
   - A short implementation plan
   - A proposed file tree
   - Assumptions and prerequisites
6. Stop and wait for my explicit approval.

Do not create anything until I approve the plan.

If `poc_spd` is unavailable, ask me what catalog to use. Do not substitute a
catalog silently.

---

## 4. Target Objects

Use the following Unity Catalog structure.

| Purpose | Location |
|---|---|
| Catalog | `poc_spd` |
| Bronze schema | `poc_spd.tiny_revenue_bronze` |
| Silver schema | `poc_spd.tiny_revenue_silver` |
| Gold schema | `poc_spd.tiny_revenue_gold` |

Create these managed Delta tables:

```text
poc_spd.tiny_revenue_bronze.orders_bronze

poc_spd.tiny_revenue_silver.orders
poc_spd.tiny_revenue_silver.quarantined_orders

poc_spd.tiny_revenue_gold.daily_revenue
```

Create one Lakeflow pipeline named:

```text
tiny-order-revenue-pipeline
```

---

## 5. Business Definitions

### Order

A purchase transaction. Only an order with status `COMPLETED` contributes to
revenue.

### Gross revenue

```text
gross_revenue = quantity * unit_price
```

### Net revenue

```text
net_revenue = quantity * unit_price - discount_amount
```

### Daily revenue

Daily revenue is the sum of completed-order net revenue grouped by order date
and sales channel.

---

## 6. Synthetic Source Contract

Generate deterministic synthetic order data using a fixed random seed.

Generate approximately:

```text
100 valid order records
```

Generate records for the previous 30 days relative to a fixed reference date in
code. Do not use the real-world current date, so results remain reproducible.

The source data must include intentional invalid records to prove quality and
quarantine behaviour.

### 6.1 Source columns

| Column | Type | Required | Rules |
|---|---|---:|---|
| order_id | STRING | Yes | `ORD-` followed by five digits |
| order_timestamp | TIMESTAMP | Yes | UTC timestamp within 30-day period |
| order_status | STRING | Yes | `COMPLETED`, `CANCELLED`, or `PENDING` |
| sales_channel | STRING | Yes | `ONLINE` or `STORE` |
| quantity | INT | Yes | Integer greater than zero |
| unit_price | DECIMAL(12,2) | Yes | Greater than zero |
| discount_amount | DECIMAL(12,2) | Yes | From zero to gross revenue |
| source_updated_at | TIMESTAMP | Yes | UTC timestamp |

### 6.2 Required intentional invalid records

Generate at least:

- 3 duplicate order IDs with later `source_updated_at`
- 2 null or malformed order IDs
- 2 invalid order statuses
- 2 zero or negative quantities
- 2 negative unit prices
- 2 discounts greater than gross revenue
- 2 invalid sales channels

The synthetic-data generator must be rerunnable without producing uncontrolled
duplicates. Use a deterministic seed and overwrite or recreate only the
proof-of-concept source data as needed.

---

## 7. Bronze Layer

Create:

```text
poc_spd.tiny_revenue_bronze.orders_bronze
```

The bronze table must preserve all source records, including invalid and
duplicate records.

Append these metadata columns:

| Column | Type | Rule |
|---|---|---|
| _ingested_at | TIMESTAMP | UTC timestamp |
| _source_system | STRING | Always `synthetic_generator` |
| _record_hash | STRING | Deterministic hash of source business fields |

Requirements:

- Retain every source record.
- Add a descriptive table comment.
- Add comments to columns where supported.
- Ensure metadata columns are non-null.
- Use a managed Delta table.

---

## 8. Silver Layer

Create:

```text
poc_spd.tiny_revenue_silver.orders
poc_spd.tiny_revenue_silver.quarantined_orders
```

### 8.1 Curated silver orders

The curated table must contain only valid, deduplicated orders.

Required columns:

```text
order_id
order_timestamp
order_status
sales_channel
quantity
unit_price
discount_amount
source_updated_at
_processed_at
```

Validation rules:

1. `order_id` is non-null and matches:

```text
^ORD-[0-9]{5}$
```

2. `order_status` is one of:

```text
COMPLETED
CANCELLED
PENDING
```

3. `sales_channel` is one of:

```text
ONLINE
STORE
```

4. `quantity > 0`
5. `unit_price > 0`
6. `discount_amount >= 0`
7. `discount_amount <= quantity * unit_price`

Deduplication rule:

- Use `order_id` as the business key.
- For duplicate valid order IDs, retain only the record with the latest
  `source_updated_at`.

### 8.2 Quarantined orders

The quarantine table must contain all invalid records.

It must preserve source columns and include:

```text
quarantine_reason
_quarantined_at
```

Requirements:

- Do not silently drop invalid records.
- `quarantine_reason` must explain why the record was rejected.
- If a record violates multiple rules, capture all reasons in a consistent
  readable format.
- Add a descriptive table comment.
- At least one record must appear in this table after the pipeline runs.

---

## 9. Gold Layer

Create:

```text
poc_spd.tiny_revenue_gold.daily_revenue
```

Grain:

```text
One row per order_date and sales_channel
```

Required columns:

| Column | Type | Rule |
|---|---|---|
| order_date | DATE | Date from `order_timestamp` |
| sales_channel | STRING | `ONLINE` or `STORE` |
| completed_order_count | BIGINT | Distinct completed order count |
| units_sold | BIGINT | Sum of quantity |
| gross_revenue | DECIMAL(18,2) | Sum of quantity * unit price |
| discount_amount | DECIMAL(18,2) | Sum of discount |
| net_revenue | DECIMAL(18,2) | Gross revenue minus discount |
| product_updated_at | TIMESTAMP | UTC timestamp |

Rules:

- Include only curated silver orders with `order_status = 'COMPLETED'`.
- `gross_revenue = sum(quantity * unit_price)`.
- `discount_amount = sum(discount_amount)`.
- `net_revenue = gross_revenue - discount_amount`.
- Gross revenue, discount amount, and net revenue must be non-negative.
- Net revenue must reconcile to curated silver completed orders.
- Add a descriptive table comment and column comments where supported.

Apply these tags to the gold table if supported:

| Tag | Value |
|---|---|
| data_product | tiny_order_revenue |
| layer | gold |
| classification | internal |
| contains_pii | false |

---

## 10. Pipeline Requirements

Create one Lakeflow Spark Declarative Pipeline named:

```text
tiny-order-revenue-pipeline
```

The logical stages are:

```text
Synthetic source generation
        |
        v
Bronze orders ingestion
        |
        v
Silver validation, deduplication, and quarantine
        |
        v
Gold daily revenue aggregation
```

Requirements:

- Use SQL where practical.
- Use Python only for deterministic synthetic-data generation if required.
- Keep the pipeline simple and lightweight.
- Do not create a schedule.
- Configure manual execution only.
- Use pipeline expectations where supported for observability.
- Preserve invalid records through explicit quarantine logic.
- Run the pipeline after implementation.
- If it fails, inspect the error and correct the code rather than weakening
  requirements.

---

## 11. Quality Checks

Implement pipeline expectations where supported and standalone SQL tests for
the following checks.

### Bronze checks

- Bronze table contains more than zero rows.
- `_ingested_at` is non-null.
- `_source_system` is non-null.
- `_record_hash` is non-null.

### Silver checks

- Curated `order_id` is non-null and unique.
- Curated order ID conforms to the required pattern.
- Curated order status is valid.
- Curated sales channel is valid.
- Quantity is greater than zero.
- Unit price is greater than zero.
- Discount is from zero to gross revenue.
- Quarantine table contains records.
- Quarantine reason is non-null.

### Gold checks

- `order_date` is non-null.
- `sales_channel` is valid.
- Gross revenue is non-negative.
- Discount amount is non-negative.
- Net revenue is non-negative.
- Net revenue equals gross revenue minus discount amount within 0.01.
- Total gold net revenue equals total completed curated silver net revenue
  within 0.01.

---

## 12. Repository Structure

Create the following files, adapting only if the current Lakeflow configuration
requires a different supported layout.

```text
.
├── specs/
│   └── tiny-order-revenue-poc.md
├── src/
│   └── tiny_revenue/
│       ├── 01_generate_synthetic_orders.py
│       ├── 10_bronze.sql
│       ├── 20_silver.sql
│       ├── 30_gold.sql
│       └── validation.sql
├── tests/
│   └── tiny_revenue/
│       ├── README.md
│       ├── test_silver_quality.sql
│       ├── test_gold_reconciliation.sql
│       └── test_data_contract.sql
├── docs/
│   └── tiny_revenue/
│       ├── data-product.md
│       └── runbook.md
└── README.md
```

---

## 13. Test Requirements

Create the following test files.

### 13.1 `tests/tiny_revenue/test_silver_quality.sql`

Test:

- Duplicate curated order IDs
- Null or malformed curated order IDs
- Invalid status
- Invalid sales channel
- Invalid quantity
- Invalid unit price
- Invalid discount
- Empty quarantine table
- Null quarantine reason

### 13.2 `tests/tiny_revenue/test_gold_reconciliation.sql`

Test:

- Negative gold revenue values
- Net revenue arithmetic
- Gold-to-silver total revenue reconciliation
- Invalid sales channel in gold
- Null order dates

### 13.3 `tests/tiny_revenue/test_data_contract.sql`

Test:

- Required tables exist
- Required columns exist
- Required gold table columns are non-null where specified
- Gold table tag exists, if tags are supported
- Gold table comment exists, if comments are queryable

### 13.4 Test standard

Each test must:

- Use fully qualified table names.
- Return zero rows when it passes.
- Return diagnostic failure rows when it fails.
- Include a `failure_reason` field in its output.
- Start with comments explaining the test logic.
- Be executable independently in the Databricks SQL editor.

Create `tests/tiny_revenue/README.md` explaining how to run each test.

---

## 14. Validation Queries

Create:

```text
src/tiny_revenue/validation.sql
```

It must include queries that return:

1. Row counts for bronze, silver, quarantine, and gold tables.
2. Quarantine counts by reason.
3. Ten sample curated orders.
4. Ten sample daily revenue records.
5. Total completed silver net revenue.
6. Total gold net revenue.
7. The difference between silver and gold net revenue.
8. Daily revenue grouped by sales channel.

---

## 15. Documentation

### 15.1 Data product document

Create:

```text
docs/tiny_revenue/data-product.md
```

Include:

- Product purpose
- Product owner: `data_product_demo`
- Source: `synthetic_generator`
- Table inventory
- Gold table grain
- Metric definitions
- Data-quality and quarantine design
- Plain-English lineage:
  `synthetic source -> bronze -> silver -> gold`
- Two example consumer SQL queries
- Limitations and assumptions

### 15.2 Runbook

Create:

```text
docs/tiny_revenue/runbook.md
```

Include:

- Required access and prerequisites
- How to create or run the pipeline
- How to rerun synthetic data generation
- How to run tests
- How to inspect quarantined records
- Common failure scenarios and corrective actions
- How to remove only the PoC schemas and pipeline safely

### 15.3 Repository README

Create or update `README.md` with:

- Purpose of the proof of concept
- Architecture summary
- File tree
- Prerequisites
- Steps to run pipeline and tests
- Expected target tables
- Links to the data product document and runbook
- Statement that all data is synthetic

---

## 16. Acceptance Criteria

The proof of concept is complete only when:

1. Required schemas and tables are created.
2. Synthetic source data includes valid and intentionally invalid orders.
3. Bronze retains all source records.
4. Silver retains only valid deduplicated orders.
5. Invalid orders appear in quarantine with explicit reasons.
6. Gold contains daily completed-order revenue by sales channel.
7. The Lakeflow pipeline completes successfully.
8. All SQL tests return zero rows.
9. Gold and silver revenue reconcile within 0.01.
10. Documentation and validation SQL are complete.
11. A final report is provided.

---

## 17. Final Report

After implementation, provide:

1. Workspace and capability findings
2. Files created or changed
3. Schemas and tables created
4. Pipeline name and execution result
5. Row counts for bronze, silver, quarantine, and gold
6. Quarantine counts by reason
7. Test results
8. Revenue-reconciliation result
9. Assumptions, limitations, or deviations
10. Exact steps to rerun or delete the proof of concept

---

## 18. Genie Code Instructions

### Phase 1: Plan only

1. Read this specification.
2. Inspect the workspace, repository, Unity Catalog access, and Lakeflow
   capabilities.
3. Confirm that `poc_spd` can be used.
4. Check whether an active Lakeflow pipeline already exists that could conflict
   with this proof of concept.
5. Provide the plan, file tree, assumptions, and prerequisites.
6. Stop and wait for explicit approval.

### Phase 2: Build only after approval

After explicit approval:

1. Create the required source files and documentation.
2. Generate synthetic orders.
3. Create and run the pipeline.
4. Create bronze, silver, quarantine, and gold tables.
5. Run validation queries.
6. Run all SQL tests.
7. Fix any implementation defects.
8. Produce the final report.

### Safety rules

- Do not create assets outside `poc_spd`.
- Do not use external or real data.
- Do not create a recurring schedule.
- Do not weaken a quality rule or test to obtain a passing result.
- Do not silently replace unavailable resources.
- Stop and ask for a decision if required capability or permission is missing.