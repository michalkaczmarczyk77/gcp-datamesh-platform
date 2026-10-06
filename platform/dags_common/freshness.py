"""Freshness/idempotency guard for Pub/Sub-driven consumer DAGs.

Referenced in the plan (Phase 5, Step 5.4 Mode B and Step 5.5) as
`validate_freshness(...)`, sitting between a PubSubPullSensor and the dbt
task group:

    wait = PubSubPullSensor(..., ack_messages=True, ...)
    validate = validate_freshness(max_staleness_hours=26)
    wait >> validate >> dbt_task_group("finance")

Pub/Sub is at-least-once, so this task:
  1. Reads the messages the upstream sensor pulled (from its XCom).
  2. Drops messages whose `logical_date` isn't this DAG run's own logical
     date — a consumer run only accepts events for its own day.
  3. Skips the run (AirflowSkipException) if every remaining message's
     event_id is already recorded in `dtp_platform._dtp_processed_events`
     — i.e. this is a duplicate/re-delivery, not a new signal.
  4. Fails loudly (AirflowException) if every remaining message is older
     than `max_staleness_hours` — a real staleness problem, distinct from
     a harmless duplicate delivery.
  5. Records newly-accepted event_ids in `_dtp_processed_events` so a
     re-delivery is recognized as a duplicate next time.

GCP_PROJECT is injected as a pod env var by the Helm chart (see
platform/helm/airflow/values-*.yaml).
"""
import base64
import json
import os
from datetime import datetime, timedelta, timezone

from airflow.decorators import task
from airflow.exceptions import AirflowException, AirflowSkipException
from google.cloud import bigquery

DEDUP_TABLE = "{project}.dtp_platform._dtp_processed_events"


def _decode_payload(received_message: dict) -> dict:
    """A PubSubPullSensor(ack_messages=True) XCom entry -> the JSON release payload."""
    data = received_message["message"]["data"]
    return json.loads(base64.b64decode(data).decode("utf-8"))


def _already_processed(bq: bigquery.Client, table: str, event_ids: list[str]) -> set[str]:
    if not event_ids:
        return set()
    query = f"SELECT event_id FROM `{table}` WHERE event_id IN UNNEST(@event_ids)"
    job = bq.query(
        query,
        job_config=bigquery.QueryJobConfig(
            query_parameters=[bigquery.ArrayQueryParameter("event_ids", "STRING", event_ids)]
        ),
    )
    return {row.event_id for row in job.result()}


def _mark_processed(bq: bigquery.Client, table: str, events: list[dict]) -> None:
    now = datetime.now(timezone.utc).isoformat()
    rows = [
        {
            "event_id": e["event_id"],
            "domain": e["domain"],
            "product": e["product"],
            "logical_date": e["logical_date"],
            "processed_at": now,
        }
        for e in events
    ]
    errors = bq.insert_rows_json(table, rows)
    if errors:
        raise AirflowException(f"Failed to record processed events in {table}: {errors}")


@task
def validate_freshness(max_staleness_hours: int, sensor_task_id: str = "await_sales_fct_orders", **context):
    project = os.environ["GCP_PROJECT"]
    table = DEDUP_TABLE.format(project=project)
    logical_date = context["logical_date"].to_date_string()

    raw_messages = context["ti"].xcom_pull(task_ids=sensor_task_id) or []
    candidates = []
    for raw in raw_messages:
        payload = _decode_payload(raw)
        if payload["logical_date"][:10] != logical_date:
            continue  # event for a different logical date — not ours to consume
        candidates.append(payload)

    if not candidates:
        raise AirflowSkipException(f"No release event for logical_date={logical_date} yet.")

    bq = bigquery.Client(project=project)
    processed = _already_processed(bq, table, [c["event_id"] for c in candidates])
    fresh = [c for c in candidates if c["event_id"] not in processed]

    if not fresh:
        raise AirflowSkipException("All matching release events were already processed (duplicate delivery).")

    now = datetime.now(timezone.utc)
    still_fresh = [
        c for c in fresh
        if now - datetime.fromisoformat(c["published_at"].replace("Z", "+00:00")) <= timedelta(hours=max_staleness_hours)
    ]

    if not still_fresh:
        raise AirflowException(
            f"Release event(s) for logical_date={logical_date} exceeded max_staleness_hours={max_staleness_hours}."
        )

    _mark_processed(bq, table, still_fresh)
    return [c["event_id"] for c in still_fresh]
