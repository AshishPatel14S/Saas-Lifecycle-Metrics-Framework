# Tracking Plan (Segment/Amplitude style)

Defines event semantics, identity rules, and sessionization rules used across marts + Power BI.

## Identity Rules
- **user_id:** use GA4 pseudonymous user identifier available in the dataset (typically `user_pseudo_id`).
- **No stitching:** treat users as pseudonymous; no login identity stitching in scope.
- **Dedup:** events should be unique by (user_id, event_timestamp, event_name) + key params when feasible.

## Sessionization Rules
- **Timeout:** 30 minutes of inactivity starts a new session (GA4 convention).
- **Session key priority:**
  1) Use native GA4 session id if available (preferred)
  2) Else derive sessions by ordering events per user and splitting when inactivity > 30 minutes
- **Session start:**
  - Use `session_start` event when present
  - Else first event in derived session = session start
- **Timezone:** use a single consistent reporting timezone; document final choice in README.

## Core Events Used (Funnel + Retention/Churn)
| event_name       | Purpose                              | Required properties (minimum) | Notes |
|------------------|--------------------------------------|-------------------------------|------|
| session_start    | Acquisition/top-of-funnel anchor     | user_id, timestamp            | Funnel step 1 |
| view_item        | Product view                          | item_id (if available)        | Funnel |
| add_to_cart      | Intent signal                          | item_id (if available)        | Funnel |
| begin_checkout   | Checkout start                         | value/currency (if available) | Funnel |
| purchase         | Value/activation proxy                 | transaction_id/value (if avail) | North Star |

## Noise / Exclusions
Default: all events count for “activity” unless clearly technical/noise events are identified.
Any exclusions must be documented here and mirrored on the dashboard Definitions page.

