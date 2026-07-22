# Care Pathway Analytics Data Product
## Diagnosis-to-Treatment Pathway — Spec-Driven Development Reference Build

**Platform:** Databricks
**Implementation assistant:** Genie Code
**Purpose:** Turn HealthVerity claims data into a governed view of how quickly
patients move from diagnosis to treatment, and where they fall through the
cracks
**Data classification:** De-identified patient-level healthcare claims data
(HealthVerity Marketplace sample; treat as sensitive/regulated even though
de-identified — no re-identification attempts, no export outside the
workspace)
**Execution mode:** Manual
**Source catalog (read-only):** `healthverity_claims_sample_patient_dataset`
**Source schema:** `hv_claims_sample`
**Target catalog:** `patient_care_pathways` (confirm availability in the
approval gate; propose an alternative if unavailable — do not substitute
silently)
**Version:** 1.2 — pipeline/data-model only; interactive exploration moved
to the companion *Care Pathway Intelligence Agent* spec

---

## 1. Goal

Give clinical operations, care management, and market access teams a clear,
governed answer to a question that drives real decisions: **once a patient
is diagnosed with a chronic condition, how long does it take them to start
treatment — and how many never do?**

The data product turns raw medical, pharmacy, and enrollment claims into a
patient-level and cohort-level view of the diagnosis-to-treatment pathway:
time from first qualifying diagnosis to first pharmacological treatment,
time to first clinical follow-up/monitoring event, and a segmentation of
patients by how quickly they were treated. This is the kind of analysis that
underpins care-gap outreach programs, treatment-pathway variation studies,
and health economics and outcomes research (HEOR) — turning a claims feed
into a decision-ready cohort view rather than a pile of transactional
records.

This build also serves as a reference implementation of a spec-driven
delivery approach: a written specification drives the data model, pipeline,
quality checks, and tests, so the same pattern extends cleanly to
additional conditions, treatment definitions, or a production-scale claims
feed with minimal rework.

This is the first of two specs. This spec covers the pipeline and the gold
data model only. Once the gold tables here are built and passing their own
tests, a separate companion spec — *Care Pathway Intelligence Agent* —
configures a Genie Agent and dashboard on top of the resulting gold tables
for natural-language exploration. That second spec is executed only after
this one is complete.

---

## 2. Data Source

**Source:** HealthVerity Claims Sample Patient Dataset, accessed via
Databricks Marketplace, provisioned in Unity Catalog at
`healthverity_claims_sample_patient_dataset.hv_claims_sample`.

**Coverage:** 1,000+ de-identified patients, United States and Canada,
medical and pharmacy claims.

**Tables (confirmed via catalog inspection):** `diagnosis`, `enrollment`,
`medical_claim`, `pharmacy_claim`, `procedure`, `provider`. All join on
`patient_id`; `diagnosis`, `procedure`, and `provider` additionally carry
`claim_id`, which links back to `medical_claim` where header-level context
(place of care, pay type) is needed. Full confirmed column list is in
Section 7.

**Remaining unknowns to resolve in Phase 1 (the schema itself is now
confirmed, but two things that affect correctness are not yet known):**

1. What values `diagnosis.diagnosis_qual` and `procedure.procedure_qual`
   actually take, and which value(s) correspond to ICD-10-CM (for
   diagnoses) and CPT/HCPCS (for procedures). This determines how the
   condition and treatment code filters in Section 6 must be written —
   `diagnosis_code` and `procedure_code` are plain strings with no built-in
   code-system column, so the qualifier field is the only way to interpret
   them correctly.
2. There is **no drug/therapeutic-class reference table** in this schema —
   `pharmacy_claim.ndc` is a raw NDC string only. Classifying pharmacy
   claims into "relevant treatment for the study condition" therefore
   requires an external reference (e.g. the FDA NDC Directory), which must
   be sourced and loaded as part of this build, not assumed to already
   exist in the workspace.

---

## 3. Scope

### In scope

- Read access to the six HealthVerity source tables (as needed)
- One bronze schema materializing the relevant source slices into the
  target catalog for lineage and point-in-time reproducibility
- One silver schema: a validated, deduplicated patient care-pathway event
  model (diagnosis events, treatment events, enrollment spans)
- One gold schema: patient-level pathway metrics and a cohort segmentation
  summary
