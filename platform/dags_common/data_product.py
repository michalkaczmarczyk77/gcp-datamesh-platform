import json
import os
import uuid
import datetime
from airflow.decorators import task
from google.cloud import pubsub_v1, bigquery


@task
def publish_release(domain: str, product: dict, **context):
    """Emit the contract event AFTER the product table is committed.

    `product` comes straight from domain.yaml's `produces[i]` (plain
    yaml.safe_load, no Jinja rendering) so it only has the keys declared
    there (name/dataset/table/sla_minutes/topic). GCP_PROJECT is injected
    as a pod env var by the Helm chart (see platform/helm/airflow/values-*.yaml)
    rather than duplicated into every domain.yaml.
    """
    project = product.get("project") or os.environ["GCP_PROJECT"]
    gcp_project = product.get("gcp_project") or project

    bq = bigquery.Client(project=project)
    fq = f"{project}.{product['dataset']}.{product['table']}"
    rows = bq.get_table(fq).num_rows

    payload = {
        "event_id": str(uuid.uuid4()),
        "domain": domain,
        "product": product["name"],
        "fq_table": fq,
        "logical_date": context["logical_date"].isoformat(),
        "run_id": context["run_id"],
        "dbt_invocation_id": context["ti"].xcom_pull(key="dbt_invocation_id") or "",
        "row_count": rows,
        "status": "SUCCESS",
        "published_at": datetime.datetime.utcnow().isoformat() + "Z",
        "schema_version": 1,
    }
    publisher = pubsub_v1.PublisherClient()
    topic = publisher.topic_path(gcp_project, product["topic"])
    publisher.publish(
        topic, json.dumps(payload).encode(),
        domain=domain, product=product["name"],
        logical_date=payload["logical_date"],  # attributes → server-side filtering
    ).result(timeout=30)
    return payload
