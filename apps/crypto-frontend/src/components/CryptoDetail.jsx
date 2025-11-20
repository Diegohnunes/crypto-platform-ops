import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, Clock, Database } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';

const CryptoDetail = () => {
    const { symbol } = useParams();
    const [history, setHistory] = useState([]);
    const [stats, setStats] = useState({ min: 0, max: 0, avg: 0 });

    useEffect(() => {
        fetch(`/api/history/${symbol}?limit=100`)
            .then(res => res.json())
            .then(data => {
                setHistory(data);
                if (data.length > 0) {
                    const prices = data.map(d => d.price);
                    setStats({
                        min: Math.min(...prices),
                        max: Math.max(...prices),
                        avg: prices.reduce((a, b) => a + b, 0) / prices.length
                    });
                }
            });
    }, [symbol]);

    if (history.length === 0) return <div className="container">Loading...</div>;

    const latest = history[history.length - 1];

    return (
        <div>
            <Link to="/" className="btn btn-ghost" style={{ marginBottom: '2rem' }}>
                <ArrowLeft size={18} /> Back to Dashboard
            </Link>

            <div className="glass-card" style={{ marginBottom: '2rem' }}>
                <div className="flex-between">
                    <div>
                        <h1 className="text-gradient" style={{ margin: 0, fontSize: '3rem' }}>{symbol}</h1>
                        <div style={{ display: 'flex', gap: '1rem', marginTop: '1rem', color: 'var(--text-secondary)' }}>
                            <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                                <Clock size={16} /> Last update: {new Date(latest.timestamp).toLocaleTimeString()}
                            </span>
                            <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                                <Database size={16} /> Source: {latest.source}
                            </span>
                        </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                        <h2 style={{ margin: 0, fontSize: '3rem' }}>
                            ${latest.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </h2>
                    </div>
                </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '3fr 1fr', gap: '2rem' }}>
                <div className="glass-card" style={{ height: '400px' }}>
                    <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={history}>
                            <defs>
                                <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="5%" stopColor="var(--accent-primary)" stopOpacity={0.3} />
                                    <stop offset="95%" stopColor="var(--accent-primary)" stopOpacity={0} />
                                </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" stroke="var(--glass-border)" vertical={false} />
                            <XAxis
                                dataKey="timestamp"
                                tickFormatter={(ts) => new Date(ts).toLocaleTimeString()}
                                stroke="var(--text-secondary)"
                                tick={{ fill: 'var(--text-secondary)' }}
                            />
                            <YAxis
                                domain={['auto', 'auto']}
                                stroke="var(--text-secondary)"
                                tick={{ fill: 'var(--text-secondary)' }}
                                tickFormatter={(val) => `$${val.toLocaleString()}`}
                            />
                            <Tooltip
                                contentStyle={{ backgroundColor: 'var(--bg-dark)', borderColor: 'var(--glass-border)', color: 'var(--text-primary)' }}
                                itemStyle={{ color: 'var(--accent-primary)' }}
                                labelFormatter={(label) => new Date(label).toLocaleString()}
                            />
                            <Area
                                type="monotone"
                                dataKey="price"
                                stroke="var(--accent-primary)"
                                fillOpacity={1}
                                fill="url(#colorPrice)"
                                strokeWidth={2}
                            />
                        </AreaChart>
                    </ResponsiveContainer>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                    <div className="glass-card">
                        <h3 style={{ margin: '0 0 0.5rem 0', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>24h High</h3>
                        <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 600 }}>${stats.max.toLocaleString()}</p>
                    </div>
                    <div className="glass-card">
                        <h3 style={{ margin: '0 0 0.5rem 0', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>24h Low</h3>
                        <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 600 }}>${stats.min.toLocaleString()}</p>
                    </div>
                    <div className="glass-card">
                        <h3 style={{ margin: '0 0 0.5rem 0', color: 'var(--text-secondary)', fontSize: '0.875rem' }}>Average</h3>
                        <p style={{ margin: 0, fontSize: '1.5rem', fontWeight: 600 }}>${stats.avg.toLocaleString(undefined, { maximumFractionDigits: 2 })}</p>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default CryptoDetail;
