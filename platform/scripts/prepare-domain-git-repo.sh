#!/bin/bash

_DOMAIN_NAME=$1

#git clone if not yet cloned

mkdir -p /git/dlh-${_DOMAIN_NAME}/dbt/models
mkdir -p /git/dlh-${_DOMAIN_NAME}/dbt/models/inbound
mkdir -p /git/dlh-${_DOMAIN_NAME}/dbt/models/compute
mkdir -p /git/dlh-${_DOMAIN_NAME}/dbt/models/expose

touch /git/dlh-${_DOMAIN_NAME}/dbt/models/profile.yaml

layers=("inbound" "compute" "expose")

for layer in "${layers[@]}"; do
    echo "# ${_DOMAIN_NAME^^} ${layer} layer" > /git/dlh-${_DOMAIN_NAME}/dbt/models/${layer}/README.md
done

#git push