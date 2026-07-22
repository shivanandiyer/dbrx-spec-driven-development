# Mine Safety Performance Data Product
## Spec-Driven Development Reference Build

**Platform:** Databricks
**Implementation assistant:** Genie Code
**Purpose:** Demonstrate spec-driven development end-to-end — a real public
dataset, a Lakeflow pipeline, governed bronze/silver/gold tables, automated
tests, and an interactive Databricks App
**Data classification:** Public, real, non-personal, non-PII, aggregated
safety data
**Execution mode:** Manual
**Catalog:** `mining_safety` (confirm availability in the approval gate;
propose an alternative if unavailable — do not substitute silently)
**Version:** 1.0

---

## 1. Goal

Give mine operators, safety regulators, and industry analysts a trusted,
governed view of mine safety performance across Queensland — turning
publicly reported site-level safety data into a clean, reconciled data
product that can be queried with confidence and explored without writing
SQL.

The data product replaces manual, spreadsheet-based reporting with a
governed pipeline that consistently applies the same validation rules to
every reporting period, flags and explains any data-quality exceptions
rather than silently dropping them, and surfaces trusted metrics — total
hours worked, lost time injuries, high potential incidents, and Lost Time
Injury Frequency Rate (LTIFR) — by mine site, sector, and reporting period.

This build also serves as a reference implementation of a spec-driven
delivery approach: a written specification drives the data model, pipeline,
quality checks, tests, and a self-service application, so the same pattern
can be extended to additional safety datasets, jurisdictions, or a
production-scale rollout with minimal rework.

---

## 2. Data Source

**Source:** Resources Safety & Health Queensland (RSHQ), published via the
Queensland Government Open Data Portal (`data.qld.gov.au`), linked from
`business.qld.gov.au` → *Safety performance reports and statistics*.

**Dataset:** *Safety performance of individual mine sites* (with the
*Qld quarterly mines and quarries safety statistics* dataset as a fallback),
covering financial years 2018–19 onward, published per mine category:
surface coal, underground coal, surface minerals, underground minerals,
quarries.

**Format:** CSV/XLS, downloadable without authentication.

**Licence:** Queensland Government open data licence (typically CC BY 4.0) —
confirm exact terms during Phase 1 and record them in the documentation.

**Why this dataset:**

- Real, public, and compact enough to build and validate quickly.
- Row grain (mine site × reporting period) maps naturally onto a
  fact-table pattern.
- Has genuine data-quality characteristics worth validating for real,
  rather than relying on injected synthetic errors.

**Important note:** this build uses real downloaded data, not a synthetic
generator. Exact column names, types, and data-quality issues are confirmed
by profiling the actual file in Phase 1. Section 6 lists the expected schema
based on published metadata; Genie Code must validate and adjust it against
the real file before building anything downstream, and report any
deviations.

---

## 3. Scope

### In scope

- One or more RSHQ mine safety performance source files (one commodity
  category is sufficient; combining two or three is acceptable if the result
  stays lightweight)
- One bronze table
- One silver table plus one quarantine table
- One gold table
- One Lakeflow Spark Declarative Pipeline
- Data quality and quarantine handling based on real data profiling
- Three SQL test files
- One validation SQL file
- One Databricks App (interactive query and filter tool over the gold table)
- Product documentation

### Out of scope

- Multiple unrelated source systems
- Multiple pipelines
- Streaming
- Jobs or schedules
- Asset Bundles
- Complex security models or row-level access control
- Any personal or worker-identifiable data (none exists in this dataset —
  RSHQ publishes site/period aggregates only)
- Cross-workspace deployment
- Custom authentication in the App beyond the Databricks Apps default pattern

---

## 4. Approval Gate

Before creating any files, tables, schemas, pipeline assets, or the app:

1. Inspect the workspace and repository context.
2. Confirm whether the `mining_safety` catalog is available; if not, ask
   which catalog to use — do not substitute silently.
3. Confirm whether a Lakeflow Spark Declarative Pipeline can be created, and
   whether Databricks Apps are enabled on this workspace/edition.
