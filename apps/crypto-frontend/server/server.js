import express from 'express';
import sqlite3 from 'sqlite3';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 4000;
const DB_PATH = process.env.DB_PATH || '/data/crypto.db';

app.use(cors());
app.use(express.json());

// Health Check
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// Serve static files from the React app
app.use(express.static(path.join(__dirname, '../dist')));

const getDb = () => {
    return new sqlite3.Database(DB_PATH, sqlite3.OPEN_READONLY, (err) => {
        if (err) {
            console.error('Error opening database:', err.message);
        }
    });
};

// API: Get list of available cryptos
app.get('/api/cryptos', (req, res) => {
    const db = getDb();
    const query = `
    SELECT DISTINCT symbol 
    FROM crypto_prices 
    ORDER BY symbol
  `;

    db.all(query, [], (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows.map(row => row.symbol));
        db.close();
    });
});

// API: Get latest price for a crypto
app.get('/api/price/:symbol', (req, res) => {
    const db = getDb();
    const symbol = req.params.symbol.toUpperCase();
    const query = `
    SELECT * FROM crypto_prices 
    WHERE symbol = ? 
    ORDER BY timestamp DESC 
    LIMIT 1
  `;

    db.get(query, [symbol], (err, row) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(row || {});
        db.close();
    });
});

// API: Get history for a crypto (for charts)
app.get('/api/history/:symbol', (req, res) => {
    const db = getDb();
    const symbol = req.params.symbol.toUpperCase();
    const limit = req.query.limit || 100;

    const query = `
    SELECT * FROM crypto_prices 
    WHERE symbol = ? 
    ORDER BY timestamp ASC 
    LIMIT ?
  `;

    db.all(query, [symbol, limit], (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows);
        db.close();
    });
});

// The "catchall" handler: for any request that doesn't
// match one above, send back React's index.html file.
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../dist/index.html'));
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
