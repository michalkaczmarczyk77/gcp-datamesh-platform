-- Data product: finance.fct_revenue (dtp.finance.fct_revenue.released).
-- Materialization/incremental_strategy/partition_by/schema are set at the
-- `marts` folder level in dbt_project.yml.
select
    order_date as revenue_date,
    country,
    count(distinct order_id) as order_count,
    sum(order_value) as gross_revenue
from {{ ref('stg_sales_orders') }}

{% if is_incremental() %}
where order_date >= _dbt_max_partition
{% endif %}

group by revenue_date, country
