from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'tank',
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
    }

with DAG(
    dag_id='pokemon_ecs_pipeline',
    default_args=default_args,
    description='Fetch Pokemon data and load to S3 via ECS Fargate',
    start_date=datetime(2026, 3, 9),
    schedule_interval='@daily',
    catchup=False,
    tags=['pokemon', 'ecs', 'pipeline'],
) as dag:
    
    fetch_pokemon = EcsRunTaskOperator(
        task_id='fetch_pokemon_to_s3',
        cluster='pokemon-pipeline-cluster',
        task_definition='pokemon-pipeline',
        launch_type='FARGATE',
        overrides={},
        network_configuration={
            'awsvpcConfiguration': {
                'subnets': [
                    'subnet-051ddc87ff8f49aef',
                    'subnet-0ae2456871f5e54c9',
                    'subnet-0fc2ec5bceb602fc2',
                ],
                'securityGroups': ['sg-08a0269ac418cd3db'],
                'assignPublicIp': 'ENABLED',
            }
        },
        awslogs_group='/ecs/pokemon-pipeline',
        awslogs_stream_prefix='ecs/pokemon-pipeline',
    )
    
    load_to_warehouse = BashOperator(
        task_id='s3_to_warehouse',
        bash_command='python /opt/airflow/pipeline/s3_to_warehouse.py',
    )

    run_dbt = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/airflow/dbt && dbt run',
    )

    fetch_pokemon >> load_to_warehouse >> run_dbt