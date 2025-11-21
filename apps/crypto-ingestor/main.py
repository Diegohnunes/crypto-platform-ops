import os
import time
import json
import sqlite3
import glob
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configuration
DATA_DIR = "/data/raw"
DB_PATH = "/data/crypto.db"
PORT = 8080

class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        return  # Silence logs

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

def ingestion_loop():
    print("🚀 Starting Ingestion Loop...")
    
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
                pass
                
        except Exception as e:
            print(f"❌ Loop error: {e}")
            
        time.sleep(5)

def main():
    print(f"🚀 Starting Crypto Ingestor (HTTP + Worker Mode) on port {PORT}...")
    
    # Start ingestion loop in a separate thread
    worker_thread = threading.Thread(target=ingestion_loop, daemon=True)
    worker_thread.start()

    # Start HTTP server for health checks
    server = HTTPServer(('0.0.0.0', PORT), HealthHandler)
    print(f"✅ Health check server listening on {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()
