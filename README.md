# GKE + Airflow — Detailed Architecture Diagram

> Companion diagram to [Weekend-Project-GKE_AirFlow.md](./Weekend-Project-GKE_AirFlow.md) — the confirmed architecture decision (self-hosted Airflow on GKE Autopilot).
>
> Updated to reflect the DLQ hardening added after the initial build: a `dlq_triage` subscription (bounded retention) plus a Cloud Monitoring alert policy, so dead-lettered messages are inspectable and alertable instead of vanishing or accumulating silently — see [project/README.md](./project/README.md#gaps-filled-beyond-the-plan).

```mermaid
flowchart TB
    subgraph GH["GitHub.com — data-transformation-platform"]
        REPO["Monorepo<br/>domains/*, infra/*, platform/*"]
        subgraph CICD["GitHub Actions (keyless via WIF)"]
            CIT["ci-terraform.yml<br/>plan on PR / apply on main"]
            CID["ci-dbt.yml — Slim CI<br/>dbt build --select state:modified+ --defer"]
            CDD["cd-deploy.yml<br/>build image → helm upgrade"]
        end
        REPO --> CIT & CID & CDD
    end

    subgraph BOOT["infra/bootstrap (applied once, manually)"]
        WIFP["Workload Identity Pool + Provider<br/>attribute_condition = this repo only"]
        SATF["sa-tf-plan (viewer) / sa-tf-apply (editor)"]
        WIFP --> SATF
    end
    CIT -. federates .-> WIFP
    CDD -. federates .-> WIFP

    subgraph GCP["GCP project — dtp-ref-dev / dtp-ref-prd"]
        TFSTATE[("GCS: dtp-ref-tfstate")]
        AR["Artifact Registry<br/>dtp/airflow-dbt:‹sha›"]
        SQL[("Cloud SQL db-f1-micro<br/>Airflow metadata DB")]

        subgraph GKE["GKE Autopilot cluster (deletion_protection=false)"]
            subgraph NS["namespace: airflow (Helm release, chart 1.16.0)"]
                SCHED["Scheduler pod<br/>+ git-sync sidecar"]
                WEB["Webserver pod"]
                KE["KubernetesExecutor<br/>spawns task pods on demand → scale to zero"]
            end
            WI["GKE Workload Identity<br/>KSA airflow-scheduler ⇄ GSA sa-airflow-‹env›"]
            SCHED --- WI
        end

        subgraph PUBSUB["modules/data_product_topic"]
            SCHEMA["AVRO schema: data-product-release-v1"]
            TOPIC(["Topic: dtp.sales.fct_orders.released"])
            SUB["Subscription …sub.finance<br/>7d retention"]
            DLQ["Dead-letter topic<br/>…released.dlq"]
            DLQSUB["dlq_triage subscription<br/>14d message_retention_duration"]
            SCHEMA --- TOPIC --> SUB
            SUB -.->|max_delivery_attempts=10| DLQ
            DLQ --> DLQSUB
        end

        subgraph MON["Cloud Monitoring — beyond the plan"]
            ALERT["Alert policy: dlq_backlog<br/>num_undelivered_messages > 0 for 5 min"]
        end
        DLQSUB -.->|watched by| ALERT

        subgraph BQ["modules/bigquery_domain"]
            SALES_STG[("sales_staging")]
            SALES_MART[("sales_mart.fct_orders")]
            FIN_STG[("finance_staging")]
            FIN_MART[("finance_mart.fct_revenue")]
            EVTBL[("_dtp_processed_events<br/>dedup by event_id")]
        end
    end

    CDD -->|docker push| AR
    CDD -->|"helm upgrade --set images.airflow.tag"| NS
    SCHED -->|"git-sync: pull domains/*/dags + dbt"| REPO

    KE -->|"sales__daily: Cosmos dbt_task_group('sales')"| SALES_STG
    SALES_STG --> SALES_MART
    KE -->|"publish_release() task"| TOPIC

    SUB -->|"Mode A: schedule=[Dataset] same-instance<br/>Mode B: PubSubPullSensor (deferrable) cross-instance"| KE
    KE -->|"dbt source freshness --select source:sales<br/>(belt-and-braces gate)"| SALES_MART
    KE -->|"finance__on_sales: Cosmos dbt_task_group('finance')"| FIN_STG
    FIN_STG --> FIN_MART
    SALES_MART -.->|"source(), never ref() across domains"| FIN_STG
    KE -.->|"check/record event_id before build"| EVTBL

    TFSTATE -. state .- GKE
    TFSTATE -. state .- PUBSUB
    TFSTATE -. state .- BQ
    ALERT -->|"notification_channels (empty by default)"| OPS(["On-call / Slack / email<br/>not wired unless supplied"])
```

## What each part maps to in the plan

| Diagram element | Plan reference |
|---|---|
| `BOOT` (WIF pool/provider) | Step 1.4 |
| `GKE`/`NS` (scheduler, webserver, KubernetesExecutor, Workload Identity) | Step 3.4, `values-dev.yaml` |
| `SQL` (Cloud SQL metadata DB) | Step 3.4 |
| `PUBSUB` (schema, topic, subscription, DLQ) | Step 3.3 |
| `PUBSUB.DLQSUB` (`dlq_triage` subscription, bounded retention) | Beyond the plan — see project/README.md § Gaps filled |
| `MON` (Cloud Monitoring alert policy on DLQ backlog) | Beyond the plan — requires `monitoring.googleapis.com` enabled (not in the plan's Step 1.2 list) |
| `BQ` (per-domain datasets) | Step 3.2 |
| `EVTBL` (`_dtp_processed_events`) | Step 5.5 (idempotency) |
| Mode A / Mode B on the `SUB → KE` edge | Step 5.4 |
| `source()` boundary between mart layers | Step 4.4 (CI-enforced rule) |
| `CDD` build/deploy flow | Step 6.3 |

## Sequence diagram — cross-domain synchronization

Zooms into the `SUB → KE` edge above. Both signals are always emitted by the
producer (Step 5.3's `publish_release` task carries `outlets=[FCT_ORDERS]`
*and* publishes to Pub/Sub in the same task) — which one a consumer *acts on*
depends on whether it's running `finance__on_sales` (Mode A) or
`finance__event_driven` (Mode B). Mode A has no message envelope to retry or
dead-letter, so the DLQ/retention/alerting path below only exists on the
Mode B side.

```mermaid
sequenceDiagram
    autonumber
    participant Sales as sales__daily<br/>(producer DAG)
    participant BQSales as sales_mart.fct_orders
    participant Topic as Pub/Sub topic<br/>dtp.sales.fct_orders.released
    participant Sub as Subscription<br/>…sub.finance (7d retention)
    participant Fin as finance__event_driven<br/>(PubSubPullSensor, deferrable)
    participant Fresh as validate_freshness()<br/>+ dbt source freshness
    participant Events as _dtp_platform.<br/>_dtp_processed_events
    participant Cosmos as dbt_task_group('finance')
    participant DLQ as Dead-letter topic<br/>…released.dlq
    participant Triage as dlq_triage subscription<br/>(14d message retention)
    participant Mon as Monitoring alert<br/>dlq_backlog
    participant OnCall as notification_channels<br/>(on-call human)

    Sales->>BQSales: dbt build fct_orders (incremental, insert_overwrite)
    Sales->>Topic: publish_release() — JSON DataProductRelease<br/>attrs: domain, product, logical_date

    par Same-instance signal (Mode A)
        Sales-->>Sales: outlets=[Dataset(sales_mart/fct_orders)]<br/>→ triggers finance__on_sales directly, no Pub/Sub involved
    and Cross-instance signal (Mode B)
        Topic->>Sub: fan out message (also retained 7d on the topic itself)
    end

    Fin->>Sub: pull (poke_interval=60s, timeout=6h)
    Sub-->>Fin: message(s): event_id, logical_date, published_at, row_count…

    alt logical_date matches this run AND event_id not yet processed
        Fin->>Fresh: validate_freshness(max_staleness_hours=26)
        Fresh->>Events: SELECT event_id WHERE event_id IN (…)
        Events-->>Fresh: not found → not a duplicate
        Fresh->>Events: INSERT event_id (mark processed)
        Fresh->>Fresh: dbt source freshness --select source:sales<br/>(belt-and-braces: "actually fresh", not just "producer said so")
        Fresh->>Cosmos: guards passed, proceed
        Cosmos->>BQSales: read via source('sales', 'fct_orders')
        Cosmos-->>Cosmos: build finance_mart.fct_revenue
    else event_id already in _dtp_processed_events
        Fin->>Fresh: validate_freshness(…)
        Fresh->>Events: SELECT event_id WHERE event_id IN (…)
        Events-->>Fresh: found → duplicate redelivery (at-least-once)
        Fresh-->>Fin: AirflowSkipException (skip quietly, no double-build)
    else published_at older than max_staleness_hours
        Fresh-->>Fin: AirflowException (fail loudly — real staleness, not a duplicate)
    end

    Note over Sub,DLQ: If finance never acks a message (bug, crash, always-failing<br/>validate_freshness) — after max_delivery_attempts=10 deliveries
    Sub->>DLQ: Pub/Sub service agent forwards the undelivered message
    DLQ->>Triage: lands on the dlq_triage subscription
    Note over Triage: message_retention_duration = 14d — bounded,<br/>not "forever" — purged automatically if untouched

    loop every alignment_period = 300s
        Mon->>Triage: check num_undelivered_messages
    end

    alt backlog > 0 sustained for 5 min
        Mon->>OnCall: notify, if dlq_alert_notification_channels supplied
        OnCall->>Triage: gcloud pubsub subscriptions pull …triage --auto-ack
        OnCall->>OnCall: fix + republish, or accept as a known loss
    else nobody looks within 14d
        Triage-->>Triage: Pub/Sub purges the message automatically
    end
```

**Key points this diagram makes explicit:**

- **Dual signalling is unconditional** — the producer never chooses between Mode A and Mode B; it emits both every run, and each consumer DAG variant decides which one it reacts to (Step 5.3/5.4).
- **Idempotency has two independent guards** — the `_dtp_processed_events` dedup check (Step 5.5) catches Pub/Sub's at-least-once redelivery, while `dbt source freshness` catches "the event said it was fresh but the table actually isn't" (e.g. an event-bus outage or a bug in the publisher).
- **The DLQ path only triggers on repeated, hard failure** — 10 consecutive failed deliveries, not a single transient error — and now has a bounded, monitored lifecycle (`dlq_triage` retention + `dlq_backlog` alert) instead of silently dropping or accumulating messages, per project/README.md § Gaps filled.

