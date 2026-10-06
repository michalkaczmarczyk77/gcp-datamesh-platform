SHELL := /bin/bash
ENV ?= dev
DOMAIN ?= sales

.PHONY: help fmt validate plan apply destroy dbt-deps dbt-build dbt-test validate-manifests helm-deploy

help:
	@echo "Common targets (override ENV=dev|prd, DOMAIN=sales|finance):"
	@echo "  make fmt                 terraform fmt -recursive over infra/"
	@echo "  make validate            terraform validate for infra/envs/\$$ENV"
	@echo "  make plan ENV=dev        terraform plan for an environment"
	@echo "  make apply ENV=dev       terraform apply for an environment"
	@echo "  make destroy ENV=dev     terraform destroy for an environment"
	@echo "  make dbt-deps DOMAIN=sales"
	@echo "  make dbt-build DOMAIN=sales"
	@echo "  make dbt-test DOMAIN=sales"
	@echo "  make validate-manifests  validate all domains/*/domain.yaml"
	@echo "  make helm-deploy ENV=dev IMAGE_TAG=<sha>"

fmt:
	terraform fmt -recursive infra/

validate:
	cd infra/envs/$(ENV) && terraform init -backend=false && terraform validate

plan:
	cd infra/envs/$(ENV) && terraform init && terraform plan

apply:
	cd infra/envs/$(ENV) && terraform init && terraform apply

destroy:
	cd infra/envs/$(ENV) && terraform init && terraform destroy

dbt-deps:
	cd domains/$(DOMAIN)/dbt && dbt deps

dbt-build:
	cd domains/$(DOMAIN)/dbt && dbt build --target $(ENV)

dbt-test:
	cd domains/$(DOMAIN)/dbt && dbt test --target $(ENV)

validate-manifests:
	python platform/scripts/validate_domain_manifest.py domains/

helm-deploy:
	IMAGE_TAG=$(IMAGE_TAG) ENV=$(ENV) ./platform/scripts/deploy_airflow.sh
