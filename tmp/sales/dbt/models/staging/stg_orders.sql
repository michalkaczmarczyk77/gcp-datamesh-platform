select
    order_id,
    user_id,
    status,
    created_at,
    returned_at,
    shipped_at,
    delivered_at,
    num_of_item,
    date(created_at) as order_date
from {{ source('thelook_ecommerce', 'orders') }}
