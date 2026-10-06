from airflow.decorators import dag
from airflow.datasets import Dataset
from pendulum import datetime
from dags_common.cosmos_factory import dbt_task_group, load_manifest
from dags_common.data_product import publish_release

MANIFEST = load_manifest("sales")
FCT_ORDERS = Dataset("bigquery://sales_mart/fct_orders")


@dag(
    dag_id="sales__daily",
    schedule=MANIFEST["schedule"],
    start_date=datetime(2026, 9, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["domain:sales", "layer:mart", "producer"],
)
def sales_daily():
    dbt = dbt_task_group("sales")
    # Dual signalling: Dataset for same-instance consumers, Pub/Sub for cross-instance/cross-project.
    notify = publish_release.override(outlets=[FCT_ORDERS])(
        domain="sales", product=MANIFEST["produces"][0]
    )
    dbt >> notify


sales_daily()