- One Lakeflow Spark Declarative Pipeline
- Data quality and quarantine handling based on real data profiling
- Three SQL test files
- One validation SQL file
- Product documentation

Interactive exploration of the gold tables (natural-language querying and a
dashboard) is handled by a separate companion spec, executed after this one
— see Section 1.

### Out of scope

- Multiple conditions or treatment definitions in v1 (single condition,
  single treatment definition — extensible later)
- Re-identification, linkage to any external PII source, or any attempt to
  narrow the cohort to identifiable individuals
- Streaming or continuously refreshing pipelines
- Jobs or schedules
- Asset Bundles
- Complex security models or row-level access control beyond standard Unity
  Catalog permissions
- Cross-workspace deployment
- Clinical validation of the condition/treatment code list by a licensed
  clinician (documented as an assumption, not performed as part of this
  build)

---

## 4. Approval Gate

Before creating any files, tables, schemas, or pipeline assets:

1. Inspect the workspace, repository context, and confirmed access to
   `healthverity_claims_sample_patient_dataset.hv_claims_sample`.
2. Confirm whether the `patient_care_pathways` catalog is available; if not,
   ask which catalog to use — do not substitute silently.
3. Confirm whether a Lakeflow Spark Declarative Pipeline can be created on
   this workspace.
4. Confirm there is no conflicting active pipeline of the same name.
5. Resolve the two open unknowns from Section 2:
   - Query `SELECT DISTINCT diagnosis_qual, COUNT(*) FROM diagnosis GROUP BY 1`
     and the equivalent for `procedure.procedure_qual`; map each observed
     value to a known code system (ICD-10-CM, ICD-9-CM, CPT, HCPCS) and
     record the mapping.
   - Confirm no drug/therapeutic-class reference exists in-catalog, then
     source an external NDC-to-therapeutic-class reference (e.g. the FDA
     NDC Directory) and confirm it can be loaded into the workspace.
   - Also capture row counts per table and null rates on key fields
     (`patient_id`, `date_service`, `diagnosis_code`, `ndc`,
     `procedure_code`, `enrollment.date_start`/`date_end`).
