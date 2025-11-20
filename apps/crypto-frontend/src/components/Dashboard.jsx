import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { TrendingUp, TrendingDown, ArrowRight } from 'lucide-react';
import { LineChart, Line, ResponsiveContainer } from 'recharts';

const CryptoCard = ({ symbol }) => {
    const [data, setData] = useState(null);
    const [history, setHistory] = useState([]);

    useEffect(() => {
        // Fetch latest price
        fetch(`/api/price/${symbol}`)
            .then(res => res.json())
            .then(setData);

        // Fetch mini history for sparkline
        fetch(`/api/history/${symbol}?limit=20`)
            .then(res => res.json())
            .then(setHistory);
    }, [symbol]);

    if (!data) return <div className="glass-card animate-pulse" style={{ height: '200px' }}></div>;

    const isPositive = history.length > 1 && history[history.length - 1].price >= history[0].price;

    return (
        <Link to={`/crypto/${symbol}`} style={{ textDecoration: 'none', color: 'inherit' }}>
            <div className="glass-card">
                <div className="flex-between">
                    <div>
                        <h3 style={{ margin: 0, fontSize: '1.5rem' }}>{symbol}</h3>
                        <span style={{ color: 'var(--text-secondary)', fontSize: '0.875rem' }}>{data.source}</span>
                    </div>
                    <div style={{
                        background: isPositive ? 'rgba(74, 222, 128, 0.1)' : 'rgba(248, 113, 113, 0.1)',
                        padding: '0.5rem',
                        borderRadius: '50%',
                        display: 'flex'
                    }}>
                        {isPositive ? <TrendingUp size={24} color="var(--success)" /> : <TrendingDown size={24} color="var(--danger)" />}
                    </div>
                </div>

                <div style={{ margin: '1.5rem 0' }}>
                    <h2 style={{ margin: 0, fontSize: '2.5rem', fontWeight: 600 }}>
                        ${data.price?.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                    </h2>
                </div>

                <div style={{ height: '60px', margin: '0 -1.5rem -1.5rem -1.5rem' }}>
                    <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={history}>
                            <Line
                                type="monotone"
                                dataKey="price"
                                stroke={isPositive ? 'var(--success)' : 'var(--danger)'}
                                strokeWidth={2}
                                dot={false}
                            />
                        </LineChart>
                    </ResponsiveContainer>
                </div>
            </div>
        </Link>
    );
};

const Dashboard = () => {
    const [cryptos, setCryptos] = useState([]);

    useEffect(() => {
        fetch('/api/cryptos')
            .then(res => res.json())
            .then(setCryptos);
    }, []);

    return (
        <div>
            <div className="flex-between">
                <div>
                    <h2 style={{ margin: 0 }}>Market Overview</h2>
                    <p style={{ color: 'var(--text-secondary)', margin: '0.5rem 0 0 0' }}>
                        Real-time price tracking from your local lab.
                    </p>
                </div>
                <button className="btn" onClick={() => window.location.reload()}>
                    Refresh Data
                </button>
            </div>

            <div className="grid-dashboard">
                {cryptos.map(symbol => (
                    <CryptoCard key={symbol} symbol={symbol} />
                ))}
            </div>

            {cryptos.length === 0 && (
                <div style={{ textAlign: 'center', marginTop: '4rem', color: 'var(--text-secondary)' }}>
                    <p>No assets found. Start a collector to see data here.</p>
                    <code>ops-cli create-service --name btc-collector --coin BTC</code>
                </div>
            )}
        </div>
    );
};

export default Dashboard;
