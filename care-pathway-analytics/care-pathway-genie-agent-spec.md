# Care Pathway Intelligence Agent
## Genie Agent Configuration Spec

**Platform:** Databricks (Genie / AI/BI)
**Implementation assistant:** Genie Code
**Purpose:** Give clinical operations, care management, and HEOR
stakeholders a natural-language way to query the care pathway data product
— no SQL, no custom app, no code to deploy or maintain
**Data classification:** De-identified patient-level healthcare claims data
(HealthVerity Marketplace sample; treat as sensitive/regulated even though
de-identified)
**Depends on:** *Care Pathway Analytics Data Product* spec — this build
assumes `patient_care_pathways.gold.patient_pathway_detail` and
`patient_care_pathways.gold.pathway_segment_summary` already exist and are
populated
**Version:** 1.0

---

## 1. Goal

Replace the custom interactive-app requirement with a governed,
natural-language question-answering layer over the care pathway gold
tables. A user should be able to ask questions like *"What share of
diabetes patients started treatment within 30 days of diagnosis?"* or
*"How does time-to-treatment vary by age band?"* and get a grounded,
correct answer — without anyone writing SQL, and without a custom
application to build, deploy, or keep running.

This is deliberately lighter-weight than a Databricks App: a Genie Agent is
a governed workspace object configured through the UI, not a deployed
codebase. There is no runtime to crash, no auth wiring, no dependency
drift — the worst-case failure mode is an imprecise answer or a
clarifying question back to the user, not an outage.

---

## 2. Scope

### In scope

- One Genie Agent (Space) registered against the two care pathway gold
  tables
- A business glossary of metric and segment definitions, reused from the
  data product spec, provided to the Agent as grounding instructions
- A set of trusted sample question → SQL pairs, to anchor accuracy on the
  domain-specific pathway logic (censoring, segment buckets, etc.)
- A curated set of starter/example questions
- Explicit guardrail instructions (see Section 7)
- One companion AI/BI Dashboard for the fixed visuals (funnel chart,
  summary tiles) that a conversational agent isn't the right tool for
- A short validation pass confirming the Agent's answers reconcile against
  the gold-table validation queries already defined in the data product
  spec

### Out of scope

- Any change to the underlying pipeline, bronze/silver layers, or gold
  table logic — this spec only adds a query layer on top
- Write access of any kind — the Agent is read-only by construction
  (Genie only generates and runs `SELECT` queries)
- Access to bronze/silver tables or raw source tables — the Agent is
  scoped to the gold layer only, so it can't accidentally surface
  unvalidated or unaggregated patient-level claim codes
- Multi-condition support in v1 (matches the single-condition scope of the
  underlying data product)
- Custom UI, branding, or embedding outside the standard Genie/Databricks
  One experience

---

## 3. Prerequisites

1. `patient_care_pathways.gold.patient_pathway_detail` and
   `patient_care_pathways.gold.pathway_segment_summary` exist, are
   populated, and have passed the SQL tests defined in the data product
   spec.
2. Genie is enabled on this workspace.
3. The intended audience (clinical ops / care management / HEOR
   stakeholders) has, or can be granted, workspace access with the
   "consumer access" entitlement, and `SELECT` permission on the two gold
   tables via Unity Catalog.
4. No existing Genie Agent with the same name is already registered.

---

## 4. Approval Gate

Before creating the Agent, the dashboard, or any grounding assets:

1. Confirm the two gold tables exist, are populated, and their most recent
   `product_updated_at` is not stale relative to the pipeline's last run.
2. Confirm Genie is enabled and who has permission to create an Agent in
   this workspace.
3. Confirm the target audience's access — do not grant broader access than
   the stakeholders named above without asking first.
4. Confirm no naming conflict with an existing Agent or Dashboard.
5. Produce a short plan: Agent name, tables to register, glossary terms to
   load, starter questions, and the dashboard's chart list.
6. Stop and wait for explicit approval before creating anything.

---

## 5. Target Objects

| Object | Name |
|---|---|
| Genie Agent (Space) | `Care Pathway Intelligence` |
| Companion AI/BI Dashboard | `Care Pathway Overview` |
| Tables registered to the Agent | `patient_care_pathways.gold.patient_pathway_detail`, `patient_care_pathways.gold.pathway_segment_summary` |

