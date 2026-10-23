FROM python:3.14-slim

COPY requirements.txt /requirements.txt

USER root
RUN apt-get update

USER airflow
RUN pip install --upgrade pip
RUN pip install --verbose --no-cache-dir -r /requirements.txt


