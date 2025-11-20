import React from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import { LayoutDashboard, Activity } from 'lucide-react';
import Dashboard from './components/Dashboard';
import CryptoDetail from './components/CryptoDetail';

function App() {
    return (
        <div className="app">
            <nav className="glass-card" style={{ borderRadius: 0, borderLeft: 0, borderRight: 0, borderTop: 0 }}>
                <div className="container flex-between" style={{ padding: '1rem 2rem' }}>
                    <Link to="/" style={{ textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <Activity className="text-gradient" size={32} />
                        <h1 style={{ margin: 0, fontSize: '1.5rem' }} className="text-gradient">CryptoLab</h1>
                    </Link>
                    <div style={{ display: 'flex', gap: '1rem' }}>
                        <Link to="/" className="btn btn-ghost">
                            <LayoutDashboard size={18} /> Dashboard
                        </Link>
                    </div>
                </div>
            </nav>

            <main className="container">
                <Routes>
                    <Route path="/" element={<Dashboard />} />
                    <Route path="/crypto/:symbol" element={<CryptoDetail />} />
                </Routes>
            </main>
        </div>
    );
}

export default App;