---

## 6. Business Glossary (grounding instructions for the Agent)

Load these definitions into the Agent's instructions/knowledge store so
every answer uses consistent terminology — these are the same definitions
from Section 6 of the data product spec, not a re-derivation:

- **Index diagnosis** — a patient's earliest qualifying diagnosis claim for
  the study condition. Anchors the pathway.
- **Pharmacological treatment event** — the patient's earliest qualifying
  pharmacy claim on or after the index diagnosis date.
- **Clinical follow-up event** — the patient's earliest qualifying
  procedure/lab claim on or after the index diagnosis date.
- **Days to treatment** — the day count between index diagnosis and the
  relevant treatment event; null if no such event was observed.
- **Pathway segment** — the bucket a patient falls into based on days to
  treatment: `SAME_DAY`, `WITHIN_30_DAYS`, `31_TO_90_DAYS`,
  `91_TO_180_DAYS`, `OVER_180_DAYS`, `NOT_TREATED_CENSORED`.
- **Censored patient** — a patient with no qualifying treatment event
  observed before their observation window ends. **This must not be
  described as "the patient was never treated"** — the data cannot see
  outside the observation window, so the correct framing is "no treatment
  observed within the available data."
- **Cohort** — patients meeting the study condition's index diagnosis
  criteria; the denominator for all percentage-based answers unless a
  question explicitly asks about a sub-segment.

Also load: the exact condition and treatment code definitions actually used
in the build (from the data product's Phase 1 confirmation — condition,
ICD code pattern, drug classes, procedure codes), so the Agent can explain
*what* "treated" means if asked.

---

## 7. Guardrail Instructions

Configure these as explicit, persistent instructions on the Agent — not
optional framing, required behavior:

- Never suggest, imply, or answer questions seeking to re-identify a
  specific patient. If a question asks for something that would isolate a
  single individual (e.g. filtering to a very small cell size), the Agent
  should decline and suggest a broader cut instead.
- Never offer clinical recommendations, diagnoses, or treatment advice for
  any individual. This is a claims analytics tool, not a clinical decision
  support tool — answers describe patterns in the de-identified cohort,
  not guidance for any patient's care.
- Always distinguish "no treatment observed within the data" from "the
  patient was never treated," per the censoring definition in Section 6.
- Only answer from the two registered gold tables. Do not attempt to join
  to, infer from, or speculate about data outside what's registered to the
  Agent.
- When a question is ambiguous (e.g. "treatment" without specifying
  pharmacy vs. clinical follow-up), ask a clarifying question rather than
  guessing which pathway type is meant.
- State sample-size caveats when answering about a segment with a small
  patient count, since this is a demonstration-scale cohort (~1,000+
  patients), not a population-scale dataset.

---

## 8. Trusted Assets (sample question → SQL pairs)

Provide these as grounding examples so the Agent generates correct SQL for
this domain's specific logic, rather than guessing at aggregation
patterns:

1. *"What percentage of patients started pharmacy treatment within 30 days
   of diagnosis?"* →
   ```sql
   SELECT
     SUM(CASE WHEN pharmacy_pathway_segment IN ('SAME_DAY', 'WITHIN_30_DAYS') THEN 1 ELSE 0 END)
       / COUNT(*) AS pct_treated_within_30_days
   FROM patient_care_pathways.gold.patient_pathway_detail;
   ```

2. *"What's the median time to clinical follow-up?"* →
   ```sql
   SELECT PERCENTILE(days_to_clinical_followup, 0.5) AS median_days_to_followup
   FROM patient_care_pathways.gold.patient_pathway_detail
   WHERE days_to_clinical_followup IS NOT NULL;
   ```

3. *"How does time-to-treatment vary by age band?"* →
   ```sql
   SELECT patient_age_band,
          PERCENTILE(days_to_pharmacy_treatment, 0.5) AS median_days_to_treatment,
          COUNT(*) AS patient_count
   FROM patient_care_pathways.gold.patient_pathway_detail
   WHERE days_to_pharmacy_treatment IS NOT NULL
   GROUP BY patient_age_band
   ORDER BY patient_age_band;
   ```