6. **Confirm the study cohort is viable before locking the condition:**
   - Default condition: Type 2 Diabetes Mellitus. Once the ICD-10-CM
     qualifier value is confirmed in step 5, filter `diagnosis_code` for
     `E11.*` under that qualifier.
   - Count distinct patients with at least one qualifying diagnosis claim.
   - If the cohort is too small to produce a meaningful segmentation (fewer
     than ~30–50 patients, at Genie Code's judgment), fall back to
     Hypertension (ICD-10-CM `I10`) or another sufficiently represented
     chronic condition, and report the substitution and reasoning.
7. Produce:
   - A short implementation plan
   - A proposed file tree
   - The confirmed/adjusted source schema and condition/treatment definition
   - Assumptions and prerequisites
8. Stop and wait for explicit approval.

---

## 5. Target Objects

| Purpose | Location |
|---|---|
| Source catalog (read-only) | `healthverity_claims_sample_patient_dataset` |
| Target catalog | `patient_care_pathways` |
| Bronze schema | `patient_care_pathways.bronze` |
| Silver schema | `patient_care_pathways.silver` |
| Gold schema | `patient_care_pathways.gold` |

Create these managed Delta tables:

```text
patient_care_pathways.bronze.diagnosis
patient_care_pathways.bronze.pharmacy_claim
patient_care_pathways.bronze.procedure
patient_care_pathways.bronze.enrollment
patient_care_pathways.bronze.ndc_reference

patient_care_pathways.silver.cohort_diagnosis_events
patient_care_pathways.silver.cohort_treatment_events
patient_care_pathways.silver.quarantined_events

patient_care_pathways.gold.patient_pathway_detail
patient_care_pathways.gold.pathway_segment_summary
```

Create one Lakeflow pipeline named:

```text
diagnosis-to-treatment-pathway-pipeline
```

---

## 6. Business Definitions

### Index diagnosis

A patient's **earliest qualifying diagnosis claim** for the study condition
within the available data window (default: Type 2 Diabetes, ICD-10-CM
`E11.*`; confirm code system in Phase 1). This date anchors the pathway.

### Pharmacological treatment event

The patient's **earliest pharmacy claim** for a drug in the condition's
relevant therapeutic class (default for Type 2 Diabetes: metformin,
insulin analogs, sulfonylureas, DPP-4 inhibitors, SGLT2 inhibitors, or GLP-1
agonists — confirm the exact NDC classification approach in Phase 1 per
Section 4.7), occurring on or after the index diagnosis date.

### Clinical follow-up / monitoring event

The patient's **earliest relevant procedure or lab claim** evidencing
ongoing clinical management of the condition (default for Type 2 Diabetes:
HbA1c test, CPT `83036`/`83037`), occurring on or after the index diagnosis
date.

### Time to treatment

```text
days_to_pharmacy_treatment = date(first pharmacy treatment event) - date(index diagnosis)
days_to_clinical_followup  = date(first clinical follow-up event) - date(index diagnosis)
```

### Observation window

The span from the patient's earliest enrollment start date to their latest
enrollment end date (or the latest `date_service` observed, if enrollment
end dates are open/ongoing). Used to distinguish "not yet treated" from
"treated, but we can't see it" (censoring).

### Censored patient

A patient with an index diagnosis but no qualifying treatment event
observed **before their observation window ends**. Reported separately from
"never treated" claims, since claims data cannot prove absence of treatment
outside the observed window.

### Pathway segment

Patients are bucketed by `days_to_pharmacy_treatment` into:
`SAME_DAY` (0), `WITHIN_30_DAYS`, `31_TO_90_DAYS`, `91_TO_180_DAYS`,
`OVER_180_DAYS`, `NOT_TREATED_CENSORED`. The same bucketing structure
applies independently to `days_to_clinical_followup`.

---

## 7. Confirmed Source Schema

Confirmed by direct catalog inspection of
`healthverity_claims_sample_patient_dataset.hv_claims_sample`. This
supersedes the earlier hypothesis — build against these column names and
types.

### 7.1 `diagnosis`

| Column | Type | Notes |
|---|---|---|
| claim_id | STRING | Links to `medical_claim.claim_id` |
| patient_id | STRING | Cohort key |
| date_service | DATE | Diagnosis service date |
| date_service_end | DATE | |
| diagnosis_code | STRING | Raw code, no embedded code-system marker |
| diagnosis_qual | STRING | Code-system qualifier — meaning to be confirmed in Phase 1 (Section 4, step 5) |
| admit_diagnosis_ind | STRING | Flags whether this is the institutional admitting diagnosis |

### 7.2 `enrollment`

| Column | Type | Notes |
|---|---|---|
| patient_id | STRING | Cohort key |
| patient_gender | STRING | Demographic — usable for gold-layer and dashboard segmentation |
| patient_year_of_birth | STRING | Demographic — used to derive an age band as of the index diagnosis date |
| patient_zip3 | STRING | First 3 digits of ZIP; low re-identification risk but still handle as sensitive |
| patient_state | STRING | Demographic — usable for gold-layer and dashboard segmentation |
| date_start | DATE | Enrollment span start |
| date_end | DATE | Enrollment span end (may be open/ongoing — confirm how open spans are represented) |
| benefit_type | STRING | |
| pay_type | STRING | |

### 7.3 `medical_claim` (not materialized in v1 — see Section 8)

| Column | Type | Notes |
|---|---|---|
| claim_id | STRING | Claim header key |
| patient_id | STRING | |
| date_service | DATE | |
| date_service_end | DATE | |
| location_of_care | STRING | |
| pay_type | STRING | |

### 7.4 `pharmacy_claim`

| Column | Type | Notes |
|---|---|---|
| claim_id | STRING | |
| patient_id | STRING | Cohort key |
| date_service | DATE | Fill date |
| ndc | STRING | Raw NDC — no in-source therapeutic class; see `ndc_reference` in Section 8 |
| fill_number | INT | 0 = original fill, 1+ = refill |
| days_supply | INT | |
| dispensed_quantity | FLOAT | |
| pay_type | STRING | |
| copay_coinsurance | FLOAT | Not used in v1 (no cost analysis in scope) |
| submitted_gross_due | FLOAT | Not used in v1 |
| paid_gross_due | FLOAT | Not used in v1 |

### 7.5 `procedure`

| Column | Type | Notes |
|---|---|---|
| claim_id | STRING | |
| patient_id | STRING | Cohort key |
| service_line_number | STRING | |
| date_service | DATE | |
| date_service_end | DATE | |
| procedure_code | STRING | Raw code, no embedded code-system marker |
| procedure_qual | STRING | Code-system qualifier — meaning to be confirmed in Phase 1 (Section 4, step 5) |
| procedure_units | FLOAT | |
| procedure_modifier1–4 | STRING | Not used in v1 |
| revenue_code | STRING | Not used in v1 |
| line_charge | FLOAT | Not used in v1 (no cost analysis in scope) |
| line_allowed | FLOAT | Not used in v1 |

### 7.6 `provider` (not materialized in v1 — see Section 8)

| Column | Type | Notes |
|---|---|---|
| claim_id | STRING | |
| patient_id | STRING | |
| npi | STRING | |
| npi_role | STRING | |
| taxonomy_code | STRING | Provider specialty — could support a future "specialist vs. generalist first-treater" cut |

### 7.7 Known real-world data-quality issues to check for

- Multiple diagnosis or procedure claim lines per patient per day (repeat
  billing) — deduplicate to the earliest qualifying event, not every claim
  line.
- `diagnosis_qual` or `procedure_qual` values that don't map cleanly to a
  known code system — quarantine rather than guessing.
- Pharmacy claims with missing or malformed `ndc` values, or NDCs not found
  in the external reference table.
- Enrollment gaps (a patient disenrolling and re-enrolling) — do not assume
  continuous enrollment; `date_end` may also represent an open/ongoing span
  rather than a true end date — confirm which in Phase 1.
- Patients with treatment events **before** any qualifying diagnosis claim
  in the data (pre-existing condition not captured at claims start) — these
  should be flagged via `pre_index_treatment_flag`, not silently included as
  "same-day" treatment.

Validate against the rules in Section 9 and quarantine whatever genuinely
fails, even if that number is small. If quarantine ends up empty, state that
plainly in the final report rather than manufacturing failures.

---

## 8. Bronze Layer

Create:

```text
patient_care_pathways.bronze.diagnosis
patient_care_pathways.bronze.pharmacy_claim
patient_care_pathways.bronze.procedure
patient_care_pathways.bronze.enrollment
patient_care_pathways.bronze.ndc_reference
```

The first four materialize the full set of columns from the corresponding
`hv_claims_sample` source table (see Section 7 for the confirmed column
list) into the target catalog, preserving all source records including
duplicates or malformed rows. `medical_claim` and `provider` are not
materialized in v1 since the pathway logic doesn't require them; add them
later if a use case needs claim-header or provider context.

`ndc_reference` is new relative to the source: it loads the external
NDC-to-therapeutic-class reference confirmed in the approval gate (Section
4, step 5) so pharmacy claims can be classified without a reference table
existing in the source itself. Document its exact origin, version/download
date, and licence in the data product documentation.

Append these metadata columns to each of the four claims-sourced bronze
tables:

| Column | Type | Rule |
|---|---|---|
| _ingested_at | TIMESTAMP | UTC timestamp |
| _source_system | STRING | Always `healthverity_marketplace` |
| _source_table | STRING | Fully qualified name of the source table read |
| _record_hash | STRING | Deterministic hash of source business fields |

Requirements:

- Retain every matching source record.
- Add a descriptive table comment noting the real source, licence/usage
  terms, and materialization date.
- Add column comments where supported.
- Ensure metadata columns are non-null.
- Use managed Delta tables.

---

## 9. Silver Layer

Create:

```text
patient_care_pathways.silver.cohort_diagnosis_events
patient_care_pathways.silver.cohort_treatment_events
patient_care_pathways.silver.quarantined_events
```

### 9.1 Cohort diagnosis events

Filtered to patients with at least one qualifying diagnosis code for the
study condition. Validation rules:

1. `patient_id` is non-null.
2. `diagnosis_qual` matches the code system confirmed in Phase 1 as
   ICD-10-CM, and `diagnosis_code` matches the study condition's code
   pattern (default `E11.*` for Type 2 Diabetes).
3. `date_service` is non-null and parses to a valid date.
4. Deduplicate to one row per `patient_id` per `date_service` per
   `diagnosis_code` (collapse repeat claim lines).

### 9.2 Cohort treatment events

Contains both pharmacological treatment events and clinical follow-up
events (tagged by `event_type`) for patients in the diagnosis cohort.
Validation rules:

1. `patient_id` is non-null and present in the diagnosis cohort.
2. `date_service` is non-null and parses to a valid date.
3. For pharmacy events: `ndc` is non-null and joins successfully to
   `bronze.ndc_reference` into one of the condition's relevant therapeutic
   classes (Section 6).
4. For clinical follow-up events: `procedure_qual` matches the code system
   confirmed in Phase 1 as CPT/HCPCS, and `procedure_code` matches the
   condition's relevant procedure code list (default `83036`/`83037` for
   HbA1c, Type 2 Diabetes).
