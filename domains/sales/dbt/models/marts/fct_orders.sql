-- Data product: sales.fct_orders (dtp.sales.fct_orders.released).
-- Materialization/incremental_strategy/partition_by/schema are set at the
-- `marts` folder level in dbt_project.yml.
--
-- `_dbt_loaded_at` is the loaded_at_field finance's staging source freshness
-- check (domains/finance/dbt/models/staging/_sources.yml) reads.
select
    order_id,
    user_id,
    status,
    order_date,
    num_of_item,
    country,
    order_value,
    current_timestamp() as _dbt_loaded_at
from {{ ref('int_orders_enriched') }}

{% if is_incremental() %}
where order_date >= _dbt_max_partition
{% endif %}