4. Confirm there is no conflicting active pipeline or app of the same name.
5. Download and profile the actual RSHQ source file(s): real column names,
   types, row counts, null rates, distinct category values, and any
   data-quality issues.
6. Reconcile the profiled schema against Section 6 and note any differences.
7. Produce:
   - A short implementation plan
   - A proposed file tree
   - The confirmed/adjusted source schema
   - Assumptions and prerequisites
8. Stop and wait for explicit approval.

---

## 5. Target Objects

| Purpose | Location |
|---|---|
| Catalog | `mining_safety` |
| Bronze schema | `mining_safety.bronze` |
| Silver schema | `mining_safety.silver` |
| Gold schema | `mining_safety.gold` |

Create these managed Delta tables:

```text
mining_safety.bronze.site_safety_events

mining_safety.silver.site_safety_performance
mining_safety.silver.site_safety_quarantine

mining_safety.gold.safety_performance_by_period
```

Create one Lakeflow pipeline named:

```text
mine-safety-performance-pipeline
```

Create one Databricks App named:

```text
mine-safety-performance-explorer
```

---

## 6. Business Definitions

### Mine site safety record

One row represents one mine site's reported safety performance for one
reporting period (financial year, or financial-year quarter if that is the
grain of the chosen file).

### Lost Time Injury (LTI)

An injury or disease that results in the injured worker being unable to
attend work for one full shift or more.

### LTIFR (Lost Time Injury Frequency Rate)

```text
LTIFR = (lost_time_injuries / hours_worked) * 1,000,000
```

### High Potential Incident (HPI)

An event, or series of events, that caused or had the potential to cause a
significant adverse effect on the safety or health of a person, without
necessarily resulting in an injury.

### Sector / mine category

One of: `SURFACE_COAL`, `UNDERGROUND_COAL`, `SURFACE_MINERALS`,
`UNDERGROUND_MINERALS`, `QUARRIES` (normalize the real source labels to this
set during silver validation; confirm exact source labels in Phase 1).

---

## 7. Expected Source Schema (confirm and adjust in Phase 1)

Based on published RSHQ metadata, the source is expected to contain
approximately these fields. Treat this as a working hypothesis — Genie Code
must replace it with the real profiled schema before building anything
downstream.

| Column (expected) | Type | Notes |
|---|---|---|
| mine_site_name | STRING | Name of the reporting mine/quarry site |
| sector | STRING | Coal/minerals/quarries, surface/underground |
| reporting_period | STRING | Financial year, e.g. `2023-24` |
| hours_worked | DOUBLE/BIGINT | Total hours worked at the site in the period |
| lost_time_injuries | INT | Count of LTIs in the period |
| high_potential_incidents | INT | Count of HPIs in the period |
| average_employees | INT | Average workforce at the site (may not be present) |

If the real file differs materially (different grain, different metrics,
wide/pivoted layout instead of long/tidy), stop and report the difference
before proceeding — do not silently reshape business meaning.

### 7.1 Known real-world data-quality issues to check for

Because this is real government-published data, profile for (report what is
actually found rather than assuming all are present):

- Small counts suppressed or blanked for privacy (common in official
  statistics)
- Zero or missing `hours_worked` for sites that closed mid-period
- Inconsistent sector/category labels across files or years
- Duplicate site rows across overlapping file versions
- Merged/renamed mine sites across periods

Validate against the rules in Section 9 and quarantine whatever genuinely
fails, even if that number is small or zero. If quarantine ends up empty,
state that plainly in the final report rather than manufacturing failures.

---

## 8. Bronze Layer

Create:

```text
mining_safety.bronze.site_safety_events
```

The bronze table must preserve all source records exactly as downloaded,
including any duplicates or malformed rows.

Append these metadata columns:

| Column | Type | Rule |
|---|---|---|
| _ingested_at | TIMESTAMP | UTC timestamp |
| _source_system | STRING | Always `rshq_open_data` |
| _source_url | STRING | The exact URL/file downloaded |
| _record_hash | STRING | Deterministic hash of source business fields |

