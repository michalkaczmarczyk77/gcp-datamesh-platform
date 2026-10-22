select
    order_id,
    sale_price
from {{ source('thelook_ecommerce', 'order_items') }}
