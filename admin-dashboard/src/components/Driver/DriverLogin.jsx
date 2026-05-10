import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FaBus } from 'react-icons/fa';
import { FiDelete } from 'react-icons/fi';
import toast from 'react-hot-toast';

// Driver PINs — add more drivers here
// Format: { pin: '1234', name: 'Driver Name', id: 'unique_id' }
const DRIVER_PINS = [
    { pin: '1234', name: 'Ravi Kumar', id: 'driver_001' },
    { pin: '5678', name: 'Suresh Babu', id: 'driver_002' },
    { pin: '9999', name: 'Arjun Reddy', id: 'driver_003' },
];

const DriverLogin = () => {
    const [pin, setPin] = useState('');
    const [loading, setLoading] = useState(false);
    const [shake, setShake] = useState(false);
    const navigate = useNavigate();

    const handleKey = (key) => {
        if (pin.length < 4) setPin(prev => prev + key);
    };

    const handleDelete = () => setPin(prev => prev.slice(0, -1));

    const handleSubmit = () => {
        if (pin.length !== 4) return;
        setLoading(true);

        const driver = DRIVER_PINS.find(d => d.pin === pin);
        if (driver) {
            localStorage.setItem('driver_session', JSON.stringify({
                id: driver.id,
                name: driver.name,
                loginAt: new Date().toISOString(),
            }));
            toast.success(`Welcome, ${driver.name}!`);
            navigate('/driver/bus-select');
        } else {
            setShake(true);
            setPin('');
            setTimeout(() => setShake(false), 600);
            toast.error('Invalid PIN. Try again.');
        }
        setLoading(false);
    };

    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

    return (
        <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-700 flex items-center justify-center p-4">
            {/* Background circles */}
            <div className="absolute inset-0 overflow-hidden">
                <div className="absolute -top-40 -right-40 w-80 h-80 rounded-full bg-yellow-500 opacity-10"></div>
                <div className="absolute -bottom-40 -left-40 w-80 h-80 rounded-full bg-yellow-400 opacity-10"></div>
            </div>

            <div className="relative w-full max-w-sm">
                {/* Header */}
                <div className="text-center mb-8">
                    <div className="inline-flex items-center justify-center w-16 h-16 bg-yellow-400 rounded-2xl shadow-lg mb-4">
                        <FaBus className="w-8 h-8 text-gray-900" />
                    </div>
                    <h1 className="text-3xl font-bold text-white">SafeTrack</h1>
                    <p className="text-gray-400 mt-1">Driver Terminal</p>
                </div>

                <div className="bg-white rounded-2xl shadow-2xl p-8">
                    <h2 className="text-xl font-semibold text-gray-800 text-center mb-2">
                        Enter Your PIN
                    </h2>
                    <p className="text-gray-400 text-sm text-center mb-6">
                        4-digit driver PIN
                    </p>

                    {/* PIN dots */}
                    <div className={`flex justify-center gap-4 mb-8 ${shake ? 'animate-bounce' : ''}`}>
                        {[0, 1, 2, 3].map(i => (
                            <div
                                key={i}
                                className={`w-4 h-4 rounded-full border-2 transition-all duration-150 ${i < pin.length
                                        ? 'bg-yellow-400 border-yellow-400 scale-110'
                                        : 'border-gray-300'
                                    }`}
                            />
                        ))}
                    </div>

                    {/* Numpad */}
                    <div className="grid grid-cols-3 gap-3 mb-6">
                        {keys.map((key, i) => {
                            if (key === '') return <div key={i} />;
                            if (key === 'del') return (
                                <button
                                    key={i}
                                    onClick={handleDelete}
                                    className="h-14 flex items-center justify-center rounded-xl bg-gray-100 hover:bg-gray-200 text-gray-600 transition-colors"
                                >
                                    <FiDelete className="w-5 h-5" />
                                </button>
                            );
                            return (
                                <button
                                    key={i}
                                    onClick={() => handleKey(key)}
                                    disabled={pin.length >= 4}
                                    className="h-14 text-xl font-semibold rounded-xl bg-gray-50 hover:bg-yellow-50 hover:text-yellow-600 border border-gray-200 hover:border-yellow-300 transition-all disabled:opacity-40"
                                >
                                    {key}
                                </button>
                            );
                        })}
                    </div>

                    {/* Submit */}
                    <button
                        onClick={handleSubmit}
                        disabled={pin.length !== 4 || loading}
                        className="w-full bg-yellow-400 hover:bg-yellow-500 text-gray-900 font-bold py-3 rounded-xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                        {loading ? 'Verifying...' : 'Login'}
                    </button>
                </div>

                <p className="text-center text-gray-500 text-sm mt-6">
                    Admin? <a href="/login" className="text-yellow-400 hover:underline">Go to Admin Login</a>
                </p>
            </div>
        </div>
    );
};

export default DriverLogin;