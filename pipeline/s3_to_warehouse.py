import os
import pandas as pd
from sqlalchemy import create_engine, text
import boto3
from dotenv import load_dotenv

load_dotenv()


def fetch_latest_from_s3(bucket, prefix):
    try:
        s3 = boto3.client('s3')
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)

        if 'Contents' not in response:
            print(f"No files found in s3://{bucket}/{prefix}")
            return None

        latest_file = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)[0]
        local_path = '/tmp/pokemon_latest.parquet'

        s3.download_file(bucket, latest_file['Key'], local_path)
        print(f"Downloaded {latest_file['Key']}")

        return pd.read_parquet(local_path)

    except Exception as e:
        print(f"S3 fetch failed: {e}")
        return None


def load_to_warehouse(df):
    try:
        engine = create_engine(os.getenv("DB_URL"))

        with engine.begin() as conn:
            conn.execute(text("TRUNCATE TABLE raw.pokemon_stats"))

        df.to_sql(
            "pokemon_stats",
            engine,
            schema="raw",
            if_exists="append",
            index=False
        )
        print("Loaded to warehouse successfully 💥💥💥")

    except Exception as e:
        print(f"Warehouse load failed: {e}")


df = fetch_latest_from_s3('cloudtank-bronze-09f1', 'pokemon/')

if df is None:
    print("No data to load")
    exit()

load_to_warehouse(df)