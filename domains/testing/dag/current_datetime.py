from airflow.decorators import dag, task
from pendulum import datetime, now


@dag(
    dag_id="testing_current_datetime",
    schedule="* * * * *",
    start_date=datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    tags=["testing"],
)
def testing_current_datetime():
    @task
    def print_current_datetime():
        print(f"===> This is test: {now('UTC')}")

    print_current_datetime()


testing_current_datetime()