5. Deduplicate to one row per `patient_id` per `date_service` per
   `event_type` per code.

### 9.3 Quarantined events

Preserve source columns plus:

```text
quarantine_reason
_quarantined_at
```

Requirements:

- Do not silently drop invalid or unparseable records.
- `quarantine_reason` must explain why the record was rejected; combine
  multiple reasons in one readable field if more than one rule fails.
- Add a descriptive table comment.
- Report the actual quarantine count honestly, including if it is zero.

---

## 10. Gold Layer

### 10.1 Patient pathway detail

```text
patient_care_pathways.gold.patient_pathway_detail
```

Grain: **one row per patient** in the study cohort.

| Column | Type | Rule |
|---|---|---|
| patient_id | STRING | Cohort patient identifier |
| patient_gender | STRING | From `enrollment.patient_gender` |
| patient_age_band | STRING | Derived from `enrollment.patient_year_of_birth` relative to `index_diagnosis_date` (e.g. `18-34`, `35-49`, `50-64`, `65+`) |
| patient_state | STRING | From `enrollment.patient_state` |
| index_diagnosis_date | DATE | Earliest qualifying diagnosis date |
| observation_start_date | DATE | Earliest enrollment/claim date observed |
| observation_end_date | DATE | Latest enrollment/claim date observed |
| first_pharmacy_treatment_date | DATE | Nullable — earliest qualifying pharmacy claim on/after index date |
| days_to_pharmacy_treatment | INT | Nullable — see Section 6 |
| pharmacy_pathway_segment | STRING | One of the segment buckets in Section 6 |
| first_clinical_followup_date | DATE | Nullable — earliest qualifying procedure/lab claim on/after index date |
| days_to_clinical_followup | INT | Nullable — see Section 6 |
| followup_pathway_segment | STRING | One of the segment buckets in Section 6 |
| pre_index_treatment_flag | BOOLEAN | True if a treatment event was observed before the index diagnosis date |
| product_updated_at | TIMESTAMP | UTC timestamp |