Requirements:

- Retain every source record.
- Add a descriptive table comment noting the real source, licence, and
  download date.
- Add column comments where supported.
- Ensure metadata columns are non-null.
- Use a managed Delta table.

---

## 9. Silver Layer

Create:

```text
mining_safety.silver.site_safety_performance
mining_safety.silver.site_safety_quarantine
```

### 9.1 Curated silver table

Contains only valid, deduplicated site/period records, using the confirmed
real schema from Phase 1. Validation rules (adjust field names to the real
schema, keep the intent):

1. `mine_site_name` is non-null.
2. `sector` maps to one of the five normalized sector values.
3. `reporting_period` is non-null and matches a recognizable financial-year
   pattern.
4. `hours_worked >= 0` (zero allowed — a closed site is valid; negative is
   not).
5. `lost_time_injuries >= 0`.
6. `high_potential_incidents >= 0`, if present in the real file.
7. If `hours_worked = 0`, `lost_time_injuries` must also be `0`
   (an injury cannot be recorded against zero worked hours) — flag violations
   to quarantine.

Deduplication rule:

- Business key: `mine_site_name` + `sector` + `reporting_period`.
- For duplicates, retain the most recently ingested record
  (`_ingested_at` latest), and note the collision in documentation.

### 9.2 Quarantined records

Preserve source columns plus:

```text
quarantine_reason
_quarantined_at
```

Requirements:

- Do not silently drop invalid records.
- `quarantine_reason` must explain why the record was rejected; combine
  multiple reasons in one readable field if more than one rule fails.
- Add a descriptive table comment.
- It is acceptable for this table to contain few or zero rows, given real
  government data is generally already curated — report the actual count
  honestly rather than treating "zero quarantined rows" as a failure.

---

## 10. Gold Layer

Create:

```text
mining_safety.gold.safety_performance_by_period
```

Grain:

```text
One row per reporting_period and sector
```

Required columns:

| Column | Type | Rule |
|---|---|---|
| reporting_period | STRING | Financial year |
| sector | STRING | Normalized sector value |
| site_count | BIGINT | Distinct mine sites reporting in the period |
| total_hours_worked | DOUBLE | Sum of hours worked |
| total_lost_time_injuries | BIGINT | Sum of LTIs |
| total_high_potential_incidents | BIGINT | Sum of HPIs, if available |
| ltifr | DOUBLE | `(total_lost_time_injuries / total_hours_worked) * 1,000,000` |
| product_updated_at | TIMESTAMP | UTC timestamp |

Rules:

- Built only from curated silver records.
- `ltifr` must be null (not a divide-by-zero error) when
  `total_hours_worked = 0`.
- All counts and sums must be non-negative.
- Add a descriptive table comment and column comments where supported.

Apply these tags to the gold table if supported:

| Tag | Value |
|---|---|
| data_product | mine_safety_performance |
| layer | gold |
| classification | public |
| contains_pii | false |

---

## 11. Pipeline Requirements

Create one Lakeflow Spark Declarative Pipeline named:

```text
mine-safety-performance-pipeline
```

Logical stages:

```text
Source file download / profiling
        |
        v
Bronze ingestion
        |
        v
Silver validation, deduplication, and quarantine
        |
        v
Gold safety performance aggregation
```

Requirements:

- Use SQL where practical.
- Use Python only for file download and initial parsing (CSV/XLS) if
  required, and keep it deterministic given a fixed source file/date.
- Keep the pipeline lightweight and easy to reason about.
- No schedule — manual execution only.
- Use pipeline expectations where supported for observability.
- Preserve invalid records through explicit quarantine logic.
- Run the pipeline after implementation.
- If it fails, inspect the error and correct the code rather than weakening
  requirements.

---

## 12. Databricks App — Interactive Query Tool

Create one Databricks App named:

```text
mine-safety-performance-explorer
```

### 12.1 Purpose

