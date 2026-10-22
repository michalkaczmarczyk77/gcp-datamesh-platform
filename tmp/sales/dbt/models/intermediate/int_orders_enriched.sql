-- Ephemeral: inlined into fct_orders.sql at compile time, no dataset footprint.
with order_value as (
    select order_id, sum(sale_price) as order_value
    from {{ ref('stg_order_items') }}
    group by order_id
)

select
    o.order_id,
    o.user_id,
    o.status,
    o.order_date,
    o.num_of_item,
    c.first_name,
    c.last_name,
    c.email,
    c.country,
    coalesce(v.order_value, 0) as order_value
from {{ ref('stg_orders') }} as o
left join {{ ref('stg_customers') }} as c
    on o.user_id = c.user_id
left join order_value as v
    on o.order_id = v.order_id
