select
    id as user_id,
    first_name,
    last_name,
    email,
    country,
    state,
    city,
    created_at
from {{ source('thelook_ecommerce', 'users') }}
