import os
import time
import json
import boto3
import psycopg2
from botocore.exceptions import ClientError

# Configuration
S3_ENDPOINT = os.getenv("S3_ENDPOINT", "http://localstack.default.svc.cluster.local:4566")
S3_BUCKET = os.getenv("S3_BUCKET", "crypto-raw-data")
DB_HOST = os.getenv("DB_HOST", "postgres-postgresql.default.svc.cluster.local")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASS = os.getenv("DB_PASS", "postgres")
DB_NAME = os.getenv("DB_NAME", "postgres")

def get_s3_client():
    return boto3.client(
        's3',
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id='test',
        aws_secret_access_key='test',
        region_name='us-east-1'
    )

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASS,
        dbname=DB_NAME
    )

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS crypto_prices (
            id SERIAL PRIMARY KEY,
            symbol VARCHAR(10),
            price DECIMAL(18, 8),
            timestamp TIMESTAMP,
            source VARCHAR(50)
        );
    """)
    conn.commit()
    cur.close()
    conn.close()
    print("✅ Database initialized")

def process_file(s3, bucket, key):
    print(f"Processing {key}...")
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response['Body'].read().decode('utf-8')
        data = json.loads(content)
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO crypto_prices (symbol, price, timestamp, source) VALUES (%s, %s, %s, %s)",
            (data['symbol'], data['price'], data['timestamp'], data['source'])
        )
        conn.commit()
        cur.close()
        conn.close()
        print(f"✅ Ingested data for {data['symbol']}")
        
        # Move to processed bucket (optional, skipping for simplicity)
        # s3.delete_object(Bucket=bucket, Key=key)
        
    except Exception as e:
        print(f"❌ Error processing {key}: {e}")

def main():
    print("🚀 Starting Crypto Ingestor...")
    time.sleep(5) # Wait for dependencies
    
    try:
        init_db()
    except Exception as e:
        print(f"⚠️ DB Init failed (retrying): {e}")
        time.sleep(5)
        init_db()

    s3 = get_s3_client()
    
    while True:
        try:
            # List objects in bucket
            response = s3.list_objects_v2(Bucket=S3_BUCKET)
            if 'Contents' in response:
                for obj in response['Contents']:
                    process_file(s3, S3_BUCKET, obj['Key'])
            else:
                print("💤 No new files found...")
                
        except Exception as e:
            print(f"❌ Loop error: {e}")
            
        time.sleep(10)

if __name__ == "__main__":
    main()