### 10.2 Pathway segment summary

```text
patient_care_pathways.gold.pathway_segment_summary
```

Grain: **one row per pathway type and segment bucket**
(`pharmacy_pathway_segment` or `followup_pathway_segment`).

| Column | Type | Rule |
|---|---|---|
| pathway_type | STRING | `PHARMACY` or `CLINICAL_FOLLOWUP` |
| segment | STRING | One of the segment buckets in Section 6 |
| patient_count | BIGINT | Count of patients in this segment |
| pct_of_cohort | DOUBLE | `patient_count / total cohort patients`, 0–1 |
| product_updated_at | TIMESTAMP | UTC timestamp |

Rules for both gold tables:

- Built only from curated silver records.
- All counts and day-differences must be non-negative (except where
  `pre_index_treatment_flag` explains a negative raw gap, which must not
  appear as a negative `days_to_*` value — route those to
  `pre_index_treatment_flag = true` with `days_to_*` set to null instead).
- `pct_of_cohort` values across all segments for a given `pathway_type` must
  sum to 1.0 within 0.01.
- Add descriptive table and column comments where supported.

Apply these tags to both gold tables if supported:

| Tag | Value |
|---|---|
| data_product | care_pathway_analytics |
| layer | gold |
| classification | de_identified_claims |
| contains_pii | false |

---

## 11. Pipeline Requirements

Create one Lakeflow Spark Declarative Pipeline named:

```text
diagnosis-to-treatment-pathway-pipeline
```

Logical stages:

