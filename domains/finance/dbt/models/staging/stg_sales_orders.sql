select
    order_id,
    user_id,
    status,
    order_date,
    order_value,
    country
from {{ source('sales', 'fct_orders') }}
where status not in ('cancelled', 'returned')
