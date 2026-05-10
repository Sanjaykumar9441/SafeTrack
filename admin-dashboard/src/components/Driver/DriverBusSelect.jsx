import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { FaBus } from 'react-icons/fa';
import { FiSearch, FiLogOut } from 'react-icons/fi';
import { db } from '../../firebase';
import { collection, onSnapshot } from 'firebase/firestore';
import toast from 'react-hot-toast';

const DriverBusSelect = () => {
    const navigate = useNavigate();
    const { logout, user: driver } = useAuth();
    const [buses, setBuses] = useState([]);
    const [search, setSearch] = useState('');
    const [loading, setLoading] = useState(true);

    // Load active buses
    useEffect(() => {
        const unsub = onSnapshot(collection(db, 'buses'), (snap) => {
            const data = snap.docs
                .map(d => ({ id: d.id, ...d.data() }))
                .filter(b => b.isActive);
            setBuses(data);
            setLoading(false);
        });
        return () => unsub();
    }, []);

    const filtered = buses.filter(b =>
        b.busNumber?.toLowerCase().includes(search.toLowerCase()) ||
        b.busName?.toLowerCase().includes(search.toLowerCase())
    );

    const handleSelect = (bus) => {
        localStorage.setItem('driver_bus', JSON.stringify({
            id: bus.id,
            busNumber: bus.busNumber,
            busName: bus.busName,
            deviceId: bus.deviceId || '',
            seatCapacity: bus.seatCapacity || 40,
        }));
        toast.success(`Selected: ${bus.busNumber}`);
        navigate('/driver/terminal');
    };

    const handleLogout = async () => {
        await logout();
        navigate('/login');
    };

    return (
        <div className="min-h-screen bg-gray-900 p-6">
            {/* Header */}
            <div className="flex items-center justify-between mb-8">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-yellow-400 rounded-xl flex items-center justify-center">
                        <FaBus className="text-gray-900 w-5 h-5" />
                    </div>
                    <div>
                        <h1 className="text-white font-bold text-lg">Select Your Bus</h1>
                        <p className="text-gray-400 text-sm">Welcome, {driver?.name}</p>
                    </div>
                </div>
                <button
                    onClick={handleLogout}
                    className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm"
                >
                    <FiLogOut className="w-4 h-4" />
                    Logout
                </button>
            </div>

            {/* Search */}
            <div className="relative mb-6">
                <FiSearch className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
                <input
                    type="text"
                    value={search}
                    onChange={e => setSearch(e.target.value)}
                    placeholder="Search bus number or name..."
                    className="w-full pl-12 pr-4 py-3 bg-gray-800 text-white border border-gray-700 rounded-xl focus:outline-none focus:border-yellow-400 placeholder-gray-500"
                />
            </div>

            {/* Bus list */}
            {loading ? (
                <div className="flex justify-center pt-20">
                    <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-yellow-400"></div>
                </div>
            ) : filtered.length === 0 ? (
                <div className="text-center py-20 text-gray-500">
                    No active buses found
                </div>
            ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filtered.map(bus => (
                        <button
                            key={bus.id}
                            onClick={() => handleSelect(bus)}
                            className="bg-gray-800 hover:bg-gray-700 border border-gray-700 hover:border-yellow-400 rounded-xl p-5 text-left transition-all group"
                        >
                            <div className="flex items-center gap-3 mb-3">
                                <div className="w-10 h-10 bg-yellow-400 bg-opacity-10 group-hover:bg-opacity-20 rounded-lg flex items-center justify-center transition-all">
                                    <FaBus className="text-yellow-400 w-5 h-5" />
                                </div>
                                <div>
                                    <p className="text-white font-bold text-sm">{bus.busNumber}</p>
                                    <p className="text-gray-400 text-xs">{bus.busName}</p>
                                </div>
                            </div>
                            <div className="flex items-center justify-between">
                                <span className={`text-xs px-2 py-1 rounded-full font-medium ${bus.status === 'RUNNING'
                                    ? 'bg-green-900 text-green-400'
                                    : 'bg-gray-700 text-gray-400'
                                    }`}>
                                    {bus.status || 'STOPPED'}
                                </span>
                                <span className="text-gray-500 text-xs">
                                    {bus.seatCapacity || 40} seats
                                </span>
                            </div>
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
};

export default DriverBusSelect;