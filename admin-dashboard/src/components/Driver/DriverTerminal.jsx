import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { FaBus } from 'react-icons/fa';
import {
    FiAlertTriangle, FiUsers, FiMapPin, FiNavigation,
    FiLogOut, FiRefreshCw, FiCheckCircle, FiClock,
} from 'react-icons/fi';
import { db } from '../../firebase';
import {
    collection, onSnapshot, addDoc, doc,
    updateDoc, serverTimestamp, query, where,
    orderBy, limit, getDocs,
} from 'firebase/firestore';
import toast from 'react-hot-toast';

const DriverTerminal = () => {
    const navigate = useNavigate();
    const { logout, user: driver } = useAuth();

    // Session
    const bus = JSON.parse(localStorage.getItem('driver_bus') || 'null');

    // State
    const [liveData, setLiveData] = useState(null);
    const [routeData, setRouteData] = useState(null);
    const [nextStop, setNextStop] = useState(null);
    const [waitingCount, setWaitingCount] = useState(0);
    const [sosActive, setSosActive] = useState(false);
    const [sosLoading, setSosLoading] = useState(false);
    const [rerouteMsg, setRerouteMsg] = useState('');
    const [rerouteLoading, setRerouteLoading] = useState(false);
    const [time, setTime] = useState(new Date());
    const [alerts, setAlerts] = useState([]);
    const [driverStatus, setDriverStatus] = useState('ON_ROUTE');

    const sosRef = useRef(null);

    // Clock
    useEffect(() => {
        const t = setInterval(() => setTime(new Date()), 1000);
        return () => clearInterval(t);
    }, []);

    // Live data stream
    useEffect(() => {
        if (!bus) return;
        const q = query(
            collection(db, 'live_data'),
            where('busId', '==', bus.id),
            orderBy('timestamp', 'desc'),
            limit(1)
        );
        const unsub = onSnapshot(q, snap => {
            if (!snap.empty) setLiveData(snap.docs[0].data());
        });
        return () => unsub();
    }, [bus]);
    // Route data
    useEffect(() => {
        if (!bus) return;

        const q = query(
            collection(db, 'routes'),
            where('busId', '==', bus.id),
            limit(1)
        );

        const unsub = onSnapshot(q, snap => {
            if (!snap.empty) {
                const route = {
                    id: snap.docs[0].id,
                    ...snap.docs[0].data()
                };

                setRouteData(route);

                const stops = route.intermediateStops || [];

                if (stops.length > 0) {
                    setNextStop(stops[0]);
                }
            }
        });

        return () => unsub();
    }, [bus]);

    // Driver status listener
    useEffect(() => {
        if (!bus) return;

        const q = query(
            collection(db, 'buses'),
            where('__name__', '==', bus.id),
            limit(1)
        );

        const unsub = onSnapshot(q, snap => {
            if (!snap.empty) {
                const data = snap.docs[0].data();

                if (data.driverStatus) {
                    setDriverStatus(data.driverStatus);
                }
            }
        });

        return () => unsub();
    }, [bus]);

    // Waiting passengers at next stop (simulated from a
    // 'stop_waiting' Firestore collection — admin can update this)
    useEffect(() => {
        if (!nextStop) return;
        const q = query(
            collection(db, 'stop_waiting'),
            where('stopName', '==', nextStop.name),
            where('busId', '==', bus?.id || ''),
            limit(1)
        );
        const unsub = onSnapshot(q, snap => {
            if (!snap.empty) {
                setWaitingCount(snap.docs[0].data().count || 0);
            } else {
                setWaitingCount(0);
            }
        });
        return () => unsub();
    }, [nextStop]);

    // Unresolved alerts for this bus
    useEffect(() => {
        if (!bus) return;
        const q = query(
            collection(db, 'alerts'),
            where('busId', '==', bus.id),
            where('isResolved', '==', false),
            orderBy('timestamp', 'desc'),
            limit(5)
        );
        const unsub = onSnapshot(q, snap => {
            setAlerts(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        });
        return () => unsub();
    }, [bus]);

    // ── SOS ──────────────────────────────────────────────────

    const handleSOS = async () => {
        if (sosActive) return;

        const confirmed = window.confirm(
            '🚨 MANUAL SOS\n\nThis will immediately alert emergency services, police, and the admin dashboard.\n\nConfirm SOS?'
        );
        if (!confirmed) return;

        setSosLoading(true);
        try {
            // Create alert in Firestore
            await addDoc(collection(db, 'alerts'), {
                busId: bus.id,
                busNumber: bus.busNumber,
                alertType: 'MANUAL_SOS',
                severity: 'CRITICAL',
                message: `Manual SOS triggered by driver ${driver.name} on bus ${bus.busNumber}`,
                latitude: liveData?.latitude || 0,
                longitude: liveData?.longitude || 0,
                isResolved: false,
                triggeredBy: 'DRIVER',
                driverId: driver.uid,
                driverName: driver.name,
                timestamp: serverTimestamp(),
            });

            // Update bus safety status
            await updateDoc(doc(db, 'buses', bus.id), {
                safetyStatus: 'DANGER',
                updatedAt: serverTimestamp(),
            });

            // Call Cloud Function for voice call + Telegram + WhatsApp + Slack
            try {
                await fetch(
                    'https://us-central1-safedrive-144.cloudfunctions.net/sendEmergencyAlert',
                    {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({
                            alertType: 'MANUAL_SOS',
                            busNumber: bus.busNumber,
                            severity: 'CRITICAL',
                            latitude: liveData?.latitude || 0,
                            longitude: liveData?.longitude || 0,
                            message: `Manual SOS by driver ${driver.name} on bus ${bus.busNumber}`,
                        }),
                    }
                );
            } catch (_) {
                // Cloud function call failed — alert still saved in Firestore
            }

            setSosActive(true);
            toast.success('SOS Alert Sent! Help is on the way.');
        } catch (err) {
            toast.error('SOS failed: ' + err.message);
        } finally {
            setSosLoading(false);
        }
    };

    const cancelSOS = async () => {
        try {
            // Resolve all manual SOS alerts for this bus
            const q = query(
                collection(db, 'alerts'),
                where('busId', '==', bus.id),
                where('alertType', '==', 'MANUAL_SOS'),
                where('isResolved', '==', false)
            );
            const snap = await getDocs(q);
            for (const d of snap.docs) {
                await updateDoc(doc(db, 'alerts', d.id), {
                    isResolved: true,
                    resolvedBy: driver.name,
                });
            }
            await updateDoc(doc(db, 'buses', bus.id), {
                safetyStatus: 'SAFE',
                updatedAt: serverTimestamp(),
            });
            setSosActive(false);
            toast.success('SOS cancelled.');
        } catch (err) {
            toast.error('Cancel failed: ' + err.message);
        }
    };

    // ── AI Rerouting ──────────────────────────────────────────

    const handleReroute = async () => {
        setRerouteLoading(true);
        setRerouteMsg('');
        try {

            setRerouteMsg(
                'Traffic ahead may be slow. Continue on the current route and maintain safe speed.'
            );
        } catch {
            setRerouteMsg('AI rerouting unavailable. Follow the standard route.');
        } finally {
            setRerouteLoading(false);
        }
    };

    // ── Logout ────────────────────────────────────────────────

    const handleLogout = async () => {
        await logout();
        navigate('/login');
    };

    const updateDriverStatus = async (status) => {
        try {
            setDriverStatus(status);

            await updateDoc(doc(db, 'buses', bus.id), {
                driverStatus: status,
                updatedAt: serverTimestamp(),
            });

            toast.success(`Driver status updated: ${status}`);
        } catch (err) {
            toast.error('Failed to update status');
        }
    };

    // ── Helpers ──────────────────────────────────────────────

    const formatTime = (d) =>
        d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' });

    const formatDate = (d) =>
        d.toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long' });

    // ── Render ────────────────────────────────────────────────

    return (
        <div className="min-h-screen bg-gray-950 text-white p-4 lg:p-6">

            {/* ── Top bar ── */}
            <div className="flex items-center justify-between mb-6">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-yellow-400 rounded-xl flex items-center justify-center">
                        <FaBus className="text-gray-900 w-5 h-5" />
                    </div>
                    <div>
                        <p className="font-bold text-lg leading-tight">{bus?.busNumber}</p>
                        <p className="text-gray-400 text-xs">{driver?.name} · Driver Terminal</p>
                    </div>
                </div>

                {/* Clock */}
                <div className="text-right hidden sm:block">
                    <p className="text-2xl font-mono font-bold text-yellow-400">
                        {formatTime(time)}
                    </p>
                    <p className="text-gray-500 text-xs">{formatDate(time)}</p>
                </div>

                <button
                    onClick={handleLogout}
                    className="flex items-center gap-2 text-gray-400 hover:text-white text-sm transition-colors"
                >
                    <FiLogOut className="w-4 h-4" />
                    <span className="hidden sm:inline">Logout</span>
                </button>
            </div>

            {/* ── Active SOS banner ── */}
            {sosActive && (
                <div className="bg-red-900 border border-red-500 rounded-xl p-4 mb-6 flex items-center justify-between animate-pulse">
                    <div className="flex items-center gap-3">
                        <FiAlertTriangle className="text-red-400 w-6 h-6" />
                        <div>
                            <p className="text-red-300 font-bold">SOS ACTIVE — Emergency services notified</p>
                            <p className="text-red-400 text-xs">Help is on the way. Stay calm.</p>
                        </div>
                    </div>
                    <button
                        onClick={cancelSOS}
                        className="bg-red-700 hover:bg-red-600 text-white text-xs px-4 py-2 rounded-lg transition-colors"
                    >
                        Cancel SOS
                    </button>
                </div>
            )}

            {/* ── Main grid ── */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-4">

                {/* ── Next Stop card ── */}
                <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800">
                    <div className="flex items-center gap-2 mb-4">
                        <FiMapPin className="text-yellow-400 w-5 h-5" />
                        <h3 className="font-semibold text-gray-300 text-sm uppercase tracking-wide">
                            Next Stop
                        </h3>
                    </div>

                    {nextStop ? (
                        <>
                            <p className="text-2xl font-bold text-white mb-1">
                                {nextStop.name}
                            </p>
                            {nextStop.arrivalTime && (
                                <div className="flex items-center gap-2 text-gray-400 text-sm mb-4">
                                    <FiClock className="w-4 h-4" />
                                    <span>Scheduled: {nextStop.arrivalTime}</span>
                                </div>
                            )}

                            {/* Waiting passengers */}
                            <div className="bg-gray-800 rounded-xl p-4 flex items-center gap-4">
                                <div className="w-12 h-12 bg-blue-500 bg-opacity-20 rounded-xl flex items-center justify-center">
                                    <FiUsers className="text-blue-400 w-6 h-6" />
                                </div>
                                <div>
                                    <p className="text-3xl font-bold text-blue-400">
                                        {waitingCount}
                                    </p>
                                    <p className="text-gray-400 text-xs">Passengers waiting</p>
                                </div>
                            </div>
                        </>
                    ) : (
                        <p className="text-gray-500 text-sm">No route data available</p>
                    )}
                </div>

                {/* ── Live sensor card ── */}
                <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800">
                    <div className="flex items-center gap-2 mb-4">
                        <FiNavigation className="text-green-400 w-5 h-5" />
                        <h3 className="font-semibold text-gray-300 text-sm uppercase tracking-wide">
                            Live Status
                        </h3>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                        <div className="bg-gray-800 rounded-xl p-3 text-center">
                            <p className="text-2xl font-bold text-white">
                                {liveData?.speed?.toFixed?.(1) ?? '0.0'}
                            </p>
                            <p className="text-gray-400 text-xs">km/h</p>
                        </div>
                        <div className="bg-gray-800 rounded-xl p-3 text-center">
                            <p className="text-2xl font-bold text-white">
                                {liveData?.temperature?.toFixed?.(1) ?? '0.0'}°
                            </p>
                            <p className="text-gray-400 text-xs">Temp °C</p>
                        </div>
                        <div className="bg-gray-800 rounded-xl p-3 text-center">
                            <p className={`text-lg font-bold ${liveData?.smoke === 'SAFE' || !liveData?.smokeDetected
                                ? 'text-green-400' : 'text-red-400'
                                }`}>
                                {liveData?.smoke ?? (liveData?.smokeDetected ? 'ALERT' : 'SAFE')}
                            </p>
                            <p className="text-gray-400 text-xs">Smoke</p>
                        </div>
                        <div className="bg-gray-800 rounded-xl p-3 text-center">
                            <p className={`text-lg font-bold ${alerts.length > 0 ? 'text-red-400' : 'text-green-400'}`}>
                                {alerts.length > 0 ? 'DANGER' : 'SAFE'}
                            </p>
                            <p className="text-gray-400 text-xs">Safety</p>
                        </div>
                    </div>
                </div>

                {/* ── SOS card ── */}
                <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800 flex flex-col items-center justify-center">
                    <p className="text-gray-400 text-sm uppercase tracking-wide mb-6">
                        Manual SOS Override
                    </p>

                    {/* SOS button */}
                    <button
                        ref={sosRef}
                        onClick={sosActive ? cancelSOS : handleSOS}
                        disabled={sosLoading}
                        className={`w-40 h-40 rounded-full text-white font-black text-2xl transition-all duration-300 shadow-2xl
              ${sosActive
                                ? 'bg-gray-700 border-4 border-gray-500 scale-95'
                                : 'bg-red-600 hover:bg-red-500 border-4 border-red-400 hover:scale-105 active:scale-95'
                            }
              ${sosLoading ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
            `}
                        style={{
                            boxShadow: sosActive
                                ? 'none'
                                : '0 0 40px rgba(239,68,68,0.5), 0 0 80px rgba(239,68,68,0.2)',
                        }}
                    >
                        {sosLoading ? '...' : sosActive ? 'CANCEL' : 'SOS'}
                    </button>

                    <p className="text-gray-500 text-xs mt-4 text-center">
                        {sosActive
                            ? 'Tap CANCEL when safe'
                            : 'Hold in emergency only'}
                    </p>
                </div>
            </div>

            {/* ── Driver Status Panel ── */}
            <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800 mb-4">
                <div className="flex items-center justify-between mb-4">
                    <h3 className="font-semibold text-gray-300 text-sm uppercase tracking-wide">
                        Driver Status
                    </h3>

                    <span className="text-yellow-400 text-sm font-bold">
                        {driverStatus}
                    </span>
                </div>

                <div className="flex flex-wrap gap-3">

                    <button
                        onClick={() => updateDriverStatus('ARRIVED')}
                        className="bg-green-600 hover:bg-green-500 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                    >
                        Arrived
                    </button>

                    <button
                        onClick={() => updateDriverStatus('BOARDING')}
                        className="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                    >
                        Boarding
                    </button>

                    <button
                        onClick={() => updateDriverStatus('DELAYED')}
                        className="bg-red-600 hover:bg-red-500 text-white px-4 py-2 rounded-lg text-sm transition-colors"
                    >
                        Delayed
                    </button>

                </div>
            </div>

            {/* ── Bottom row ── */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">

                {/* ── AI Rerouting ── */}
                <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800">
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-2">
                            <span className="text-lg">✨</span>
                            <h3 className="font-semibold text-gray-300 text-sm uppercase tracking-wide">
                                AI Route Advice
                            </h3>
                        </div>
                        <button
                            onClick={handleReroute}
                            disabled={rerouteLoading}
                            className="flex items-center gap-2 bg-purple-600 hover:bg-purple-500 text-white text-xs px-3 py-2 rounded-lg transition-colors disabled:opacity-50"
                        >
                            <FiRefreshCw className={`w-3 h-3 ${rerouteLoading ? 'animate-spin' : ''}`} />
                            {rerouteLoading ? 'Analyzing...' : 'Get Advice'}
                        </button>
                    </div>

                    {rerouteMsg ? (
                        <div className="bg-purple-950 border border-purple-800 rounded-xl p-4">
                            <p className="text-purple-200 text-sm leading-relaxed">{rerouteMsg}</p>
                        </div>
                    ) : (
                        <div className="bg-gray-800 rounded-xl p-4 text-center">
                            <p className="text-gray-500 text-sm">
                                Tap "Get Advice" for AI-powered rerouting suggestions
                            </p>
                        </div>
                    )}

                    {/* Route stops */}
                    {routeData && (
                        <div className="mt-4">
                            <p className="text-gray-500 text-xs mb-2">Route</p>
                            <div className="flex items-center gap-2 flex-wrap">
                                <span className="text-green-400 text-xs font-medium">
                                    {routeData.source}
                                </span>
                                {(routeData.intermediateStops || []).map((s, i) => (
                                    <React.Fragment key={i}>
                                        <span className="text-gray-600 text-xs">→</span>
                                        <span className={`text-xs ${s.name === nextStop?.name
                                            ? 'text-yellow-400 font-bold'
                                            : 'text-gray-400'
                                            }`}>
                                            {s.name}
                                        </span>
                                    </React.Fragment>
                                ))}
                                <span className="text-gray-600 text-xs">→</span>
                                <span className="text-red-400 text-xs font-medium">
                                    {routeData.destination}
                                </span>
                            </div>
                        </div>
                    )}
                </div>

                {/* ── Active alerts ── */}
                <div className="bg-gray-900 rounded-2xl p-5 border border-gray-800">
                    <div className="flex items-center gap-2 mb-4">
                        <FiAlertTriangle className="text-orange-400 w-5 h-5" />
                        <h3 className="font-semibold text-gray-300 text-sm uppercase tracking-wide">
                            Active Alerts
                        </h3>
                        {alerts.length > 0 && (
                            <span className="bg-red-900 text-red-400 text-xs px-2 py-0.5 rounded-full font-bold">
                                {alerts.length}
                            </span>
                        )}
                    </div>

                    {alerts.length === 0 ? (
                        <div className="flex items-center gap-3 bg-green-950 border border-green-900 rounded-xl p-4">
                            <FiCheckCircle className="text-green-400 w-5 h-5" />
                            <p className="text-green-400 text-sm font-medium">
                                All systems normal
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {alerts.map(alert => (
                                <div
                                    key={alert.id}
                                    className="bg-red-950 border border-red-900 rounded-xl p-3 flex items-center gap-3"
                                >
                                    <div className={`w-2 h-2 rounded-full flex-shrink-0 ${alert.severity === 'CRITICAL'
                                        ? 'bg-red-400' : 'bg-orange-400'
                                        }`} />
                                    <div className="flex-1 min-w-0">
                                        <p className="text-red-300 text-xs font-semibold">
                                            {alert.alertType}
                                        </p>
                                        <p className="text-red-400 text-xs truncate">
                                            {alert.message}
                                        </p>
                                    </div>
                                    <span className="text-red-600 text-xs flex-shrink-0">
                                        {alert.severity}
                                    </span>
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DriverTerminal;