```text
Source profiling & cohort confirmation (Phase 1, one-time)
        |
        v
Bronze materialization (diagnosis, pharmacy, procedure, enrollment slices)
        |
        v
Silver cohort construction, validation, and quarantine
        |
        v
Gold pathway metrics and segment summary
```

Requirements:

- Use SQL where practical.
- Use Python only where set-based SQL is impractical (e.g. NDC/code
  classification lookups against a reference list), and keep logic
  deterministic.
- Keep the pipeline lightweight and easy to reason about.
- No schedule — manual execution only.
- Use pipeline expectations where supported for observability.
- Preserve invalid records through explicit quarantine logic.
- Run the pipeline after implementation.
- If it fails, inspect the error and correct the code rather than weakening
  requirements.

---

## 12. Quality Checks

Implement pipeline expectations where supported and standalone SQL tests
for:

### Bronze checks

- Each bronze table contains more than zero rows.
- `_ingested_at`, `_source_system`, `_source_table`, `_record_hash` are
  non-null.

### Silver checks

- Cohort diagnosis events: `patient_id` + `date_service` + `diagnosis_code`
  combination is unique after deduplication.
- Cohort treatment events: `patient_id` + `date_service` + `event_type` +
  code combination is unique after deduplication.
- No treatment event in the cohort tables belongs to a `patient_id` absent
  from the diagnosis cohort.
- Quarantine reason is non-null wherever a quarantine row exists.

### Gold checks

- Every patient in `patient_pathway_detail` has a non-null
  `index_diagnosis_date`.
- No negative `days_to_pharmacy_treatment` or `days_to_clinical_followup`
  values.
- `pharmacy_pathway_segment` and `followup_pathway_segment` are always one
  of the defined bucket values.
- `pathway_segment_summary.pct_of_cohort` sums to 1.0 (± 0.01) within each
  `pathway_type`.
- `patient_pathway_detail` patient count matches the sum of
  `pathway_segment_summary.patient_count` for each `pathway_type`.

---

## 13. Repository Structure

```text
.
├── specs/
│   └── care-pathway-analytics.md
├── src/
│   └── care_pathway_analytics/
│       ├── 00_profile_and_confirm_cohort.py
│       ├── 10_bronze.sql
│       ├── 20_silver.sql
│       ├── 30_gold.sql
│       └── validation.sql
├── tests/
│   └── care_pathway_analytics/
│       ├── README.md
│       ├── test_silver_quality.sql
│       ├── test_gold_reconciliation.sql
│       └── test_data_contract.sql
├── docs/
│   └── care_pathway_analytics/
│       ├── data-product.md
│       └── runbook.md
└── README.md
```

---

## 14. Test Requirements

### 14.1 `tests/care_pathway_analytics/test_silver_quality.sql`

Test: duplicate diagnosis/treatment event keys, treatment events for
patients outside the diagnosis cohort, null diagnosis or treatment codes,
malformed dates, empty quarantine-reason values.

### 14.2 `tests/care_pathway_analytics/test_gold_reconciliation.sql`

Test: negative days-to-treatment values, invalid segment bucket values,
`pct_of_cohort` totals per pathway type, patient-count reconciliation
between the two gold tables, null index diagnosis dates.

### 14.3 `tests/care_pathway_analytics/test_data_contract.sql`

Test: required tables exist, required columns exist, gold tags/comments
exist if supported.

### 14.4 Test standard

Each test must use fully qualified table names, return zero rows when
passing, return diagnostic rows with a `failure_reason` field when failing,
start with an explanatory comment block, and run independently in the SQL
editor.

Create `tests/care_pathway_analytics/README.md` explaining how to run each
test.

---

## 15. Validation Queries

Create `src/care_pathway_analytics/validation.sql`, returning:

1. Row counts for each bronze, silver, quarantine, and gold table.
2. Quarantine counts by reason.
3. Cohort size (distinct patients with an index diagnosis).
4. Ten sample patient-level pathway records.
5. Full `pathway_segment_summary` output for both pathway types.
6. Median and mean days-to-treatment for each pathway type.
7. Count and % of patients flagged `pre_index_treatment_flag = true`.
8. Count and % of patients in the `NOT_TREATED_CENSORED` segment for each
   pathway type.

---

## 16. Documentation

### 16.1 Data product document (`docs/care_pathway_analytics/data-product.md`)

