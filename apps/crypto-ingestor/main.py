import os
import time
import json
import sqlite3
import glob

# Configuration
DATA_DIR = "/data/raw"
DB_PATH = "/data/crypto.db"

def get_db_connection():
    return sqlite3.connect(DB_PATH)

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS crypto_prices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            price REAL,
            timestamp TEXT,
            source TEXT
        );
    """)
    conn.commit()
    conn.close()
    print("✅ Database initialized (SQLite)")

def process_file(filepath):
    print(f"Processing {filepath}...")
    try:
        with open(filepath, 'r') as f:
            content = f.read()
            data = json.loads(content)
        
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO crypto_prices (symbol, price, timestamp, source) VALUES (?, ?, ?, ?)",
            (data['symbol'], data['price'], data['timestamp'], data['source'])
        )
        conn.commit()
        conn.close()
        print(f"✅ Ingested data for {data['symbol']}")
        
        # Delete file after processing
        os.remove(filepath)
        
    except Exception as e:
        print(f"❌ Error processing {filepath}: {e}")

def main():
    print("🚀 Starting Crypto Ingestor (SQLite Mode)...")
    
    # Ensure data dir exists
    if not os.path.exists(DATA_DIR):
        print(f"⚠️ Waiting for {DATA_DIR}...")
        time.sleep(5)

    init_db()
    
    while True:
        try:
            # List JSON files
            files = glob.glob(os.path.join(DATA_DIR, "*.json"))
            if files:
                for filepath in files:
                    process_file(filepath)
            else:
                # print("💤 No new files found...")
                pass
                
        except Exception as e:
            print(f"❌ Loop error: {e}")
            
        time.sleep(5)

if __name__ == "__main__":
    main()