A read-only interactive tool that lets a user filter and explore
`mining_safety.gold.safety_performance_by_period` without writing SQL.

### 12.2 Functional requirements

- Filters (as UI controls, not free-text SQL):
  - `reporting_period` (multi-select or range)
  - `sector` (multi-select)
  - Minimum `total_hours_worked` (numeric threshold, to exclude near-empty
    periods if desired)
- Results view:
  - A filtered table of matching gold rows
  - A chart of `ltifr` by `reporting_period`, split by `sector`
  - Summary tiles: total sites, total hours worked, total LTIs, blended
    LTIFR for the current filter selection
- Read-only: the app must never write to any table.
- Query the gold table via a Databricks SQL warehouse connection (a small
  serverless SQL warehouse is sufficient); do not embed static/frozen data
  in the app.

### 12.3 Technical requirements

- Build with Streamlit (or Dash, whichever Genie Code confirms is best
  supported for Databricks Apps in this workspace).
- Use the workspace's built-in Databricks Apps authentication pattern (app
  service principal or on-behalf-of-user auth) to reach the SQL warehouse —
  do not hardcode credentials.
- Keep it to a single page; no multi-page navigation needed.
- Deploy manually via the Databricks Apps UI or CLI; no CI/CD.
- Document the exact deploy command/steps in the runbook.

### 12.4 Safety rules for the app

- No destructive actions available anywhere in the UI.
- No PII is queried or displayed (none exists in this dataset).
- If the SQL warehouse or gold table is unavailable, show a clear error
  state rather than crashing silently.

---

## 13. Quality Checks

Implement pipeline expectations where supported and standalone SQL tests for:

### Bronze checks

- Bronze table contains more than zero rows.
- `_ingested_at`, `_source_system`, `_record_hash` are non-null.

### Silver checks

- Curated business key (`mine_site_name` + `sector` + `reporting_period`) is
  unique.
- Sector values are within the normalized set.
- `hours_worked >= 0`, `lost_time_injuries >= 0`.
- Zero-hours periods have zero LTIs.
- Quarantine reason is non-null wherever a quarantine row exists.

### Gold checks

- `reporting_period` and `sector` are non-null.
- All numeric columns are non-negative.
- `ltifr` is null (not error/NaN) when `total_hours_worked = 0`, and
  correctly computed otherwise.
- Gold totals reconcile to curated silver totals within 0.01.

---

## 14. Repository Structure

```text
.
├── specs/
│   └── mine-safety-performance.md
├── src/
│   └── mine_safety_performance/
│       ├── 00_download_source.py
│       ├── 10_bronze.sql
│       ├── 20_silver.sql
│       ├── 30_gold.sql
│       └── validation.sql
├── app/
│   └── mine_safety_performance_explorer/
│       ├── app.py
│       ├── app.yaml
│       └── requirements.txt
├── tests/
│   └── mine_safety_performance/
│       ├── README.md
│       ├── test_silver_quality.sql
│       ├── test_gold_reconciliation.sql
│       └── test_data_contract.sql
├── docs/
│   └── mine_safety_performance/
│       ├── data-product.md
│       └── runbook.md
└── README.md
```

---

## 15. Test Requirements

### 15.1 `tests/mine_safety_performance/test_silver_quality.sql`

Test: duplicate business keys, invalid sector values, negative hours/LTIs,
zero-hours-with-nonzero-LTI violations, empty quarantine-reason values.

### 15.2 `tests/mine_safety_performance/test_gold_reconciliation.sql`

Test: negative gold values, LTIFR arithmetic and null-on-zero-hours
handling, gold-to-silver total reconciliation, null reporting periods.

### 15.3 `tests/mine_safety_performance/test_data_contract.sql`

Test: required tables exist, required columns exist, gold tags/comments
exist if supported.

### 15.4 Test standard

Each test must use fully qualified table names, return zero rows when
passing, return diagnostic rows with a `failure_reason` field when failing,
start with an explanatory comment block, and run independently in the SQL
editor.

