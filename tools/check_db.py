import sqlite3

conn = sqlite3.connect('/data/crypto.db')

# Total de registros
total = conn.execute('SELECT count(*) FROM crypto_prices').fetchone()[0]
print(f'Total records: {total}')

# Últimos 5 preços
print('\nLast 5 prices:')
for row in conn.execute('SELECT symbol, price, timestamp FROM crypto_prices ORDER BY timestamp DESC LIMIT 5').fetchall():
    print(f'{row[0]}: ${row[1]:.2f} at {row[2]}')

# Estatísticas de preço
stats = conn.execute('SELECT MIN(price), MAX(price), AVG(price) FROM crypto_prices WHERE symbol = "BTC"').fetchone()
print(f'\nBTC Price Stats:')
print(f'  Min: ${stats[0]:.2f}')
print(f'  Max: ${stats[1]:.2f}')
print(f'  Avg: ${stats[2]:.2f}')

conn.close()