Include: purpose, owner, source (HealthVerity Claims Sample Patient Dataset
via Databricks Marketplace, with usage terms noted), table inventory, gold
grain for both gold tables, metric definitions (Section 6), the exact
condition and treatment code lists used, data-quality/quarantine design,
lineage (`HealthVerity source -> bronze -> silver -> gold`), two example
consumer SQL queries, limitations (sample-size caveats, code-list
assumptions, no clinical validation of the treatment definition, censoring
caveats), and a note that the companion *Care Pathway Intelligence Agent*
spec is the next step once this build is complete.

### 16.2 Runbook (`docs/care_pathway_analytics/runbook.md`)

Include: prerequisites and required Marketplace access, how to run the
pipeline, how to run tests, how to inspect quarantined records, common
failure scenarios, and how to remove the environment (schemas and pipeline)
safely.

### 16.3 Repository README

Purpose, architecture summary, file tree, prerequisites, steps to run the
pipeline and tests, expected target tables, links to the data product doc
and runbook, a note that the companion Genie Agent spec runs next, and a
clear statement that all patient data is de-identified, sourced under
HealthVerity's Marketplace terms, and used for demonstration purposes only.

---

## 17. Acceptance Criteria

1. Required schemas and tables are created.
2. Real source tables are profiled; actual schema and code systems
   documented; cohort viability confirmed before condition lock-in.
3. Bronze materializes the relevant source slices for the study cohort.
4. Silver contains only valid, deduplicated diagnosis and treatment events
   tied to cohort patients.
5. Any genuinely invalid records appear in quarantine with explicit reasons
   (or quarantine is honestly reported as empty).
6. Gold contains patient-level pathway detail and a segment summary that
   reconciles to it.
7. The Lakeflow pipeline completes successfully.
8. All SQL tests return zero rows.
9. Gold patient counts and segment percentages reconcile within 0.01.
10. Documentation and validation SQL are complete.
11. A final report is provided.
12. The companion *Care Pathway Intelligence Agent* spec is ready to
    execute against the resulting gold tables.

---

## 18. Final Report

After implementation, provide:

1. Workspace and capability findings, including the confirmed real source
   schema and final condition/treatment definition used
2. Files created or changed
3. Schemas and tables created
4. Pipeline name and execution result
5. Row counts for bronze, silver, quarantine, and both gold tables
6. Quarantine counts by reason (or confirmation it's empty)
7. Test results
8. Reconciliation results (silver vs. gold, and between the two gold tables)
9. Cohort size and headline pathway metrics (median days to treatment,
   % never treated within the observation window)
10. Assumptions, limitations, or deviations from Section 7/Section 6
11. Exact steps to rerun or remove the build
12. Confirmation that the gold tables are ready for the companion *Care
    Pathway Intelligence Agent* spec

---

## 19. Genie Code Instructions

### Phase 1: Discover and plan only

1. Read this specification.
2. Inspect workspace, repo, and Unity Catalog access to
   `healthverity_claims_sample_patient_dataset` and Lakeflow capabilities.
3. Confirm `patient_care_pathways` can be used as the target catalog.
4. Profile the real source tables and confirm the cohort per Section 4.5–4.6.
5. Check for conflicting pipelines of the same name.
6. Provide the plan, file tree, confirmed schema, confirmed condition and
   treatment definition, assumptions, and prerequisites.
7. Stop and wait for explicit approval.

### Phase 2: Build only after approval

1. Create source files and documentation.
2. Materialize the bronze layer from the source Marketplace tables.
3. Create and run the pipeline.
4. Create bronze, silver, quarantine, and gold tables.
5. Run validation queries and all SQL tests.
6. Fix any implementation defects.
7. Produce the final report, confirming readiness for the companion Genie
   Agent spec.

### Safety rules

- Do not create assets outside `patient_care_pathways` (other than the
  required read-only access to the source Marketplace catalog).
- Do not attempt to re-identify any patient or link this data to any
  external identifiable source.
- Do not create a recurring schedule.
- Do not weaken a quality rule or test to obtain a passing result.
- Do not silently replace unavailable resources, substitute conditions, or
  reshape the treatment definition without reporting the deviation.
- Do not begin work on the companion Genie Agent spec until this build's
  acceptance criteria (Section 17) are met.
- Stop and ask for a decision if required capability, access, or permission
  is missing.