Create `tests/mine_safety_performance/README.md` explaining how to run each
test.

---

## 16. Validation Queries

Create `src/mine_safety_performance/validation.sql`, returning:

1. Row counts for bronze, silver, quarantine, and gold.
2. Quarantine counts by reason.
3. Ten sample curated records.
4. Ten sample gold records.
5. Total curated LTIs and hours worked.
6. Total gold LTIs and hours worked.
7. The difference between silver and gold totals.
8. LTIFR trend by sector across periods.

---

## 17. Documentation

### 17.1 Data product document (`docs/mine_safety_performance/data-product.md`)

Include: purpose, owner, real source name/URL/licence, table inventory, gold
grain, metric definitions, data-quality/quarantine design, lineage
(`RSHQ source file -> bronze -> silver -> gold`), two example consumer SQL
queries, and limitations (e.g. suppressed small counts, sector label
normalization assumptions).

### 17.2 Runbook (`docs/mine_safety_performance/runbook.md`)

Include: prerequisites, how to re-download the source file, how to run the
pipeline, how to run tests, how to inspect quarantined records, how to
deploy and run the Databricks App, common failure scenarios, and how to
remove the environment (schemas, pipeline, app) safely.

### 17.3 Repository README

Purpose, architecture summary, file tree, prerequisites, steps to run
pipeline/tests/app, expected target tables, links to the data product doc
and runbook, and a statement that all data is real, public, and
non-personal, with the source and licence named explicitly.

---

## 18. Acceptance Criteria

1. Required schemas and tables are created.
2. Real source data is downloaded and profiled; actual schema documented.
3. Bronze retains all source records.
4. Silver retains only valid deduplicated records.
5. Any genuinely invalid records appear in quarantine with explicit reasons
   (or quarantine is honestly reported as empty).
6. Gold contains safety performance by period and sector.
7. The Lakeflow pipeline completes successfully.
8. All SQL tests return zero rows.
9. Gold and silver totals reconcile within 0.01.
10. The Databricks App deploys, connects to the gold table, and its filters
    work as specified.
11. Documentation and validation SQL are complete.
12. A final report is provided.

---

## 19. Final Report

After implementation, provide:

1. Workspace and capability findings, including confirmed real source schema
2. Files created or changed
3. Schemas and tables created
4. Pipeline name and execution result
5. App name, deployment status, and access URL
6. Row counts for bronze, silver, quarantine, and gold
7. Quarantine counts by reason (or confirmation it's empty)
8. Test results
9. Reconciliation result (silver vs. gold totals)
10. Assumptions, limitations, or deviations from the expected schema in
    Section 7
11. Exact steps to rerun or remove the build

---

## 20. Genie Code Instructions

### Phase 1: Discover and plan only

1. Read this specification.
2. Inspect workspace, repo, Unity Catalog access, Lakeflow, and Databricks
   Apps capabilities.
3. Confirm `mining_safety` can be used.
4. Download the real RSHQ source file(s) and profile the actual schema
   against Section 7.
5. Check for conflicting pipelines or apps of the same name.
6. Provide the plan, file tree, confirmed schema, assumptions, and
   prerequisites.
7. Stop and wait for explicit approval.

### Phase 2: Build only after approval

1. Create source files, app, and documentation.
2. Ingest the real source data.
3. Create and run the pipeline.
4. Create bronze, silver, quarantine, and gold tables.
5. Deploy the Databricks App.
6. Run validation queries and all SQL tests.
7. Fix any implementation defects.
8. Produce the final report.

### Safety rules

- Do not create assets outside `mining_safety`.
- Do not use synthetic or fabricated data — only the real downloaded source.
- Do not create a recurring schedule.
- Do not weaken a quality rule or test to obtain a passing result.
- Do not silently replace unavailable resources or reshape the source schema
  without reporting the deviation.
- Do not display or store any personal/worker-identifiable data (none is
  expected in this source — flag immediately if any is found).
- Stop and ask for a decision if required capability or permission is
  missing.
