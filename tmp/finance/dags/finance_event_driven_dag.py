import os

from airflow.decorators import dag
from airflow.operators.bash import BashOperator
from airflow.providers.google.cloud.sensors.pubsub import PubSubPullSensor
from pendulum import datetime

from dags_common.cosmos_factory import dbt_task_group
from dags_common.freshness import validate_freshness


@dag(
    dag_id="finance__event_driven",
    schedule="@daily",
    start_date=datetime(2026, 9, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,  # Step 5.5: idempotency guard alongside the dedup table
    tags=["domain:finance", "layer:mart", "consumer", "mode:pubsub"],
)
def finance_event_driven():
    """Mode B — cross-instance / future separate domain project (Step 5.4).
    The scalable one: Datasets don't cross Airflow instances, this does."""
    wait = PubSubPullSensor(
        task_id="await_sales_fct_orders",
        project_id=os.environ["GCP_PROJECT"],
        subscription="dtp.sales.fct_orders.released.sub.finance",
        max_messages=10,
        ack_messages=True,
        deferrable=True,  # frees the worker slot entirely
        timeout=6 * 60 * 60,
        poke_interval=60,
    )
    validate = validate_freshness(max_staleness_hours=26, sensor_task_id="await_sales_fct_orders")

    # Belt-and-braces third check (Step 5.4): even with events, gate on the
    # data actually being fresh, not just "the producer said it was done".
    freshness_gate = BashOperator(
        task_id="dbt_source_freshness_sales",
        bash_command=(
            "cd /opt/airflow/dags/repo/domains/finance/dbt && "
            "/home/airflow/.local/bin/dbt source freshness --select source:sales "
            "--target {{ var.value.get('dtp_env', 'dev') }}"
        ),
    )

    wait >> validate >> freshness_gate >> dbt_task_group("finance")


finance_event_driven()
