import os
import time
import requests
from dotenv import load_dotenv
import pandas as pd
import boto3
import pyarrow

load_dotenv()

url = "https://pokeapi.co/api/v2/pokemon/?limit=150"


def fetch_data(url, max_retries=3, retry_delay=2):
    for attempt in range(max_retries):
        try:
            response = requests.get(url)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Attempt {attempt + 1} failed: {e}")
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
    return None


data = fetch_data(url)

if data is None:
    print("Failed to fetch data from the API")
    exit()

print(f"Retrieved {len(data['results'])} records from the API")

data_list = []

for results in data['results']:
    nested_data = fetch_data(results['url'])
    if nested_data is None:
        print(f"Skipped {results['name']}")
        continue

    data_list.append({
        "id": nested_data["id"],
        "name": nested_data["name"],
        "height": nested_data["height"],
        "weight": nested_data["weight"],
        "base_experience": nested_data["base_experience"],
        "type_1": nested_data["types"][0]["type"]["name"],
        "type_2": nested_data["types"][1]["type"]["name"] if len(nested_data["types"]) > 1 else None,
    })

    time.sleep(1)
    print(f"Fetched {nested_data['name']}")

df = pd.DataFrame(data_list)
df["loaded_at"] = pd.Timestamp.now()

print(f"{len(df)} records fetched from the API")

s3 = boto3.client('s3')

parquet_data = df.to_parquet(index=False, engine='pyarrow')
s3.put_object(
    Bucket='cloudtank-bronze-09f1',
    Key=f"pokemon/pokemon_{pd.Timestamp.now():%Y-%m-%d}.parquet",
    Body=parquet_data,
)

print("Loaded to S3 successfully 💥💥💥")