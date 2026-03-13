{{ config(materialized='table', schema='marts') }}

select
    secondary_type,
    count(*) as pokemon_count,
    round(avg(height)::numeric, 1) as avg_height,
    round(avg(weight)::numeric, 1) as avg_weight,
    round(avg(base_experience)::numeric, 1) as avg_base_experience,
    max(base_experience) as max_base_experience,
    min(base_experience) as min_base_experience
from {{ ref('stg_pokemon_stats') }}
group by secondary_type
order by pokemon_count desc