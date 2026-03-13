select 
    id as pokemon_id,
    name,
    height,
    weight,
    base_experience,
    type_1 as primary_type,
    type_2 as secondary_type,
    loaded_at
from {{ source('pokemon_raw', 'pokemon_stats') }}