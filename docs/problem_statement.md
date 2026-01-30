# SaaS Lifecycle Metrics Framework — Problem Statement

## Goal
Build an end-to-end Tech/SaaS product analytics portfolio project from GA4-style events in BigQuery:
data → staging/cleaning → dimensional model → SQL marts → QA + reconciliation → Power BI semantic model + dashboard → 1-page insights memo → GitHub-ready repo.

## Dataset & Tools
- Dataset: GA4 Obfuscated Sample E-commerce Events (BigQuery sample)
- Warehouse: BigQuery
- BI: Power BI
- Core tools: SQL, Python (Pandas/NumPy), Excel, Git/GitHub

## Key Business Questions
1. Where do users drop off in the funnel, and how does conversion vary by segment?
2. What do cohort retention patterns look like over time?
3. How sensitive is churn (behavioral proxy) to 14/30/60-day inactivity windows?
4. Are the KPIs trustworthy (QA checks + reconciliation across events → sessions → users)?

## Deliverables
- Metric dictionary aligned to SQL marts + Power BI measures
- Tracking plan (Segment/Amplitude style) with identity + sessionization rules
- Dimensional model (facts/dims) + marts for funnel, cohorts, churn
- Data QA pack + reconciliation documentation
- Power BI dashboard (3–5 pages) + Definitions/Data Quality page
- Insights memo + demo script

## Assumptions (initial)
- This is event-based analytics; “churn” is behavioral (inactivity), not billing cancellation.
- Users are pseudonymous; identity stitching is out of scope.
- Sessionization follows GA4-style 30-minute inactivity timeout unless dataset constraints require approximation.
- All caveats will be documented in the Definitions & Data Quality dashboard page.

