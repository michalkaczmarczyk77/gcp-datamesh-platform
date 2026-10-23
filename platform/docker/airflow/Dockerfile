FROM apache/airflow:3.3.2-python3.14

USER root

COPY requirements.txt /requirements.txt

RUN apt-get update && \
    apt-get upgrade -y

USER airflow
RUN pip install --upgrade pip && \
    pip install --verbose --no-cache-dir -r /requirements.txt
