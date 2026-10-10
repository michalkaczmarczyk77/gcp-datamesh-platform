#!/usr/bin/bash
docker build --no-cache -f ../Dockerfile -t dbt-bq-python-slim ../
#docker build -f ./Dockerfile -t dbt-bq-python-slim .
