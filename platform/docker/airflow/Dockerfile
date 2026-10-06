FROM apache/airflow:3.3.2-python3.14

COPY requirements.txt /requirements.txt

USER root
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y python3-venv

USER airflow
RUN pip install --upgrade pip
RUN python3 -m venv dbt_venv && \
    source dbt_venv/bin/activate && \
    pip install --verbose --no-cache-dir -r /requirements.txt && \
    deactivate
#constraint https://raw.githubusercontent.com/apache/airflow/constraints-2.10.5/constraints-3.11.txt

