from airflow.decorators import dag
from airflow.datasets import Dataset
from pendulum import datetime
from dags_common.cosmos_factory import dbt_task_group

FCT_ORDERS = Dataset("bigquery://sales_mart/fct_orders")


@dag(
    dag_id="finance__on_sales",
    schedule=[FCT_ORDERS],
    start_date=datetime(2026, 9, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["domain:finance", "layer:mart", "consumer", "mode:dataset"],
)
def finance_on_sales():
    """Mode A — same Airflow instance (Step 5.4). Airflow triggers this DAG
    the moment sales__daily updates the FCT_ORDERS asset. No sensors, no
    polling, no cost. Use this while sales and finance share one instance;
    switch to finance_event_driven_dag.py's Mode B once they don't."""
    dbt_task_group("finance")


finance_on_sales()
