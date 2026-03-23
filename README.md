# Pokemon Analytics Pipeline

End-to-end data pipeline that extracts Pokemon data from PokeAPI, lands it in S3 as Parquet, loads to PostgreSQL, transforms with dbt, and orchestrates the full flow with Airflow on Docker.

## Architecture

```
PokeAPI
  │
  ▼
Python (ECS Fargate)        ← Docker container, triggered by Airflow
  │  Fetches 150 Pokemon, extracts stats, writes Parquet
  ▼
AWS S3 (Parquet)            ← Bronze bucket, partitioned by date
  │
  ▼
PostgreSQL (raw schema)     ← Truncate-and-load via SQLAlchemy
  │
  ▼
dbt
  ├── staging/              ← Type casting and column renaming
  └── marts/                ← Aggregated summaries by Pokemon type
  │
  ▼
Apache Airflow              ← DAG chains all steps, runs daily
  (Docker Compose, LocalExecutor)

Infrastructure: Terraform (modular — ECS, ECR, S3, IAM, CloudWatch)
```

## Tech Stack

| Layer | Tool |
|---|---|
| Ingestion | Python, Requests, Pandas |
| Compute | AWS ECS Fargate (Docker) |
| Storage | AWS S3 (Parquet) |
| Warehouse | PostgreSQL |
| Transformation | dbt (staging + mart layers) |
| Orchestration | Apache Airflow (Docker Compose, LocalExecutor) |
| Infrastructure | Terraform (modular: ECS, S3, IAM) |
| Container Registry | AWS ECR |

## Project Structure

```
pokemon-ecs-pipeline/
├── pipeline/
│   ├── pipeline.py             # PokeAPI → S3 ingestion script
│   ├── s3_to_warehouse.py      # S3 → PostgreSQL loader
│   ├── Dockerfile
│   └── requirements.txt
├── airflow/
│   ├── docker-compose.yaml
│   ├── Dockerfile
│   ├── .env.example
│   └── dags/
│       └── pokemon_dag.py      # ECS → warehouse → dbt DAG
├── pokemon_dbt/
│   ├── dbt_project.yml
│   ├── macros/
│   │   └── get_custom_schema.sql
│   └── models/
│       ├── staging/
│       │   ├── sources.yml
│       │   ├── stg_pokemon_stats.sql
│       │   └── _stg_pokemon_stats.yml
│       └── marts/
│           ├── mart_pokemon_primary_summary.sql
│           └── mart_pokemon_secondary_summary.sql
├── terraform/
│   ├── main.tf                 # ECS cluster, ECR, S3, IAM, CloudWatch
│   ├── variables.tf
│   └── outputs.tf
├── .env.example
└── pyproject.toml
```

## Pipeline Details

### 1. Ingestion
`pipeline/pipeline.py` calls the PokeAPI for the first 150 Pokemon. For each, it extracts: `id`, `name`, `height`, `weight`, `base_experience`, `type_1`, `type_2`. The result is written to S3 as a Parquet file keyed by date (`pokemon/pokemon_YYYY-MM-DD.parquet`) with a `loaded_at` timestamp column.

### 2. Loading
`pipeline/s3_to_warehouse.py` fetches the most recently modified Parquet file from S3, truncates `raw.pokemon_stats` in PostgreSQL, and appends the new data. Truncate-and-load ensures idempotency on reruns.

### 3. Transformation
dbt runs two layers:
- **Staging** (`stg_pokemon_stats`): renames `id → pokemon_id`, `type_1 → primary_type`, `type_2 → secondary_type` and enforces types. Materialized as a view.
- **Marts**: `mart_pokemon_primary_summary` and `mart_pokemon_secondary_summary` aggregate count, average height/weight/base_experience, and max/min base_experience grouped by Pokemon type. Materialized as tables.

### 4. Orchestration
The Airflow DAG (`pokemon_ecs_pipeline`) chains three tasks daily:
1. `EcsRunTaskOperator` — triggers the Fargate container to run `pipeline.py`
2. `BashOperator` — runs `s3_to_warehouse.py` inside the Airflow container
3. `BashOperator` — runs `dbt run` against the warehouse

### 5. Infrastructure
Terraform provisions:
- **ECR** repository for the pipeline Docker image
- **ECS Fargate** cluster and task definition (256 CPU / 512 MB, ARM64)
- **S3** bucket with versioning, AES-256 encryption, and lifecycle policies (IA after 30 days, expire after 365)
- **IAM** execution and task roles with least-privilege S3 access scoped to the pipeline prefix
- **CloudWatch** log group for ECS task output

## How to Run

### Prerequisites
- Docker and Docker Compose
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Python 3.12+

### 1. Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### 2. Build and push the pipeline image
```bash
# Get the ECR URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)

docker build -t pokemon-pipeline ./pipeline
docker tag pokemon-pipeline:latest $ECR_URL:latest
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL
docker push $ECR_URL:latest
```

### 3. Configure environment
```bash
cp .env.example .env
# Fill in S3_BUCKET and DB_URL

cp airflow/.env.example airflow/.env
# Fill in DBT_HOST, ECS_SUBNETS, ECS_SECURITY_GROUP
```

### 4. Start Airflow
```bash
cd airflow
docker compose up
```

Airflow UI: http://localhost:8080 (admin / admin)

### 5. Run the pipeline manually
Trigger the `pokemon_ecs_pipeline` DAG from the Airflow UI, or let it run on its daily schedule.

## Key Design Decisions

- **Modular Terraform**: separate resource groups for ECS, ECR, S3, and IAM make the infrastructure easy to extend or swap out individually.
- **ECS Fargate**: serverless compute means no EC2 instances to manage; the pipeline container only runs when triggered.
- **Parquet on S3**: columnar format keeps storage costs low and reads fast for downstream loading.
- **dbt custom schema macro**: routes staging and mart models to separate PostgreSQL schemas (`staging`, `marts`) without manual schema prefixing in every model.
- **Truncate-and-load**: simple idempotency strategy — reruns are safe and the warehouse always reflects the latest API snapshot.

## Author

Daniel Brown