4. *"How many patients have no treatment observed at all?"* →
   ```sql
   SELECT COUNT(*) AS censored_patient_count
   FROM patient_care_pathways.gold.patient_pathway_detail
   WHERE pharmacy_pathway_segment = 'NOT_TREATED_CENSORED';
   ```

Genie Code should add 2–3 more pairs covering the `pathway_segment_summary`
table directly (e.g. segment distribution by pathway type), so both gold
tables are represented in the trusted assets.

---

## 9. Starter Questions

Seed the Agent's UI with these to demonstrate the kind of intelligence it
can produce on first use:

- "What percentage of patients started treatment within 30 days of
  diagnosis?"
- "How does time-to-treatment differ by gender?"
- "Which state has the highest share of patients with no treatment
  observed?"
- "What's the median days to clinical follow-up, and how does it compare
  to median days to pharmacy treatment?"
- "Show me the segment distribution for both pathway types."

---

## 10. Companion Dashboard

Create `Care Pathway Overview` as a small AI/BI Dashboard (not an app —
configured through the UI, no code) covering what a conversational agent
answers less naturally as a fixed view:

- Funnel/bar chart: patient count by pathway segment, for both pathway
  types (from `pathway_segment_summary`)
- Summary tiles: cohort size, median days to pharmacy treatment, median
  days to clinical follow-up, % censored
- A demographic breakdown chart (age band or gender) of pathway segment,
  from `patient_pathway_detail`

Link the dashboard from the Genie Agent's landing context so users can move
between "ask a question" and "see the standing view" without leaving the
governed environment.

---

## 11. Validation

1. Ask each of the Section 8 trusted questions through the Agent and
   confirm the returned answer matches the corresponding SQL run directly
   against the gold tables (the data product spec's `validation.sql`
   covers most of the same aggregates — cross-check against it).
2. Ask 2–3 of the Section 9 starter questions and manually confirm
   correctness and that guardrail behavior (Section 7) triggers correctly
   — e.g. try a deliberately ambiguous or re-identification-adjacent
   question and confirm the Agent declines or asks for clarification
   rather than answering.
3. Record any question the Agent answers incorrectly or ambiguously, and
   add it as an additional trusted-asset example to close the gap.

---

## 12. Acceptance Criteria

1. The Genie Agent is created, registered only against the two gold
   tables, and accessible to the intended audience.
2. The business glossary and guardrail instructions from Sections 6–7 are
   loaded into the Agent's configuration.
3. All trusted assets from Section 8 return correct, verified answers.
4. All starter questions from Section 9 are seeded and functional.
5. The companion dashboard is created and linked.
6. Validation per Section 11 is complete, with results documented.
7. No write access, and no access to bronze/silver/source tables, is
   granted to the Agent.
8. A short final summary is provided (see Section 13).

---

## 13. Final Report

After configuration, provide:

1. Agent name, registered tables, and access granted (who/what group)
2. Glossary terms and guardrail instructions loaded
3. Trusted assets created, with validation results for each
4. Starter questions seeded
5. Dashboard name and chart list
6. Any question the Agent got wrong during validation, and how it was
   corrected
7. Exact steps to update the glossary/guardrails later, or to remove the
   Agent and dashboard

---

## 14. Genie Code Instructions

### Phase 1: Plan only

1. Confirm the gold tables exist and are current.
2. Confirm Genie and dashboard creation permissions.
3. Propose the Agent name, glossary content, guardrail text, trusted
   assets, and starter questions for review.
4. Stop and wait for explicit approval.

### Phase 2: Build only after approval

1. Create the Genie Agent scoped to the two gold tables only.
2. Load the business glossary and guardrail instructions.
3. Add the trusted question → SQL pairs.
4. Seed the starter questions.
5. Build the companion dashboard.
6. Run the validation pass in Section 11 and record results.
7. Produce the final report.

### Safety rules

- Do not register the Agent against bronze, silver, or raw source tables —
  gold only.
- Do not grant the Agent or its users any write capability.
- Do not omit the censoring/guardrail instructions in Sections 6–7 — these
  are required, not optional polish.
- Do not grant broader audience access than confirmed in the approval
  gate.
- Stop and ask if the underlying gold tables are missing, stale, or fail
  their own validation before configuring the Agent on top of them.
